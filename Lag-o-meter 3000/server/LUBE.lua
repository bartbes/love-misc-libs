--[[
	Copyright © 2009 BartBes <bart.bes+nospam@gmail.com>

	Permission is hereby granted, free of charge, to any person
	obtaining a copy of this software and associated documentation
	files (the "Software"), to deal in the Software without
	restriction, including without limitation the rights to use,
	copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following
	conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
	OTHER DEALINGS IN THE SOFTWARE.



	The above license is the MIT/X11 license, check the license for
	information about distribution.

	Also used:
		-LÖVE (ZLIB license) Copyright (C) 2006-2009 LOVE Development Team
			LÖVE itself depends on:
			-Lua
			-OpenGL
			-SDL
			-SDL_mixer
			-FreeType
			-DevIL
			-PhysicsFS
			-Box2D
			-boost
			-SWIG
		-LuaSocket (MIT license) Copyright © 2004-2007 Diego Nehab. All rights reserved.
		-Lua (MIT license) Copyright © 1994-2008 Lua.org, PUC-Rio.
]]--

socket = require "socket"

lube = {}
lube.version = "0.4"
lube.bin = {}
lube.bin.__index = lube.bin

lube.bin.null = string.char(30)
lube.bin.one = string.char(31)
lube.bin.defnull = lube.bin.null
lube.bin.defone = lube.bin.one

function lube.bin:setseperators(null, one)
	null = null or self.defnull
	one = one or self.defone
	self.null = null
	self.one = one
end

function lube.bin:pack(t)
	local result = ""
	for i, v in pairs(t) do
		result = result .. self:packvalue(i, v)
	end
	return result
end

function lube.bin:packvalue(i, v)
	local id = ""
	local typev = type(v)
	if typev == "string" then id = "S"
	elseif typev == "number" then id = "N"
	elseif typev == "boolean" then id = "B"
	elseif typev == "userdata"  then id = "U"
	elseif typev == "nil" then id = "0"
	else error("Type " .. typev .. " is not supported by lube.bin") return
	end
	return tostring(id .. lube.bin.one .. i .. lube.bin.one .. tostring(v) .. lube.bin.null)
end

function lube.bin:unpack(s)
	local t = {}
	local i, v
	for s2 in string.gmatch(s, "[^" .. lube.bin.null .. "]+") do
		i, v = self:unpackvalue(s2)
		t[i] = v
	end
	return t
end

function lube.bin:unpackvalue(s)
	local id = s:sub(1, 1)
	s = s:sub(3)
	local len = s:find(lube.bin.one)
	local i = s:sub(1, len-1)
	local v = s:sub(len+1)
	if id == "N" then v = tonumber(v)
	elseif id == "B" then v = (v == "true")
	elseif id == "0" then v = nil
	end
	return i, v
end

lube.client = {}
lube.client.__index = lube.client
lube.client.udp = {}
lube.client.udp.protocol = "udp"
lube.client.tcp = {}
lube.client.tcp.protocol = "tcp"
lube.client.ping = {}
lube.client.ping.enabled = false
lube.client.ping.time = 0
lube.client.ping.msg = "ping"
lube.client.ping.queue = {}
lube.client.ping.dt = 0
local client_mt = {}
function client_mt:__call(...)
	local t = {}
	local mt = { __index = self }
	setmetatable(t, mt)
	t:Init(...)
	return t
end

setmetatable(lube.client, client_mt)

function lube.client:Init(socktype)
	self.host = ""
	self.port = 0
	self.connected = false
	if socktype then
		if self[socktype] then
			self.socktype = socktype
		elseif love.filesystem.exists(socktype .. ".sock") then
			love.filesystem.require(socktype .. ".sock")
			self[socktype] = _G[socktype]
			self.socktype = socktype
		else
			self.socktype = "udp"
		end
	else
		self.socktype = "udp"
	end
	for i, v in pairs(self[self.socktype]) do
		self[i] = v
	end
	self.socket = socket[self.protocol]()
	self.socket:settimeout(0)
	self.callback = function(data) end
	self.handshake = ""
end

function lube.client:setPing(enabled, time, msg)
	self.ping.enabled = enabled
	if enabled then self.ping.time = time; self.ping.msg = msg; self.ping.dt = time end
end

function lube.client:setCallback(cb)
	if cb then
		self.callback = cb
		return true
	else
		self.callback = function(data) end
		return false
	end
end

function lube.client:setHandshake(hshake)
	self.handshake = hshake
