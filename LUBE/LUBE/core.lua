--- CLIENT ---

local client = {}
-- A generic client class
-- Implementations are required to implement the following functions:
--  * createSocket() --> Put a socket object in self.socket
--  * success, err = _connect() --> Connect the socket to self.host and self.port
--  * _disconnect() --> Disconnect the socket
--  * success, err = _send(data) --> Send data to the server
--  * message, err = _receive() --> Receive a message from the server
--  * setOption(option, value) --> Set a socket option, options being one of the following:
--      - "broadcast" --> Allow broadcast packets.
-- And they also have to set _implemented to evaluate to true.
--
-- Note that all implementations should have a 0 timeout, except for connecting.

function client:init()
	assert(self._implemented, "Can't use a generic client object directly, please provide an implementation.")
	-- 'Initialize' our variables
	self.host = nil
	self.port = nil
	self.connected = false
	self.socket = nil
	self.callbacks = {
		recv = nil
	}
	self.handshake = nil
	self.ping = nil
end

function client:setPing(enabled, time, msg)
	-- If ping is enabled, create a self.ping
	-- and set the time and the message in it,
	-- but most importantly, keep the time.
	-- If disabled, set self.ping to nil.
	if enabled then
		self.ping = {
			time = time,
			msg = msg,
			timer = time
		}
	else
		self.ping = nil
	end
end

function client:connect(host, port, dns)
	-- Verify our inputs.
	if not host or not port then
		return false, "Invalid arguments"
	end
	-- Resolve dns if needed (dns is true by default).
	if dns ~= false then
		local ip = socket.dns.toip(host)
		if not ip then
			return false, "DNS lookup failed for " .. host
		end
		host = ip
	end
	-- Set it up for our new connection.
	self:createSocket()
	self.host = host
	self.port = port
	-- Ask our implementation to actually connect.
	local success, err = self:_connect()
	if not success then
		self.host = nil
		self.port = nil
		return false, err
	end
	self.connected = true
	-- Send our handshake if we have one.
	if self.handshake then
		self:send(self.handshake .. "+\n")
	end
	return true
end

function client:disconnect()
	if self.connected then
		self:send(self.handshake .. "-\n")
		self:_disconnect()
		self.host = nil
		self.port = nil
	end
end

function client:send(data)
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_send(data)
end

function client:receive()
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_receive()
end

function client:update(dt)
	if not self.connected then return end
	assert(dt, "Update needs a dt!")
	-- First, let's handle ping messages.
	if self.ping then
		self.ping.timer = self.ping.timer + dt
		if self.ping.timer > self.ping.time then
			self:_send(self.ping.msg)
			self.ping.timer = 0
		end
	end
	-- If a recv callback is set, let's grab
	-- all incoming messages. If not, leave
	-- them in the queue.
	if self.callbacks.recv then
		local data, err = self:_receive()
		while data do
			self.callbacks.recv(data)
			data, err = self:_receive()
		end
	end
end


--- SERVER ---

local server = {}
-- A generic server class
-- Implementations are required to implement the following functions:
--  * createSocket() --> Put a socket object in self.socket.
--  * _listen() --> Listen on self.port. (All interfaces.)
--  * send(data, clientid) --> Send data to clientid, or everyone if clientid is nil.
--  * data, clientid = receive() --> Receive data.
--  * accept() --> Accept all waiting clients.
-- And they also have to set _implemented to evaluate to true.
-- Note that all functions should have a 0 timeout.

function server:init()
	assert(self._implemented, "Can't use a generic server object directly, please provide an implementation.")
	-- 'Initialize' our variables
	-- Some more initialization.
	self.clients = {}
	self.handshake = nil
	self.callbacks = {
		recv = nil,
		connect = nil,
		disconnect = nil,
	}
	self.ping = nil
	self.port = nil
end

function server:setPing(enabled, time, msg)
	-- Set self.ping if enabled with time and msg,
	-- otherwise set it to nil.
	if enabled then
		self.ping = {
			time = time,
			msg = msg
		}
	else
		self.ping = nil
	end
end

function server:listen(port)
	-- Create a socket, set the port and listen.
	self:createSocket()
	self.port = port
	self:_listen()
end

function server:update(dt)
	assert(dt, "Update needs a dt!")
	-- Accept all waiting clients.
	self:accept()
	-- Start handling messages.
	local data, clientid = self:receive()
	while data do
		local hs, conn = data:match("^(.+)([%+%-])\n?$")
		if hs == self.handshake and conn == "+" then
			-- If we already knew the client, ignore.
			if not self.clients[clientid] then
				self.clients[clientid] = {ping = -dt}
				if self.callbacks.connect then
					self.callbacks.connect(clientid)
				end
			end
		elseif hs == self.handshake and conn == "-" then
			-- Ignore unknown clients (perhaps they timed out before?).
			if self.clients[clientid] then
				self.clients[clientid] = nil
				if self.callbacks.disconnect then
					self.callbacks.disconnect(clientid)
				end
			end
		elseif not self.ping or data ~= self.ping.msg then
			-- Filter out ping messages and call the recv callback.
			if self.callbacks.recv then
				self.callbacks.recv(data, clientid)
			end
		end
		-- Mark as 'ping receive', -dt because dt is added after.
		-- (Which means a net result of 0.)
		if self.clients[clientid] then
			self.clients[clientid].ping = -dt
		end
		data, clientid = self:receive()
	end
	if self.ping then
		-- If we ping then up all the counters.
		-- If it exceeds the limit we set, disconnect the client.
		for i, v in pairs(self.clients) do
			v.ping = v.ping + dt
			if v.ping > self.ping.time then
				self.clients[i] = nil
				if self.callbacks.disconnect then
					self.callbacks.disconnect(i)
				end
			end
		end
	end
end

return {client, server}
