local protocol = {}

local ESC = "\027"
local STX = "\002"
local ETX = "\003"
local escape_group = ("[%s%s%s]"):format(ESC, STX, ETX)
local packet_pattern = ("%%z%s(.-)%%z%s"):format(STX, ETX)

local function escapechar(c)
	return ESC .. c
end

local function unescapechar(c)
	return c:sub(2, 2)
end

function protocol.escape(text)
	return text:gsub(escape_group, escapechar)
end

function protocol.unescape(escaped)
	return escaped:gsub(ESC .. ".", unescapechar)
end

protocol.typemap = {
	["CONNECT"] = "\001",
	["DISCONNECT"] = "\002",
	["DATA"] = "\003",
	["CONTINUATION"] = "\004",
}

protocol.invtypemap = {}
for i, v in pairs(protocol.typemap) do
	protocol.invtypemap[v] = i
end

function protocol.createheader(type, seqno, contno)
	local hdr = protocol.typemap[type]
	if type == "DATA" or type == "CONTINUATION" then
		return hdr .. string.char(seqno) .. "\0" .. string.char(contno)
	end
	return hdr
end

function protocol.createpacket(header, payload)
	return "\0" .. STX .. header .. payload .. "\0" .. ETX
end

function protocol.findpacket(buffer)
	local start, finish = buffer:find(packet_pattern)
	return start, finish
end

function protocol.gettype(pkt)
	return protocol.invtypemap[pkt:sub(3, 3)]
end

function protocol.getseqno(pkt)
	return string.byte(pkt:sub(4, 4))
end

function protocol.getcontno(pkt)
	return string.byte(pkt:sub(6, 6))
end

function protocol.getdata(pkt)
	local type = protocol.gettype(pkt)
	local start, finish = 4, -3
	if type == "DATA" or type == "CONTINUATION" then
		start = 7
	end

	return protocol.unescape(pkt:sub(start, finish))
end

return {protocol}
