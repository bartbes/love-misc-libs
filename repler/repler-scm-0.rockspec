package = "repler"
version = "scm-0"

source = {
	url = "git://github.com/bartbes/love-misc-libs",
	dir = "love-misc-libs/repler"

}
description = {
	summary = "A repl for LOVE programs",
	detailed = [[
		REPLer is a small, and basic library for LÖVE that spawns an extra thread,
		and runs a REPL (read-eval-print-loop) in it. This means that you can
		interactively use lua in your console, while running LÖVE, but wait, there's
		more! Even though this runs in a thread, the actual commands are executed on
		the main thread, this means you can modify the game's environment easily.
	]],
	homepage = "https://github.com/bartbes/love-misc-libs",
	license = "MIT"
}

dependencies = {
	"lua ~> 5.1",
	"love ~> 0.9"
}

build = {
	type = "builtin",
	modules = {
		["repler"] = "repler.lua",
	}
}
