local bit = require "bit"

local utils = {}

function utils.newArray(length, default)
	local base = {}
	return setmetatable({}, {
		__index = function(_, key)
			return rawget(base, key+1) or default
		end,
		__newindex = function(_, key, val)
			rawset(base, key+1, val)
		end,
		__len = function()
			return length
		end
	})
end

function utils.getBit(_byte, pos)
	return bit.band(bit.rshift(_byte, pos), 0x01)
end

function utils.setBit(_byte, pos, _bit)
	if _bit == 0 then
		return bit.band(_byte, bit.bnot(bit.lshift(0x01, pos)))
	else
		return bit.bor(_byte, bit.lshift(0x01, pos))
	end
end

function utils.loadInternalSprites(memory)
	-- internal sprites bytes
	local internalSprites = {
		0xF0, 0x90, 0x90, 0x90, 0xF0, -- 0
		0x20, 0x60, 0x20, 0x20, 0x70, -- 1
		0xF0, 0x10, 0xF0, 0x80, 0xF0, -- 2
		0xF0, 0x10, 0xF0, 0x10, 0xF0, -- 3
		0x90, 0x90, 0xF0, 0x10, 0x10, -- 4
		0xF0, 0x80, 0xF0, 0x10, 0xF0, -- 5
		0xF0, 0x80, 0xF0, 0x90, 0xF0, -- 6
		0xF0, 0x10, 0x20, 0x40, 0x40, -- 7
		0xF0, 0x90, 0xF0, 0x90, 0xF0, -- 8
		0xF0, 0x90, 0xF0, 0x10, 0xF0, -- 9
		0xF0, 0x90, 0xF0, 0x90, 0x90, -- A
		0xE0, 0x90, 0xE0, 0x90, 0xE0, -- B
		0xF0, 0x80, 0x80, 0x80, 0xF0, -- C
		0xE0, 0x90, 0x90, 0x90, 0xE0, -- D
		0xF0, 0x80, 0xF0, 0x80, 0xF0, -- E
		0xF0, 0x80, 0xF0, 0x80, 0x80, -- F
	}

	-- copy to memory
	for i = 1, #internalSprites do
		memory[0x0000+i-1] = internalSprites[i]
	end
end

function utils.loadRom(memory, fileName)
	-- read rom content
	local file = io.open(fileName, "rb")
	local content = file:read("*a")
	file:close()

	-- copy to memory
	for i = 1, #content do
		local c = string.sub(content, i, i)
		memory[0x0200+i-1] = string.byte(c)
	end
end

utils.keyMap = utils.newArray(0x10, ' ')
utils.keyMap[0x0] = '1'
utils.keyMap[0x1] = '2'
utils.keyMap[0x2] = '3'
utils.keyMap[0x3] = '4'
utils.keyMap[0x4] = 'q'
utils.keyMap[0x5] = 'w'
utils.keyMap[0x6] = 'e'
utils.keyMap[0x7] = 'r'
utils.keyMap[0x8] = 'a'
utils.keyMap[0x9] = 's'
utils.keyMap[0xA] = 'd'
utils.keyMap[0xB] = 'f'
utils.keyMap[0xC] = 'z'
utils.keyMap[0xD] = 'x'
utils.keyMap[0xE] = 'c'
utils.keyMap[0xF] = 'v'

utils.regvIndex = {
	["V0"] = 0x0, ["V1"] = 0x1, ["V2"] = 0x2, ["V3"] = 0x3, 
	["V4"] = 0x4, ["V5"] = 0x5, ["V6"] = 0x6, ["V7"] = 0x7, 
	["V8"] = 0x8, ["V9"] = 0x9, ["VA"] = 0xA, ["VB"] = 0xB, 
	["VC"] = 0xC, ["VD"] = 0xD, ["VE"] = 0xE, ["VF"] = 0xF, 
}

utils.regvIndexRev = utils.newArray(0x10, "")
for i = 0, 0xF do
	utils.regvIndexRev[i] = "V"..string.format("%X", i)
end

return utils