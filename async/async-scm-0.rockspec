package = "async"
version = "scm-0"

source = {
	url = "git://github.com/bartbes/love-misc-libs.git",
	dir = "love-misc-libs/async",
}

description = {
	summary = "A love library for asynchronous background computation",
	detailed = [[
		Async is a library for LÖVE (http://love2d.org) that enables
		thread-based asynchronous computation. It allows defining arbitrary
		asynchronous functions, and has a configurable, flexible amount of
		worker threads.
	]],
	homepage = "http://docs.bartbes.com/async",
	license = "Simplified BSD license",
}

dependencies = {
	"lua >= 5.1",
	"love ~> 0.9",
}

build = {
	type = "builtin",
	modules = {
		async = "async.lua"
	}
}
