local socket = require "socket"

return function(protocol)
	--- CLIENT ---

	local lubeClient = {}
	lubeClient._implemented = true

	function lubeClient:createSocket()
		self.socket = socket.udp()
		self.socket:settimeout(0)
		self._recvbuffer = ""
		self._seqno = 0
		self:_newpktbuffer()
	end

	function lubeClient:_newpktbuffer()
		self._pktbuffer = {
			seqno = nil,
			contno = 0,
			conts = math.huge,
			databuffer = "",
		}
	end

	function lubeClient:_connect()
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

	function lubeClient:_disconnect()
		-- Form a disconnect packet
		local hdr = protocol.createheader("DISCONNECT")
		local pkt = protocol.createpacket(hdr, "")
		self.socket:send(pkt)
		self.socket:close()
		return true
	end

	function lubeClient:_send(data)
		-- Max datagram size is apparently 65507 bytes
		-- To be safe, split at 65000
		-- TODO Escape here
		local splitlen = 65000
		self._seqno = (self._seqno + 1)%256

		local seqno = self._seqno
		local contno = math.floor(math.max(#data-1, 0)/splitlen)
		local type = "DATA"

		for i = 1, math.max(#data, 1), splitlen do
			local split = data:sub(i, i+splitlen)
			local hdr = protocol.createheader(type, seqno, contno)
			local pkt = protocol.createpacket(hdr, split)
			self.socket:send(pkt)

			if type == "DATA" then contno = 0 end
			type = "CONTINUATION"
			contno = contno + 1
		end
	end

	function lubeClient:_receive_data()
		local data, ip, port = self.socket:receivefrom()
		if ip == self.host and port == self.port then
			return data
		end
		return false, data and "Unknown remote sent data." or ip
	end

	function lubeClient:_getPacket(buffer)
		local buffer = self._recvbuffer
		local start, finish = protocol.findpacket(buffer)
		if not start then return nil end

		local pkt = buffer:sub(start, finish)

		-- Note, anything before start is discarded!
		self._recvbuffer = buffer:sub(finish+1, -1)

		return pkt
	end

	function lubeClient:_receive()
		local data = self.socket:receive()
		if data then
			self._recvbuffer = self._recvbuffer .. data
		end

		local pkt = self:_getPacket()
		if not pkt then return nil end

		-- A new DATA!
		local type = protocol.gettype(pkt)
		if type == "DATA" then
			self:_newpktbuffer()
			self._pktbuffer.seqno = protocol.getseqno(pkt)
			self._pktbuffer.conts = protocol.getcontno(pkt)
			self._pktbuffer.databuffer = protocol.getdata(pkt)
		elseif type == "CONTINUATION" then
			local seqno = protocol.getseqno(pkt)
			local contno = packget.getcontno(pkt)

			-- If this is for the wrong data
			-- or we've lost a continuation
			if seqno ~= self._pktbuffer.seqno or
					contno ~= self._pktbuffer.contno + 1 then
				-- DISCARD BOTH!
				self._pktbuffer.seqno = nil
				return nil
			end

			-- Otherwise concatenate
			self._pktbuffer.databuffer = self._pktbuffer.databuffer .. protocol.getdata(pkt)
			self._pktbuffer.contno = contno
		end

		-- If we've received everything
		if self._pktbuffer.conts == self._pktbuffer.contno then
			return self._pktbuffer.databuffer
		end
	end

	local lubeServer = {}

	return {lubeClient, lubeServer}
end
