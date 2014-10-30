-- Get our base modulename, to require the submodules
local modulename = ...
modulename = modulename:match("^(.+)%.init$") or modulename

local function subrequire(sub)
	return unpack(require(modulename .. "." .. sub))
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

local lube = {}

-- All the submodules!
local client, server = subrequire "core"
lube.Client = common.class("lube.Client", client)
lube.Server = common.class("lube.Server", server)

local udpClient, udpServer = subrequire "udp"
lube.udpClient = common.class("lube.udpClient", udpClient, lube.Client)
lube.udpServer = common.class("lube.udpServer", udpServer, lube.Server)

local tcpClient, tcpServer = subrequire "tcp"
lube.tcpClient = common.class("lube.tcpClient", tcpClient, lube.Client)
lube.tcpServer = common.class("lube.tcpServer", tcpServer, lube.Server)

-- If enet is found, load that, too
if pcall(require, "enet") then
	local enetClient, enetServer = subrequire "enet"
	lube.enetClient = common.class("lube.enetClient", enetClient, lube.Client)
	lube.enetServer = common.class("lube.enetServer", enetServer, lube.Server)
end

return lube
