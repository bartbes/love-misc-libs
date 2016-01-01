-- Get our base modulename, to require the submodules
local modulename = ...
modulename = modulename:match("^(.+)%.init$") or modulename

local function subrequire(sub, ...)
	local mod = require(modulename .. "." .. sub)
	if select('#', ...) > 0 then
		mod = mod(...)
	end
	return unpack(mod)
end

-- Common Class fallback
local fallback = {}
function fallback.class(_, table, parent)
	parent = parent or {}

	local mt = {}
	function mt:__index(name)
		return table[name] or parent[name]
	end
	function mt:__call(...)
		local instance = setmetatable({}, mt)
		instance:init(...)
		return instance
	end

	return setmetatable({}, mt)
end

-- Use the fallback only if not other class
-- commons implemenation is defined
local common = fallback
if _G.common and _G.common.class then
	common = _G.common
end

local grease = {}

-- All the submodules!
local client, server = subrequire "core"
grease.Client = common.class("grease.Client", client)
grease.Server = common.class("grease.Server", server)

local udpClient, udpServer = subrequire "udp"
grease.udpClient = common.class("grease.udpClient", udpClient, grease.Client)
grease.udpServer = common.class("grease.udpServer", udpServer, grease.Server)

local tcpClient, tcpServer = subrequire "tcp"
grease.tcpClient = common.class("grease.tcpClient", tcpClient, grease.Client)
grease.tcpServer = common.class("grease.tcpServer", tcpServer, grease.Server)

local protocol = subrequire("protocol")
local lightningClient, lightningServer = subrequire("lightning", protocol)
grease.lightningClient = common.class("grease.lightningClient", lightningClient, grease.Client)
grease.lightningServer = common.class("grease.lightningServer", lightningServer, grease.Server)

-- If enet is found, load that, too
if pcall(require, "enet") then
	local enetClient, enetServer = subrequire "enet"
	grease.enetClient = common.class("grease.enetClient", enetClient, grease.Client)
	grease.enetServer = common.class("grease.enetServer", enetServer, grease.Server)
end

return grease
