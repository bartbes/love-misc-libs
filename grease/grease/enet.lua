local enet = require "enet"

--- CLIENT ---

local enetClient = {}
enetClient._implemented = true

function enetClient:createSocket()
	self.socket = enet.host_create()
	self.flag = "reliable"
end

function enetClient:_connect()
	self.socket:connect(self.host .. ":" .. self.port)
	local t = self.socket:service(5000)
	local success, err = t and t.type == "connect"
	if not success then
		err = "Could not connect"
	else
		self.peer = t.peer
	end
	return success, err
end

function enetClient:_disconnect()
	self.peer:disconnect()
	return self.socket:flush()
end

function enetClient:_send(data)
	return self.peer:send(data, 0, self.flag)
end

function enetClient:_receive()
	return (self.peer:receive())
end

function enetClient:setoption(option, value)
	if option == "enetFlag" then
		self.flag = value
	end
end

function enetClient:update(dt)
	if not self.connected then return end
	if self.ping then
		if self.ping.time ~= self.ping.oldtime then
			self.ping.oldtime = self.ping.time
			self.peer:ping_interval(self.ping.time*1000)
		end
	end

	while true do
		local event = self.socket:service()
		if not event then break end

		if event.type == "receive" then
			if self.callbacks.recv then
				self.callbacks.recv(event.data)
			end
		end
	end
end


--- SERVER ---

local enetServer = {}
enetServer._implemented = true

function enetServer:createSocket()
	self.connected = {}
end

function enetServer:_listen()
	self.socket = enet.host_create("*:" .. self.port)
end

function enetServer:send(data, clientid)
	if clientid then
		return self.socket:get_peer(clientid):send(data)
	else
		return self.socket:broadcast(data)
	end
end

function enetServer:receive()
	return (self.peer:receive())
end

function enetServer:accept()
end

function enetServer:update(dt)
	if self.ping then
		if self.ping.time ~= self.ping.oldtime then
			self.ping.oldtime = self.ping.time
			for i = 1, self.socket:peer_count() do
				self.socket:get_peer(i):timeout(5, 0, self.ping.time*1000)
			end
		end
	end

	while true do
		local event = self.socket:service()
		if not event then break end

		if event.type == "receive" then
			local hs, conn = event.data:match("^(.+)([%+%-])\n?$")
			local id = event.peer:index()
			if hs == self.handshake and conn == "+" then
				if self.callbacks.connect then
					self.connected[id] = true
					self.callbacks.connect(id)
				end
			elseif hs == self.handshake and conn == "-" then
				if self.callbacks.disconnect then
					self.connected[id] = false
					self.callbacks.disconnect(id)
				end
			else
				if self.callbacks.recv then
					self.callbacks.recv(event.data, id)
				end
			end
		elseif event.type == "disconnect" then
			local id = event.peer:index()
			if self.connected[id] and self.callbacks.disconnect then
				self.callbacks.disconnect(id)
			end
			self.connected[id] = false
		elseif event.type == "connect" and self.ping then
			event.peer:timeout(5, 0, self.ping.time*1000)
		end
	end
end

return {enetClient, enetServer}
