require "socket"
require "tests.slither"
require "LUBE"

local tests = {}
local testtypes = {
	unit = {},
	impl = {}
}

local mt = {}
mt.__index = {require = require, io = io, print = print, assert = assert, error = error, pcall = pcall, math = math, lube = lube, socket = socket}

class "Test" {
	__init__ = function(self, name, func)
		table.insert(tests, self)
		self.name = name
		local env = setmetatable({}, mt)
		if func then
			self.run = func
		end
		setfenv(self.run, env)
	end,

	run = function()
	end,
}

class "UnitTest" ("Test") {
	__init__ = function(self, ...)
		Test.__init__(self, ...)
		table.insert(testtypes.unit, self)
	end
}

class "ImplTest" ("Test") {
	__init__ = function(self, ...)
		Test.__init__(self, ...)
		table.insert(testtypes.impl, self)
	end
}

function mt.__index.log(message)
	if verbose then
		print(("        %s"):format(message))
	end
end

require "tests.tests"

local args = {...}
if args[1] == "-v" then
	verbose = true
	args[1] = args[2]
end

local testlist = testtypes[args[1]] or tests
local succeeded = 0
local failed = {}

for i, v in ipairs(testlist) do
	print(v.name .. ":")
	local success, err = pcall(v.run, v)
	io.write("    ")
	if success then
		succeeded = succeeded + 1
		print("SUCCESS")
	else
		print("FAIL: " .. err)
		table.insert(failed, v.name)
	end
	collectgarbage("collect")
end

print()
print(("Failures: %d"):format(#testlist-succeeded))
print(("Success rate: %0.2d%%"):format((succeeded/#testlist)*100))
print("Failed tests:")
for i, v in ipairs(failed) do
	print("  " .. v)
end
