UnitTest("Generic Client instantiation failure", function()
	assert(not pcall(lube.Client))
end)

UnitTest("Generic Server instantiation failure", function()
	assert(not pcall(lube.Server))
end)

UnitTest("Successful UdpClient instantiation", function()
	assert(lube.udpClient())
end)

UnitTest("Successful TcpClient instantiation", function()
	assert(lube.tcpClient())
end)

UnitTest("Successful UdpServer instantiation", function()
	assert(lube.udpServer())
end)

UnitTest("Successful TcpServer instantiation", function()
	assert(lube.tcpServer())
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
	assert(msg == "handshake-\n")
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
