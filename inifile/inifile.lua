-- Copyright 2011-2013 Bart van Strien. All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without modification, are
-- permitted provided that the following conditions are met:
-- 
--    1. Redistributions of source code must retain the above copyright notice, this list of
--       conditions and the following disclaimer.
-- 
--    2. Redistributions in binary form must reproduce the above copyright notice, this list
--       of conditions and the following disclaimer in the documentation and/or other materials
--       provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY BART VAN STRIEN ''AS IS'' AND ANY EXPRESS OR IMPLIED
-- WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
-- FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL BART VAN STRIEN OR
-- CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
-- ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- 
-- The views and conclusions contained in the software and documentation are those of the
-- authors and should not be interpreted as representing official policies, either expressed
-- or implied, of Bart van Strien.
--
-- The above license is known as the Simplified BSD license.

inifile = {}

local defaultBackend = "io"

local backends = {
	io = {
		lines = function(name) return assert(io.open(name)):lines() end,
		write = function(name, contents) assert(io.open(name, "w")):write(contents) end,
	},
	memory = {
		lines = function(text) return text:gmatch("([^\r\n]+)\r?\n") end,
		write = function(name, contents) return contents end,
	},
}

if love then
	backends.love = {
		lines = love.filesystem.lines,
		write = function(name, contents) love.filesystem.write(name, contents) end,
	}
	defaultBackend = "love"
end

function inifile.parse(name, backend)
	backend = backend or defaultBackend
	local t = {}
	local section
	local comments = {}
	local sectionorder = {}
	local cursectionorder

	for line in backends[backend].lines(name) do

		-- Section headers
		local s = line:match("^%[([^%]]+)%]$")
		if s then
			section = s
			t[section] = t[section] or {}
			cursectionorder = {name = section}
			table.insert(sectionorder, cursectionorder)
		end

		-- Comments
		s = line:match("^;(.+)$")
		if s then
			local commentsection = section or comments
			comments[commentsection] = comments[commentsection] or {}
			table.insert(comments[commentsection], s)
		end

		-- Key-value pairs
		local key, value = line:match("^(%w+)%s-=%s-(.+)$")
		if tonumber(value) then value = tonumber(value) end
		if value == "true" then value = true end
		if value == "false" then value = false end
		if key and value ~= nil then
			t[section][key] = value
			table.insert(cursectionorder, key)
		end
	end

	-- Store our metadata in the __inifile field in the metatable
	return setmetatable(t, {
		__inifile = {
			comments = comments,
			sectionorder = sectionorder,
		}
	})
end

function inifile.save(name, t, backend)
	backend = backend or defaultBackend
	local contents = {}

	-- Get our metadata if it exists
	local metadata = getmetatable(t)
	local comments, sectionorder

	if metadata then metadata = metadata.__inifile end
	if metadata then
		comments = metadata.comments
		sectionorder = metadata.sectionorder
	end

	-- If there are comments before sections,
	-- write them out now
	if comments and comments[comments] then
		for i, v in ipairs(comments[comments]) do
			table.insert(contents, (";%s"):format(v))
		end
		table.insert(contents, "")
	end

	local function writevalue(section, key)
		local value = section[key]
		table.insert(contents, ("%s=%s"):format(key, tostring(value)))
	end

	local function writesection(section, order)
		local s = t[section]
		table.insert(contents, ("[%s]"):format(section))

		-- Write our comments out again, sadly we have only achieved
		-- section-accuracy so far
		if comments and comments[section] then
			for i, v in ipairs(comments[section]) do
				table.insert(contents, (";%s"):format(v))
			end
		end

		-- Write the key-value pairs with optional order
		if order then
			for _, v in ipairs(order) do
				writevalue(s, v)
			end
		else
			for i, _ in pairs(s) do
				writevalue(s, i)
			end
		end

		-- Newline after the section
		table.insert(contents, "")
	end

	-- Write the sections, with optional order
	if sectionorder then
		for _, v in ipairs(sectionorder) do
			writesection(v.name, v)
		end
	else
		for i, _ in pairs(contents) do
			writesection(i)
		end
	end

	return backends[backend].write(name, table.concat(contents, "\n"))
end

return inifile
