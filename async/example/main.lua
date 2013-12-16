local async = require "async"

local done = 0

function love.load()
	async.load(2)

	httprequest = async.define("httprequest", function(url)
		local http = require "socket.http"
		local body, status = http.request(url)
		return body, status -- don't return header table
	end)

	-- VERY BAD IDEA, can block a worker thread indefinitely
	async.define("getinput", function()
		return io.read("*l")
	end)

	httprequest({
		success = function(result)
			print("Got result: ")
			print(result)
			done = done + 1
		end,
		error = function(err)
			error(err)
			done = done + 1
		end,
	}, "http://icanhazip.com")

	httprequest(function(result, status)
		print(result)
		done = done + 1
	end, "http://www.google.com")
end

function love.update(dt)
	async.update()

	if done == 2 then
		print("Press enter to end program")
		async.call(function(input)
			love.event.quit()
		end, "getinput")
		done = -1
	end
end

function love.threaderror(t, err)
	error(err)
end
