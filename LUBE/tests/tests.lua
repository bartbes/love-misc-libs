class "lube.testClient" ("lube.Client") {
	_implemented = true,

	createSocket = function(self)
		self.socket = true
	end,

	_connect = function(self)
		self.connected = {host = self.host, port = self.port}
		return true
	end,

	_disconnect = function(self)
		self.connected = false
	end,

	_send = function(self, data)
		self.sent = data
		return true
	end,

	_receive = function(self)
		local msg = self.received
		self.received = nil
		return msg
	end,

	setOption = function(self, option, value)
		local allowed = {
			broadcast = true
		}
		assert(allowed[option])
	end
}

class "lube.testServer" ("lube.Server") {
	_implemented = true,

	createSocket = function(self)
		self.socket = true
	end,

	_listen = function(self)
		self.listening = self.port
	end,

	send = function(self, data, clientid)
		self.sent = {data = data, clientid = clientid}
	end,

	receive = function(self)
		local msg = self.received
		self.received = nil
		if not msg then
			return nil
		end
		return msg.data, msg.clientid
	end,

	accept = function(self)
		self.accepted = true
	end,
}

UnitTest("Generic Client instantiation", function()
	assert(not pcall(lube.Client))
end)

UnitTest("Generic Server instantiation", function()
	assert(not pcall(lube.Server))
end)

UnitTest("UdpClient instantiation", function()
	assert(lube.udpClient())
end)

UnitTest("TcpClient instantiation", function()
	assert(lube.tcpClient())
end)

UnitTest("UdpServer instantiation", function()
	assert(lube.udpServer())
end)

UnitTest("TcpServer instantiation", function()
	assert(lube.tcpServer())
end)

UnitTest("TestClient instantiation", function()
	assert(lube.testClient())
end)

UnitTest("TestServer instantiation", function()
	assert(lube.testServer())
end)

UnitTest("Client connect handshake", function()
	local client = lube.testClient()
	client.handshake = "handshake"

	client:connect("127.0.0.1", 9797, false)

	assert(client.sent == "handshake+\n")
end)

UnitTest("Client disconnect handshake", function()
	local client = lube.testClient()
	client.handshake = "handshake"

	client:connect("127.0.0.1", 9797, false)
	client:disconnect()

	assert(client.sent == "handshake-\n")
end)

UnitTest("Client send", function()
	local client = lube.testClient()
	client:connect("127.0.0.1", 9797, false)

	client:send("hellothere")

	assert(client.sent == "hellothere")
end)

UnitTest("Client receive", function()
	local client = lube.testClient()
	client:connect("127.0.0.1", 9797, false)

	client.received = "hellothere"

	assert(client:receive() == "hellothere")
end)

UnitTest("Client recv callback", function()
	local client = lube.testClient()
	client:connect("127.0.0.1", 9797, false)

	client.received = "hellothere"
	local called = false
	client.callbacks.recv = function(data)
		called = true
		assert(data == "hellothere")
	end

	client:update(5)

	assert(called)
end)

UnitTest("Server connect callback", function()
	local server = lube.testServer()
	server.handshake = "handshake"
	server:listen(9797)

	local called = false
	local clientid = math.random(0, 55)
	server.callbacks.connect = function(id)
		called = true
		assert(id == clientid)
	end

	server.received = { data = server.handshake .. "+\n", clientid = clientid }
	server:update(5)

	assert(called)
end)

UnitTest("Server disconnect callback", function()
	local server = lube.testServer()
	server.handshake = "handshake"
	server:listen(9797)

	local called = false
	local clientid = math.random(0, 55)
	server.callbacks.disconnect = function(id)
		called = true
		assert(id == clientid)
	end

	server.received = { data = server.handshake .. "+\n", clientid = clientid }
	server:update(5)
	server.received = { data = server.handshake .. "-\n", clientid = clientid }
	server:update(5)

	assert(called)
end)

UnitTest("Server recv callback", function()
	local server = lube.testServer()
	server.handshake = "handshake"
	server:listen(9797)

	local called = false
	local clientid = math.random(0, 55)
	server.callbacks.recv = function(data, id)
		called = true
		assert(id == clientid)
		assert(data == "hellothere")
	end

	server.received = { data = server.handshake .. "+\n", clientid = clientid }
	server:update(5)
	server.received = { data = "hellothere", clientid = clientid }
	server:update(5)

	assert(called)
end)

UnitTest("Client ping", function()
	local client = lube.testClient()
	client:setPing(true, 2, "ping")
	client:connect("127.0.0.1", 9797, false)

	client:update(3)

	assert(client.sent == "ping")
end)

UnitTest("Server ping", function()
	local server = lube.testServer()
	server.handshake = "handshake"
	server:setPing(true, 2, "ping")
	server:listen(9797)

	local called = false
	server.callbacks.disconnect = function(id)
		assert(id == 1)
		called = true
	end

	server.received = { data = server.handshake .. "+\n", clientid = 1 }
	server:update(0.1)

	--shouldn't time out yet
	server:update(1)
	assert(not called)

	--should time out
	server:update(5)
	assert(called)
end)

