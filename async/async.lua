local async = { ensure = {} }

local function threadfunc(...)
	local definitionsChannel, requestChannel, returnChannel = ...

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

		shutdown = function(amount)
			keepRunning = false
			if amount > 1 then
				requestChannel:push{"shutdown", amount-1}
			end
		end,
	}

	local msg, command
	while keepRunning do
		msg = requestChannel:demand()

		-- Update our definitions first
		while true do
			local defs = definitionsChannel:pop()
			if not defs then break end
			for i, v in pairs(defs) do
				functions[i] = loadstring(v)
			end
		end

		-- And only then handle the actual request
		command = table.remove(msg, 1)
		if interface[command] then
			interface[command](unpack(msg))
		else
			print("Async thread received unknown command: '" .. command .. "'")
		end
	end
end
local threaddata = string.dump(threadfunc)

local threads, definitionsChannels,
	requestChannel, returnChannel,
	nextid, cbregistry,
	functionregistry

function async.load(numthreads)
	requestChannel = love.thread.newChannel()
	returnChannel = love.thread.newChannel()
	nextid = 1
	cbregistry = {}
	functionregistry = {}

	threads = {}
	definitionsChannels = {}

	numthreads = numthreads or 1
	for i = 1, numthreads do
		async.addWorker()
	end
end

function async.shutdown()
	requestChannel:push{"shutdown", math.huge}
	for i, v in ipairs(threads) do
		v:wait()
	end

	threads, requestChannel, returnChannel, cbregistry = nil, nil, nil, nil
end

function async.addWorker()
	local thread, definitionsChannel
	local id = #threads+1

	thread = love.thread.newThread(love.filesystem.newFileData(threaddata, "async.lua-thread"))
	definitionsChannel = love.thread.newChannel()

	threads[id] = thread
	definitionsChannels[id] = definitionsChannel

	definitionsChannel:push(functionregistry)
	thread:start(definitionsChannel, requestChannel, returnChannel)
end

function async.stopWorkers(amount)
	requestChannel:push{"shutdown", amount}
end

function async.define(name, func)
	local contents = string.dump(func)
	assert(contents, "Could not dump function, did you use upvalues?")

	functionregistry[name] = contents

	for i, v in ipairs(definitionsChannels) do
		v:push{[name] = contents}
	end

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
	-- Clean up any shut down threads
	for i = #threads, 1, -1 do
		if not threads[i]:isRunning() then
			table.remove(threads, i):wait()
			table.remove(definitionsChannels, i)
		end
	end

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

function async.getWorkerCount()
	return #threads
end

function async.ensure.exactly(n)
	async.ensure.atLeast(n).atMost(n)

	return async.ensure
end

function async.ensure.atLeast(n)
	for i = #threads+1, n do
		async.addWorker()
	end

	return async.ensure
end

function async.ensure.atMost(n)
	if n < #threads then
		async.stopWorkers(n-#threads)
	end

	return async.ensure
end

return async
