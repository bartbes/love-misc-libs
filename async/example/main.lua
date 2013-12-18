local async = require "async"

function love.load()
	async.load()
	async.ensure.atLeast(2).atMost(3)

	httprequest = async.define("httprequest", function(url)
		local http = require "socket.http"
		local body, status = http.request(url)
		return body, status -- don't return header table
	end)

	-- VERY BAD IDEA, can block a worker thread indefinitely
	print("Press enter to end program")
	async.define("getinput", function()
		return io.read("*l")
	end)(function(input)
		love.event.quit()
	end)

	httprequest({
		success = function(result)
			print("Got result: ")
			print(result)
		end,
		error = function(err)
			error(err)
		end,
	}, "http://icanhazip.com")

	httprequest(function(result, status)
		print(result)
	end, "http://www.google.com")
end

function love.update(dt)
	async.update()
end

function love.threaderror(t, err)
	error(err)
end
