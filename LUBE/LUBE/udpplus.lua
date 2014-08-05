local socket = require "socket"
local parentClient, parentServer

--- COMMON ---

local function notimplemented() return error("Not implemented") end

local udpPacketSizeLimit = 65000
local startMarker = string.char(2) -- STX
local endMarker = string.char(3)   -- ETX

local function escapeData(data)
	return data:gsub(startMarker, startMarker .. startMarker):gsub(endMarker, endMarker..endMarker)
end

local function createPackets(data)
	local packet = {startMarker .. escapeData(data)}

	while true do
		local overlimit = #packet[1]-udpPacketSizeLimit
		if overlimit <= 0 then break end

		overlimit = overlimit%udpPacketSizeLimit
		table.insert(packet, 3, packet[1]:sub(-overlimit))
		packet[1] = packet[1]:sub(1, -overlimit-1)
	end

	-- Our limit is rounded down, so we can spare the ending marker
	packet[#packet] = packet[#packet] .. endMarker
	return packet
end

local function getBufferedPacket(buffer)
	return table.remove(buffer.packets, 1)
end

local function containsBegin(data)
	return data:find("^" .. startMarker) or data:find("[^" .. startMarker .. "]" .. startMarker)
end

local function containsEnd(data)
	return data:find("^" .. endMarker) or data:find("[^" .. endMarker .. "]" .. endMarker)
end

local function stripPacket(pkt)
	return pkt:sub(2, -2):gsub(startMarker..startMarker, startMarker):gsub(endMarker..endMarker, endMarker)
end

local function countBufferedPackets(buffer)
	local i = 1
	while #buffer > 0 and i <= #buffer do
		local startPos = containsBegin(buffer[i])
		if startPos then
			local endPos, endPkt
			for j = i, #buffer do
				endPos = containsEnd(buffer[j])
				endPkt = j
				if endPos then break end
			end

			if endPos then
				local pkt = {buffer[i]:sub(startPos)}
				for j = i+1, endPkt-1 do
					table.insert(pkt, buffer[j])
				end
				table.insert(pkt, buffer[endPkt]:sub(1, endPos))

				if endPkt == i then
					pkt = {buffer[i]:sub(startPos, endPos)}
				end

				table.insert(buffer.packets, (stripPacket(table.concat(pkt))))

				for j = i, endPkt-1 do
					table.remove(buffer, i)
				end

				if #buffer[i] > endPos then
					buffer[i] = buffer[i]:sub(endPos+1)
				else
					table.remove(buffer, i)
				end
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end

	return #buffer.packets
end

--- CLIENT ---

local udpPlusClient = {}

function udpPlusClient:_connect()
	self._buffer = { packets = {} }
	self._bufferedPackets = 0
	return true
end

function udpPlusClient:_send(data)
	local packets = createPackets(data)
	local succ, err
	for i, v in ipairs(packets) do
		succ, err = parentClient._send(self, v)
		if not succ then
			return succ, err
		end
	end

	return true
end

function udpPlusClient:_receive()
	if self._bufferedPackets > 0 then
		local data = getBufferedPacket(self._buffer)
		self._bufferedPackets = self._bufferedPackets - 1
		return data
	end

	local data, err = parentClient._receive(self)
	if not data then
		return false, err
	end

	table.insert(self._buffer, data)

	if containsEnd(data) then
		self._bufferedPackets = countBufferedPackets(self._buffer) - 1
		return getBufferedPacket(self._buffer)
	end
end

--- SERVER ---

local udpPlusServer = {}

function udpPlusServer:_listen()
	self._buffer = {}
	return parentServer._listen(self)
end

function udpPlusServer:send(data, clientid)
	local packets = createPackets(data)
	local succ, err
	for i, v in ipairs(packets) do
		succ, err = parentServer.send(self, v, clientid)
		if not succ then
			return succ, err
		end
	end

	return true
end

function udpPlusServer:receive()
	for i, v in pairs(self._buffer) do
		if #v.packets > 0 then
			return getBufferedPacket(v), i
		end
	end

	local data, clientid = parentServer.receive(self)
	if not data then
		return false, clientid
	end

	if not self._buffer[clientid] then
		--FIXME cleanup!
		self._buffer[clientid] = { packets = {} }
	end
	table.insert(self._buffer[clientid], data)

	if containsEnd(data) then
		countBufferedPackets(self._buffer[clientid])
		return getBufferedPacket(self._buffer[clientid]), clientid
	end
end


return function(client, server)
	parentClient = client
	parentServer = server
	return {udpPlusClient, udpPlusServer}
end
