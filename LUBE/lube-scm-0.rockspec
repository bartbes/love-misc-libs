package = "lube"
version = "scm-0"

source = {
	url = "git://github.com/bartbes/love-misc-libs",
	dir = "love-misc-libs/LUBE"
}

description = {
	summary = "A game-loop centric wrapper module for luasockets",
	detailed = [[
		LUBE is a networking library for lua, using LuaSocket, and optionally
		Lua-ENet. It was designed to operate within the LÖVE framework, but also
		works without it.
	]],
	homepage = "http://docs.bartbes.com/lube",
	license = "MIT"
}

dependencies = {
	"lua ~> 5.1",
	"luasocket",
	-- Optional
	-- "enet",
}

build = {
	type = "builtin",
	modules = {
		["lube.core"] = "LUBE/core.lua",
		["lube.enet"] = "LUBE/enet.lua",
		["lube.init"] = "LUBE/init.lua",
		["lube.tcp"]  = "LUBE/tcp.lua",
		["lube.udp"]  = "LUBE/udp.lua",
	}
}
