local async = {}

local function threadfunc(...)
	local requestChannel, returnChannel = ...

	require "love.filesystem"

	local functions = {}

	local isolatemt = {__index = _G}
	local function isolate(f)
		local env = setmetatable({}, isolatemt)
		setfenv(f, env)
		return f
	end

	local keepRunning = true

	local interface = {
		define = function(name, contents)
			functions[name] = loadstring(contents)
		end,

		call = function(id, name, ...)
			if not functions[name] then
				return print("Async thread received call to unknown function: '" .. name .. "'")
			end

			if not pcall(returnChannel.push, returnChannel, {id, pcall(isolate(functions[name]), ...)}) then
				returnChannel:push{id, false, "[async] Tried to push unserializable data"}
			end
		end,

		shutdown = function()
			keepRunning = false
			requestChannel:push{"shutdown"}
		end,
	}

	local msg, command
	while keepRunning do
		msg = requestChannel:demand()
		command = table.remove(msg, 1)
		if interface[command] then
			interface[command](unpack(msg))
		else
			print("Async thread received unknown command: '" .. command .. "'")
		end
	end
end
local threaddata = string.dump(threadfunc)

local threads, requestChannel, returnChannel, nextid, cbregistry

function async.load(numthreads)
	requestChannel = love.thread.newChannel()
	returnChannel = love.thread.newChannel()
	nextid = 1
	cbregistry = {}

	threads = {}
	-- TODO At the moment we can only have one thread, because definitions
	-- are thread-local, so we either need to find a way to send definitions
	-- to each thread, or to share them appropriately
	numthreads = 1
	local thread
	for i = 1, numthreads do
		thread = love.thread.newThread(love.filesystem.newFileData(threaddata, "async.lua-thread"))
		thread:start(requestChannel, returnChannel)
		threads[i] = thread
	end
end

function async.shutdown()
	requestChannel:push{"shutdown"}
	for i, v in ipairs(threads) do
		v:wait()
	end

	threads, requestChannel, returnChannel, cbregistry = nil, nil, nil, nil
end

function async.define(name, func)
	local contents = string.dump(func)
	assert(contents, "Could not dump function, did you use upvalues?")

	requestChannel:push{"define", name, contents}

	return function(cb, ...)
		return async.call(cb, name, ...)
	end
end

function async.call(callback, name, ...)
	local id = nextid
	nextid = id + 1

	cbregistry[id] = callback
	requestChannel:push{"call", id, name, ...}
end

function async.update()
	local result = returnChannel:pop()
	while result do
		local id = table.remove(result, 1)
		local cb = cbregistry[id]
		cbregistry[id] = nil

		if not cb then
			print("Async thread returned a value, but no callback was registered")
		else
			if type(cb) == "table" then
				if table.remove(result, 1) then
					cb.success(unpack(result))
				else
					cb.error(unpack(result))
				end
			elseif table.remove(result, 1) then
				cb(unpack(result))
			else
				-- don't call the callback, do note
				-- it is removed from the registry though
			end
		end

		result = returnChannel:pop()
	end
end

return async