end

function lube.client.udp:connect(host, port, dns)
	if dns then
		host = socket.dns.toip(host)
		if not host then
			return false, "Failed to do DNS lookup"
		end
	end
	self.host = host
	self.port = port
	self.connected = true
	if self.handshake ~= "" then self:send(self.handshake) end
end

function lube.client.udp:disconnect()
	if self.handshake ~= "" then self:send(self.handshake) end
	self.host = ""
	self.port = 0
	self.connected = false
end

function lube.client.udp:send(data)
	if not self.connected then return end
	return self.socket:sendto(data, self.host, self.port)
end

function lube.client.udp:receive()
	if not self.connected then return false, "Not connected" end
	local data, err = self.socket:receive()
	if err then
		return false, err
	end
	return true, data
end

function lube.client.tcp:connect(host, port, dns)
	if dns then
		host = socket.dns.toip(host)
		if not host then
			return false, "Failed to do DNS lookup"
		end
	end
	self.host = host
	self.port = port
	self.socket:connect(self.host, self.port)
	self.connected = true
	if self.handshake ~= "" then self:send(self.handshake) end
end

function lube.client.tcp:disconnect()
	if self.handshake ~= "" then self:send(self.handshake) end
	self.host = ""
	self.port = 0
	self.socket:shutdown()
	self.connected = false
end

function lube.client.tcp:send(data)
	if not self.connected then return end
	if data:sub(-1) ~= "\n" then data = data .. "\n" end
	return self.socket:send(data)
end

function lube.client.tcp:receive()
	if not self.connected then return false, "Not connected" end
	local data, err = self.socket:receive()
	if err then
		return false, err
	end
	return true, data
end

function lube.client:doPing(dt)
	if not self.ping.enabled then return end
	self.ping.dt = self.ping.dt + dt
	if self.ping.dt >= self.ping.time then
		self:send(self.ping.msg)
		self.ping.dt = 0
	end
end

function lube.client:update()
	if not self.connected then return end
	local success, data = self:receive()
	if success then
		self.callback(data)
	end
end

lube.server = {}
lube.server.__index = lube.server
lube.server.udp = {}
lube.server.udp.protocol = "udp"
lube.server.tcp = {}
lube.server.tcp.protocol = "tcp"
lube.server.ping = {}
lube.server.ping.enabled = false
lube.server.ping.time = 0
lube.server.ping.msg = "ping"
lube.server.ping.queue = {}
lube.server.ping.dt = 0
local server_mt = {}
function server_mt:__call(...)
	local t = {}
	local mt = { __index = self }
	setmetatable(t, mt)
	t:Init(...)
	return t
end

setmetatable(lube.server, server_mt)

function lube.server:Init(port, socktype)
	lube.clients = {}

	if socktype then
		if self[socktype] then
			self.socktype = socktype
		elseif love.filesystem.exists(socktype .. ".sock") then
			love.filesystem.require(socktype .. ".sock")
			self[socktype] = _G[socktype]
			self.socktype = socktype
		else
			self.socktype = "udp"
		end
	else
		self.socktype = "udp"
	end
	for i, v in pairs(self[self.socktype]) do
		self[i] = v
	end
	self.socket = socket[self.protocol]()
	self.socket:settimeout(0)
	self.handshake = ""
	self.recvcallback = function(data, ip, port) end
	self.connectcallback = function(ip, port) end
	self.disconnectcallback = function(ip, port) end
	self:startserver(port)
end

function lube.server:setPing(enabled, time, msg)
	self.ping.enabled = enabled
	if enabled then self.ping.time = time; self.ping.msg = msg end
end

function lube.server.udp:receive()
	return self.socket:receivefrom()
end

function lube.server.udp:send(data, rcpt)
	if rcpt then
		return self.socket:sendto(data, rcpt, lube.clients[rcpt])
	else
		local errors = 0
		for ip, port in pairs(lube.clients) do
			if not pcall(self.socket.sendto, self.socket, data, ip, port) then errors = errors + 1 end
		end
		return errors
	end
end

function lube.server.udp:startserver(port)
	self.socket:setsockname("*", port)
end

function lube.server.tcp:receive()
	for i, v in pairs(lube.clientsocks) do
		local data = v:receive()
		if data then return data, v:getpeername() end
	end
end

