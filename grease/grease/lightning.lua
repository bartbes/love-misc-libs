local socket = require "socket"

return function(protocol)
	--- COMMON ---

	local function sendPacket(self, sendfunc, data)
		-- Max datagram size is apparently 65507 bytes
		-- To be safe, split at 65000
		local splitlen = 65000
		self._seqno = (self._seqno + 1)%256

		data = protocol.escape(data)

		local seqno = self._seqno
		local contno = math.floor(math.max(#data-1, 0)/splitlen)
		local type = "DATA"

		for i = 1, math.max(#data, 1), splitlen do
			local split = data:sub(i, i+splitlen)
			local hdr = protocol.createheader(type, seqno, contno)
			local pkt = protocol.createpacket(hdr, split)
			sendfunc(pkt)

			if type == "DATA" then contno = 0 end
			type = "CONTINUATION"
			contno = contno + 1
		end
	end

	local function initpktbuffer(buffer)
		buffer.seqno = nil
		buffer.contno = 0
		buffer.conts = math.huge
		buffer.databuffer = ""
		return buffer
	end

	local function handlePacket(pkt, pktbuffer)
		-- A new DATA!
		local type = protocol.gettype(pkt)
		if type == "DATA" then
			initpktbuffer(pktbuffer)
			pktbuffer.seqno = protocol.getseqno(pkt)
			pktbuffer.conts = protocol.getcontno(pkt)
			pktbuffer.databuffer = protocol.getdata(pkt)
		elseif type == "CONTINUATION" then
			local seqno = protocol.getseqno(pkt)
			local contno = protocol.getcontno(pkt)

			-- If this is for the wrong data
			-- or we've lost a continuation
			if seqno ~= pktbuffer.seqno or
					contno ~= pktbuffer.contno + 1 then
				-- DISCARD BOTH!
				pktbuffer.seqno = nil
				return nil
			end

			-- Otherwise concatenate
			pktbuffer.databuffer = pktbuffer.databuffer .. protocol.getdata(pkt)
			pktbuffer.contno = contno
		end

		-- If we've received everything
		if pktbuffer.conts == pktbuffer.contno then
			return pktbuffer.databuffer
		end
	end

	--- CLIENT ---

	local lightningClient = {}
	lightningClient._implemented = true

	function lightningClient:createSocket()
		self.socket = socket.udp()
		self.socket:settimeout(0)
		self._recvbuffer = ""
		self._seqno = 0
		self._pktbuffer = initpktbuffer{}
	end

	function lightningClient:_connect()
		-- 'Connect' in the udp style of no longer having to specify a host and port
		self.socket:setpeername(self.host, self.port)

		-- Form a connect packet
		local hdr = protocol.createheader("CONNECT")
		local pkt = protocol.createpacket(hdr, "")
		self.socket:send(pkt)
		-- Wait until confirmed
		-- TODO
		return true
	end

	function lightningClient:_disconnect()
		-- Form a disconnect packet
		local hdr = protocol.createheader("DISCONNECT")
		local pkt = protocol.createpacket(hdr, "")
		self.socket:send(pkt)
		self.socket:close()
		return true
	end

	function lightningClient:_send(data)
		local function f(data)
			return self.socket:send(data)
		end
		return sendPacket(self, f, data)
	end

	function lightningClient:_getPacket()
		local buffer = self._recvbuffer
		local start, finish = protocol.findpacket(buffer)
		if not start then return nil end

		local pkt = buffer:sub(start, finish)

		-- Note, anything before start is discarded!
		self._recvbuffer = buffer:sub(finish+1, -1)

		return pkt
	end

	function lightningClient:_receive()
		local data = self.socket:receive()
		if data then
			self._recvbuffer = self._recvbuffer .. data
		end

		local pkt = self:_getPacket()
		if not pkt then return nil end

		return handlePacket(pkt, self._pktbuffer)
	end

	--- SERVER ---

	local lightningServer = {}
	lightningServer._implemented = true

	function lightningServer:createSocket()
		self.socket = socket.udp()
		self.socket:settimeout(0)

		self._seqno = 0
		self._clients = {
			--[[{
				recvbuffer = "",
				pktbuffer = self:_newpktbuffer()
			},]]--
		}
	end

	function lightningServer:_listen()
		self.socket:setsockname("*", self.port)
	end

	function lightningServer:send(data, clientid)
		-- We conviently use ip:port as clientid.
		local f
		if clientid then
			local ip, port = clientid:match("^(.-):(%d+)$")
			f = function(data)
				return self.socket:sendto(data, ip, tonumber(port))
			end
		else
			f = function(data)
				for clientid, _ in pairs(self._clients) do
					local ip, port = clientid:match("^(.-):(%d+)$")
					self.socket:sendto(data, ip, tonumber(port))
				end
			end
		end

		return sendPacket(self, f, data)
	end

	function lightningServer:_getPacket(client)
		local buffer = client.recvbuffer
		local start, finish = protocol.findpacket(buffer)
		if not start then return nil end

		local pkt = buffer:sub(start, finish)

		-- Note, anything before start is discarded!
		client.recvbuffer = buffer:sub(finish+1, -1)

		return pkt
	end

	function lightningServer:receive()
		-- Buffer all incoming data
		local data, ip, port = self.socket:receivefrom()
		if data then
			local clientid = ip .. ":" .. port
			-- TODO Clean self._clients
			self._clients[clientid] = self._clients[clientid] or
			{
				recvbuffer = "",
				pktbuffer = initpktbuffer{},
			}

			self._clients[clientid].recvbuffer = self._clients[clientid].recvbuffer .. data
		end

		-- Find a client with a packet ready, if any
		local pkt, pktclientid, pktclient
		for clientid, client in pairs(self._clients) do
			pkt = self:_getPacket(client)
			if pkt then
				pktclientid, pktclient = clientid, client
				break
			end
		end

		-- If there were no packets, stop now
		if not pkt then return nil end

		-- Handle the packet, the difficult part
		local pkt = handlePacket(pkt, pktclient.pktbuffer)
		return pkt, pktclientid
	end

	function lightningServer:accept()
	end

	return {lightningClient, lightningServer}
end
