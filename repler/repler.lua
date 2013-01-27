--[[ LICENSE
-- Following is the MIT license as found on
-- http://www.opensource.org/licenses/mit-license.php .

Copyright (c) 2013 Bart van Strien

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local t

local function sprint(...)
	local args = {...}
	for i, v in ipairs(args) do
		args[i] = tostring(v)
	end

	if #args == 0 then
		return nil
	end

	return table.concat(args, "\t")
end

local function doExecute(command)
	command = command:gsub("^=", "return ")
	local success, f = pcall(loadstring, command)
	local results
	if success then
		results = {pcall(f)}
	end

	if not success then
		return sprint(f)
	elseif not table.remove(results, 1) then
		return sprint(results[1])
	else
		return sprint(unpack(results))
	end
end

local function load()
	t = love.thread.newThread("repler-thread",
		love.filesystem.newFileData(
		[[
			require "love.event"

			function prompt()
				io.write("> ")
				return io.read("*l")
			end

			t = love.thread.getThread()
			repeat
				local command = prompt()
				love.event.push("repler", t, command)
				local result = t:demand("result")
				if #result > 0 then
					print(result:sub(2, -1))
				end
			until infinity
		]],
		"replthread"))
	love.handlers.repler = rawget(love.handlers, "repler") or function(thread, command)
		local result = doExecute(command)
		if result == nil then
			t:set("result", "")
		else
			t:set("result", "\"" .. result)
		end
	end
	t:start()
end

return {load = load}