UnitTest("Server generic ping", function()
	local server = lube.testServer()
	server.handshake = "handshake"
	server:setPing(true, 2, "ping")
	server:listen(9797)

	local called = false
	server.callbacks.disconnect = function(id)
		assert(id == 1)
		called = true
	end

	server.received = { data = server.handshake .. "+\n", clientid = 1 }
	server:update(0.1)

	--shouldn't time out yet
	server:update(1)
	assert(not called)

	server.received = { data = "somethingrandom", clientid = 1 }

	--shouldn't time out either
	server:update(5)
	assert(not called)
end)

ImplTest("Udp client connect handshake", function()
	local serv = socket.udp()
	serv:setsockname("*", 9797)
	serv:settimeout(5)

	local client = lube.udpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local msg = serv:receive()
	log("Handshake: " .. msg:gsub("\n", "\\n"))
	assert(msg:match("handshake%+\n?"))
end)

ImplTest("Tcp client connect", function()
	local serv = socket.tcp()
	serv:setoption("reuseaddr", true)
	serv:settimeout(5)
	serv:bind("*", 9797)
	serv:listen(1)

	local client = lube.tcpClient()
	client:connect("127.0.0.1", 9797, false)

	assert(serv:accept())
end)

ImplTest("Tcp client connect handshake", function()
	local serv = socket.tcp()
	serv:setoption("reuseaddr", true)
	serv:settimeout(5)
	serv:bind("*", 9797)
	serv:listen(1)

	local client = lube.tcpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local c = serv:accept()
	local msg = c:receive()
	log("Handshake: " .. msg:gsub("\n", "\\n"))
	assert(msg:match("handshake%+\n?"))
end)

ImplTest("Udp client disconnect handshake", function()
	local serv = socket.udp()
	serv:setsockname("*", 9797)
	serv:settimeout(5)

	local client = lube.udpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local msg = serv:receive()
	log("Connect handshake: " .. msg:gsub("\n", "\\n"))

	client:disconnect()
	msg = serv:receive()
	log("Disconnect handshake: " .. msg:gsub("\n", "\\n"))

	assert(msg:match("handshake%-\n?"))
end)

ImplTest("Tcp client disconnect handshake", function()
	local serv = socket.tcp()
	serv:setoption("reuseaddr", true)
	serv:settimeout(5)
	serv:bind("*", 9797)
	serv:listen(1)

	local client = lube.tcpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local c = serv:accept()
	local msg = c:receive()
	log("Connect handshake: " .. msg:gsub("\n", "\\n"))

	client:disconnect()
	msg = c:receive()
	log("Disconnect handshake: " .. msg:gsub("\n", "\\n"))

	assert(msg:match("handshake%-\n?"))
end)

ImplTest("Udp client recv callback", function()
	local serv = socket.udp()
	serv:setsockname("*", 9797)
	serv:settimeout(5)

	local client = lube.udpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local _, ip, port = serv:receivefrom()
	log(("Message from %s:%d"):format(ip, port))
	serv:sendto("hellothere", ip, port)
	socket.sleep(0.1)

	local called = false
	client.callbacks.recv = function(data)
		log("Message: " .. data)
		called = true
		assert(data == "hellothere")
	end
	client:update(5)

	assert(called)
end)

ImplTest("Udp client receive", function()
	local serv = socket.udp()
	serv:setsockname("*", 9797)
	serv:settimeout(5)

	local client = lube.udpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local _, ip, port = serv:receivefrom()
	log(("Message from %s:%d"):format(ip, port))
	serv:sendto("hellothere", ip, port)
	socket.sleep(0.1)

	local msg = client:receive()
	log("Message: " .. msg)
	assert(msg == "hellothere")
end)

ImplTest("Tcp client recv callback", function()
	local serv = socket.tcp()
	serv:setoption("reuseaddr", true)
	serv:settimeout(5)
	serv:bind("*", 9797)
	serv:listen(1)

	local client = lube.tcpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local c = serv:accept()

	c:send("hellothere")
	socket.sleep(0.1)

	local called = false
	client.callbacks.recv = function(data)
		log("Message: " .. data)
		called = true
		assert(data == "hellothere")
	end
	client:update(5)

	assert(called)
end)

ImplTest("Tcp client receive", function()
	local serv = socket.tcp()
	serv:setoption("reuseaddr", true)
	serv:settimeout(5)
	serv:bind("*", 9797)
	serv:listen(1)

	local client = lube.tcpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local c = serv:accept()

	c:send("hellothere")
	socket.sleep(0.1)

	local msg = client:receive()
	log("Message: " .. msg)
	assert(msg == "hellothere")
end)

ImplTest("Tcp client send", function()
	local serv = socket.tcp()
	serv:setoption("reuseaddr", true)
	serv:settimeout(5)
	serv:bind("*", 9797)
	serv:listen(1)

	local client = lube.tcpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	local c = serv:accept()
	c:receive()

	client:send("hellothere")

	local msg = c:receive(10)
	log("Message: " .. msg)
	assert(msg == "hellothere")
end)

ImplTest("Udp client send", function()
	local serv = socket.udp()
	serv:setsockname("*", 9797)
	serv:settimeout(5)

	local client = lube.udpClient()
	client.handshake = "handshake"
	client:connect("127.0.0.1", 9797, false)

	serv:receive()

	client:send("hellothere")

	local msg = serv:receive()
	log("Message: " .. msg)
	assert(msg == "hellothere")
end)
