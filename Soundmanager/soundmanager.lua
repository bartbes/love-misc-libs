--[[
This software is distributed under the terms of the MIT license, also
known as the Expat license.

Copyright (C) 2011 by Bart van Strien and Tommy Brunn

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

soundmanager = {}
soundmanager.queue = {}
soundmanager.playlist = {}
soundmanager.currentsong = -1
soundmanager.playsfx = true
soundmanager.playmusic = true

local function shuffle(a, b)
	return math.random(1, 2) == 1
end

--do the magic
function soundmanager:play(sndData)
	if not self.playsfx then return end
	--make a source out of the sound data
	local src = love.audio.newSource(sndData, "static")
	--put it in the queue
	table.insert(self.queue, src)
	--and play it
	love.audio.play(src)
end

--do the music magic
function soundmanager:playMusic(first, ...)
	if not self.playmusic then return end
	self:stopMusic()
	--decide if we were passed a table or a vararg,
	--and assemble the playlist
	if type(first) == "table" then
		self.playlist = first
	else
		self.playlist = {first, ...}
	end
	self.currentsong = 1
	--play
	love.audio.play(self.playlist[1])
end

function soundmanager:stopMusic()
	--stop all currently playing music
	for i, v in ipairs(self.playlist) do
		love.audio.stop(v)
	end
end

--do some shufflin'
function soundmanager:shuffle(first, ...)
	local playlist
	if type(first) == "table" then
		playlist = first
	else
		playlist = {first, ...}
	end
	table.sort(playlist, shuffle)
	return unpack(playlist)
end

--update
function soundmanager:update(dt)
	--check which sounds in the queue have finished, and remove them
	local removelist = {}
	for i, v in ipairs(self.queue) do
		if v:isStopped() then
			table.insert(removelist, i)
		end
	end
	--we can't remove them in the loop, so use another loop
	for i, v in ipairs(removelist) do
		table.remove(self.queue, v-i+1)
	end
	--advance the playlist if necessary
	if self.playmusic and self.currentsong ~= -1 and self.playlist and self.playlist[self.currentsong]:isStopped() then
		self.currentsong = self.currentsong + 1
		if self.currentsong > #self.playlist then
			self.currentsong = 1
		end
		love.audio.play(self.playlist[self.currentsong])
	end
end
