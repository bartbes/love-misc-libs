local mt = {}
local translator = setmetatable({}, mt)

translator.language = nil
translator.fallback = "en_US"
translator.formats = {}
translator.location = "lang"

translator.tbl = {}

local function startsWith(a, b)
	return a:sub(1, #b) == b
end

local function getExtension(fn)
	return fn:match("%.([^%.]+)$")
end

function translator:init()
	if self.language then return self end

	for i, v in ipairs(love.filesystem.getDirectoryItems(self.location)) do
		if not v:match("^%.") then
			assert(self.formats[getExtension(v)], "No format loader specified for language file '" .. v .. "', which was present in the language directory")
		end
	end

	local curlang = os.getenv("LANG") or os.setlocale()
	curlang = curlang:match("^(.-)%..+$") or curlang
	self:setLanguage(curlang)

	return self
end

function translator:setLanguage(lang)
	self.language = lang

	local files = love.filesystem.getDirectoryItems(self.location)
	local target
	for i, v in ipairs(files) do
		if startsWith(v, lang) then
			local ext = getExtension(v)
			assert(self.formats[ext], "No format loader specified for language files with extension '" .. ext .. "'")
			target = {self.formats[ext], self.location .. "/" .. v}
			break
		end
	end

	if not target then
		if lang == self.fallback then
			return error("Can't set language, nor fallback language")
		end
		if lang:match("_") then
			return self:setLanguage(lang:match("^(.-)_"))
		end
		return self:setLanguage(self.fallback)
	end

	self.tbl = target[1](target[2])
	return self
end

function translator:setFallback(lang)
	self.fallback = lang
	return self
end

function translator:setLocation(location)
	self.location = location
	return self
end

function translator:addFormat(extension, loader)
	self.formats[extension] = loader
	return self
end

function translator:translate(str)
	return self.tbl[str] or ("&" .. str)
end

function translator:translateFormatted(str)
	return str:gsub("&(%w+)", function(str)
		return self:translate(str)
	end)
end

mt.__call = translator.translateFormatted

translator:addFormat("lua", function(name)
	return love.filesystem.load(name)()
end)

return translator
