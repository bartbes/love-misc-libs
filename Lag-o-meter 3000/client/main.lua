pings = {}
lag = {}

function recv(data)
	print(data)
	if data:sub(1, 4) == "PONG" then
		table.insert(lag, mytime - pings[tonumber(data:sub(6))])
		pings[data:sub(6)] = nil
		pending = pending - 1
		if #lag >= 9 then
			table.remove(lag, 1)
		end
	end
end

function load()
	love.filesystem.require("LUBE.lua")
	love.graphics.setFont(love.default_font)
	lube.client:Init()
	lube.client:setCallback(recv)
	lube.client:setHandshake("Allô")
	lube.client:connect("127.0.0.1", 2113)
	timer = 5
	mytime = 0
	pending = 0
end

function update(dt)
	mytime = mytime + dt
	lube.client:update()
	timer = timer + dt
	if timer >= 5 then
		local val = math.random(10000, 99999)
		lube.client:send("PING " .. val)
		pings[val] = mytime
		timer = 0
		pending = pending + 1
	end
	if pending == 0 then
		love.timer.sleep(50)
	end
end

function draw()
	love.graphics.line(20, 580, 580, 580)
	love.graphics.line(20, 20, 20, 580)
	love.graphics.line(100, 20, 100, 580)
	love.graphics.line(180, 20, 180, 580)
	love.graphics.line(260, 20, 260, 580)
	love.graphics.line(340, 20, 340, 580)
	love.graphics.line(420, 20, 420, 580)
	love.graphics.line(500, 20, 500, 580)
	love.graphics.line(580, 20, 580, 580)
	love.graphics.draw("1", 10, 26)
	love.graphics.draw("0",10, 590)
	love.graphics.draw("Lag (s)", 20, 20)
	for i, v in ipairs(lag) do
		love.graphics.point(i*80-60, 580-v*560)
		if i > 1 then love.graphics.line(i*80-140, 580-lag[i-1]*560, i*80-60, 580-v*560) end
	end
end
