local socket = require "socket"

--- CLIENT ---

local udpClient = {}
udpClient._implemented = true

function udpClient:createSocket()
	self.socket = socket.udp()
	self.socket:settimeout(0)
end

function udpClient:_connect()
	-- We're connectionless,
	-- guaranteed success!
	return true
end

function udpClient:_disconnect()
	-- Well, that's easy.
end

function udpClient:_send(data)
	return self.socket:sendto(data, self.host, self.port)
end

function udpClient:_receive()
	local data, ip, port = self.socket:receivefrom()
	if ip == self.host and port == self.port then
		return data
	end
	return false, "Unknown remote sent data."
end

function udpClient:setOption(option, value)
	if option == "broadcast" then
		self.socket:setoption("broadcast", not not value)
	end
end


--- SERVER ---

local udpServer = {}
udpServer._implemented = true

function udpServer:createSocket()
	self.socket = socket.udp()
	self.socket:settimeout(0)
end

function udpServer:_listen()
	self.socket:setsockname("*", self.port)
end

function udpServer:send(data, clientid)
	-- We conviently use ip:port as clientid.
	if clientid then
		local ip, port = clientid:match("^(.-):(%d+)$")
		self.socket:sendto(data, ip, tonumber(port))
	else
		for clientid, _ in pairs(self.clients) do
			local ip, port = clientid:match("^(.-):(%d+)$")
			self.socket:sendto(data, ip, tonumber(port))
		end
	end
end

function udpServer:receive()
	local data, ip, port = self.socket:receivefrom()
	if data then
		local id = ip .. ":" .. port
		return data, id
	end
	return nil, "No message."
end

function udpServer:accept()
end


return {udpClient, udpServer}
