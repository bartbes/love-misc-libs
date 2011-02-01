--[[Copyright (c) 2009 Bart Bes

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
]]

require "socket"
love.filesystem.require("SECS.lua")

servbrowser = class:new()

servbrowser.discover = "SERVBROWSER_DISCOVER"
servbrowser.poll = "SERVBROWSER_POLL"
servbrowser.identify = "SERVER_IDENTIFY"
servbrowser.info = "SERVER_INFO"

function servbrowser:init(port)
	self.port = port
	self.servers = {}
	self.socket = socket.udp()
	self.socket:setoption("broadcast", true)
	self.socket:settimeout(0.1)
end

function servbrowser:setport(port)
	self.port = port
end

function servbrowser:search()
	self.socket:sendto(self.discover, "255.255.255.255", self.port)
end

function servbrowser:receive()
	data, ip, port = self.socket:receivefrom()
	if not data then return nil end
	if data == self.identify then
		table.insert(self.servers, {ip = ip, port = port})
		return #self.servers
	end
	return nil
end

function servbrowser:pollserver(id)
	self.socket:sendto(self.poll, self.servers[id].ip, self.servers[id].port)
	self.socket:settimeout(2)
	data, ip, port = self.socket:receivefrom()
	self.socket:settimeout(0.1)
	if not data then return nil end
	if data:sub(1, #self.info) == self.info and ip == self.servers[id].ip then
		local name, version, additional = data:gmatch(self.info .. ":([^:]*):([^:]*):(.*)")()
		args = {}
		for s in additional:gmatch("([^:]*)") do
			table.insert(args, s)
		end
		if name and version then
			self.servers[id].name = name
			self.servers[id].version = version
			self.servers[id].args = args
		end
		return name, version, args
	end
	return nil
end

