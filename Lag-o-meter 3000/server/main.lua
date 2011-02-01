function recv(data,  ip)
	print(data)
	if data:sub(1, 4) ==  "PING" then
		lube.server:send("PONG " .. data:sub(6))
	end
end

function load()
	love.filesystem.require("LUBE.lua")
	lube.server:Init(2113)
	lube.server:setCallback(recv)
	lube.server:setHandshake("Allô")
end

function update(dt)
	lube.server:update()
end

function draw()
end