function lube.server.tcp:send(data, rcpt)
	if data:sub(-1) ~= "\n" then data = data .. "\n" end
	if rcpt then
		return lube.clientsocks[rcpt]:send(data)
	else
		local errors = 0
		for i, v in pairs(lube.clientsocks) do
			if not pcall(v.send, v, data) then errors = errors + 1 end
		end
		return errors
	end
end

function lube.server.tcp:startserver(port)
	lube.clientsocks = {}
	self.socket:bind("*", port)
	self.socket:listen(5)
end

function lube.server.tcp:acceptAll()
	local client = self.socket:accept()
	if client then
		local ip, port = client:getpeername()
		lube.clientsocks[ip] = client
	end
end

function lube.server:setHandshake(hshake)
	self.handshake = hshake
end

function lube.server:setCallback(recv, connect, disconnect)
	if recv then
		self.recvcallback = recv
	else
		self.recvcallback = function(data, ip, port) end
	end
	if connect then
		self.connectcallback = connect
	else
		self.connectcallback = function(ip, port) end
	end
	if disconnect then
		self.disconnectcallback = disconnect
	else
		self.disconnectcallback = function(ip, port) end
	end
	return (recv ~= nil), (connect ~= nil), (disconnect ~= nil)
end

function lube.server:checkPing(dt)
	if not self.ping.enabled then return end
	self.ping.dt = self.ping.dt + dt
	if self.ping.dt >= self.ping.time then
		for ip, port in pairs(self.ping.queue) do
			self.disconnectcallback(ip, port)
			lube.clients[ip] = nil
		end
		self.ping.dt = 0
		self.ping.queue = {}
		for ip, port in pairs(lube.clients) do
			self.ping.queue[ip] = port
		end
	end
end

function lube.server:update()
	local data, ip, port = self:receive()
	if data then
		if data == self.handshake then
			if lube.clients[ip] then
				lube.clients[ip] = nil
				return self.disconnectcallback(ip, port)
			else
				lube.clients[ip] = port
				return self.connectcallback(ip, port)
			end
		elseif data == self.ping.msg then
			self.ping.queue[ip] = nil
			return
		end
		return self.recvcallback(data, ip, port)
	end
end

lube.easy = {}
lube.easy.timer = 0
lube.easy.keycharset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890!@#$%*()`~-_=+[]{};:'\",<.>/?\\|"

function lube.easy.generateKey(keylength)
	math.randomseed(os.time())
	local key = ""
	for i = 1, keylength do
		local rand = math.random(#lube.easy.keycharset)
		key = key .. lube.easy.keycharset:sub(rand, rand)
	end
	return key
end

function lube.easy:settable(data)
	local t = self.deserializer(data)
	for i, v in pairs(t) do
		self.table[i] = v
	end
end

function lube.easy:gettable()
	return self.serializer(self.table)
end

function lube.easy:server(port, table, serializer, deserializer, rate, object, keylength)
	keylength = keylength or 512
	self.type = "server"
	self.port = port
	self.table = table
	self.serializer = serializer
	self.deserializer = deserializer
	self.rate = rate
	self.object = object
	self.object:Init(port)
	self.object:setCallback(self.sreceive, self.sconnect)
	self.object:setHandshake("EasyLUBE")
	self.key = self.generateKey(keylength)
end

function lube.easy:client(host, port, table, serializer, deserializer, rate, object)
	self.type = "client"
	self.port = port
	self.table = table
	self.serializer = serializer
	self.deserializer = deserializer
	self.rate = rate
	self.object = object
	self.object:Init()
	self.object:setCallback(self.creceive)
	self.object:setHandshake("EasyLUBE")
	self.object:connect(host, port, true)
	self.object:send("RequestKeyFromEasyLUBEServer")
end

function lube.easy.sreceive(data, ip, port)
	if data:gfind("(.*)\n\n")() == lube.easy.key then
		lube.easy:settable(data:gfind(".*\n\n(.*)")())
	elseif data == "RequestKeyFromEasyLUBEServer" then
		lube.easy.object:send(lube.easy.key)
	end
end

function lube.easy.creceive(data)
	if not lube.easy.key then
		lube.easy.key = data
	elseif data:gfind("(.*)\n\n")() == lube.easy.key then
		lube.easy:settable(data:gfind(".*\n\n(.*)")())
	end
end

function lube.easy:update(dt)
	self.object:update()
	if not self.key then return end
	self.timer = self.timer + dt
	if self.timer >= self.rate then
		local s = self.key .. "\n\n"
		s = s .. self:gettable()
		self.object:send(s)
		self.timer = 0
	end
end
