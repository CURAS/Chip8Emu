local bit = require "bit"
local utils = require "utils"

local instruction = {}

function instruction.fetchWord(memory, addr)
	return bit.lshift(memory[addr], 8) + memory[addr+1]
end

function instruction.putWord(memory, addr, word)
	memory[addr] = bit.rshift(word, 8)
	memory[addr+1] = bit.band(word, 0x00FF)
end

function instruction.parseInst(inst)
	local byteHigh = bit.rshift(inst, 8)
	local byteLow  = bit.band(inst, 0x00FF)
	local a = bit.rshift(byteHigh, 4)
	local b = bit.band(byteHigh, 0x0F)
	local c = bit.rshift(byteLow, 4)
	local d = bit.band(byteLow, 0x0F)

	if a==0x0 then
		if b==0x0 and byteLow==0xE0 then
			return "CLS"
		elseif b==0x0 and byteLow==0xEE then
			return "RET"
		else
			local addr = bit.band(inst, 0x0FFF)
			return "SYS", addr
		end
	elseif a==0x1 then
		local addr = bit.band(inst, 0x0FFF)
		return "JP", addr
	elseif a==0x2 then
		local addr = bit.band(inst, 0x0FFF)
		return "CALL", addr
	elseif a==0x3 then
		return "SE", utils.regvIndexRev[b], byteLow
	elseif a==0x4 then
		return "SNE", utils.regvIndexRev[b], byteLow
	elseif a==0x5 then
		if d==0x0 then
			return "SE", utils.regvIndexRev[b], utils.regvIndexRev[c]
		end
	elseif a==0x6 then
		return "LD", utils.regvIndexRev[b], byteLow
	elseif a==0x7 then
		return "ADD", utils.regvIndexRev[b], byteLow
	elseif a==0x8 then
		if d==0x0 then
			return "LD", utils.regvIndexRev[b], utils.regvIndexRev[c]
		elseif d==0x1 then
			return "OR", utils.regvIndexRev[b], utils.regvIndexRev[c]
		elseif d==0x2 then
			return "AND", utils.regvIndexRev[b], utils.regvIndexRev[c]
		elseif d==0x3 then
			return "XOR", utils.regvIndexRev[b], utils.regvIndexRev[c]
		elseif d==0x4 then
			return "ADD", utils.regvIndexRev[b], utils.regvIndexRev[c]
		elseif d==0x5 then
			return "SUB", utils.regvIndexRev[b], utils.regvIndexRev[c]
		elseif d==0x6 then
			return "SHR", utils.regvIndexRev[b], utils.regvIndexRev[c]
		elseif d==0x7 then
			return "SUBN", utils.regvIndexRev[b], utils.regvIndexRev[c]
		elseif d==0xE then
			return "SHL", utils.regvIndexRev[b], utils.regvIndexRev[c]
		end
	elseif a==0x9 then
		if d==0x0 then
			return "SNE", utils.regvIndexRev[b], utils.regvIndexRev[c]
		end
	elseif a==0xA then
		local addr = bit.band(inst, 0x0FFF)
		return "LD", "I", addr
	elseif a==0xB then
		local addr = bit.band(inst, 0x0FFF)
		return "JP", "V0", addr
	elseif a==0xC then
		return "RND", utils.regvIndexRev[b], byteLow
	elseif a==0xD then
		return "DRW", utils.regvIndexRev[b], utils.regvIndexRev[c], d
	elseif a==0xE then
		if byteLow==0x9E then
			return "SKP", utils.regvIndexRev[b]
		elseif byteLow==0xA1 then
			return "SKNP", utils.regvIndexRev[b]
		end
	elseif a==0xF then
		if byteLow==0x07 then
			return "LD", utils.regvIndexRev[b], "DT"
		elseif byteLow==0x0A then
			return "LD", utils.regvIndexRev[b], "K"
		elseif byteLow==0x15 then
			return "LD", "DT", utils.regvIndexRev[b]
		elseif byteLow==0x18 then
			return "LD", "ST", utils.regvIndexRev[b]
		elseif byteLow==0x1E then
			return "ADD", "I", utils.regvIndexRev[b]
		elseif byteLow==0x29 then
			return "LD", "F", utils.regvIndexRev[b]
		elseif byteLow==0x33 then
			return "LD", "B", utils.regvIndexRev[b]
		elseif byteLow==0x55 then
			return "LD", "[I]", utils.regvIndexRev[b]
		elseif byteLow==0x65 then
			return "LD", utils.regvIndexRev[b], "[I]"
		end
	end
	return nil
end

function instruction.runOneCycle(machine)
	-- get next insrtuction
	local inst = instruction.fetchWord(machine.memory, machine.pc)
	local cmd, param1, param2, param3 = instruction.parseInst(inst)
	print(string.format("%04X", inst), cmd, param1, param2, param3)

	-- increase pc
	machine.pc = machine.pc+2

	-- execute instruction
	handler[cmd](machine, param1, param2, param3)
end

local handler = {}

function handler.SYS(machine)
	-- ignored
end

function handler.CLS(machine)
	for i = 0x0000, 0x00FF do
		machine.memory[0x0F00+i] = 0x00
	end
end

function handler.CALL(machine, param1)
	machine.sp = machine.sp+2
	instruction.putWord(machine.memory, 0x0EA0+machine.sp-2, machine.pc)
	machine.pc = param1
end

function handler.RET(machine)
	machine.pc = instruction.fetchWord(machine.memory, 0x0EA0+machine.sp-2)
	machine.sp = machine.sp-2
end

function handler.JP(machine, param1, param2)
	if param1 == "V0" then
		machine.pc = param2 + machine.reg_v[0]
	else
		machine.pc = param1
	end
end

function handler.SE(machine, param1, param2)
	local reg1 = utils.regvIndex[param1]
	if type(param2) == "string" then
		local reg2 = utils.regvIndex[param2]
		if machine.reg_v[reg1] == machine.reg_v[reg2] then
			machine.pc = machine.pc+2
		end
	else
		if machine.reg_v[reg1] == param2 then
			machine.pc = machine.pc+2
		end
	end
end

function handler.SNE(machine, param1, param2)
	local reg1 = utils.regvIndex[param1]
	if type(param2) == "string" then
		local reg2 = utils.regvIndex[param2]
		if machine.reg_v[reg1] ~= machine.reg_v[reg2] then
			machine.pc = machine.pc+2
		end
	else
		if machine.reg_v[reg1] ~= param2 then
			machine.pc = machine.pc+2
		end
	end
end

function handler.LD(machine, param1, param2, param3)
	if param1 == "I" then
		machine.i = param2
	elseif param1 == "DT" then
		local reg2 = utils.regvIndex[param2]
		machine.dt = machine.reg_v[reg2]
	elseif param1 == "ST" then
		local reg2 = utils.regvIndex[param2]
		machine.st = machine.reg_v[reg2]
	elseif param1 == "F" then
		local reg2 = utils.regvIndex[param2]
		machine.i = 0x0000 + 5*machine.reg_v[reg2]
	elseif param1 == "B" then
		local reg2 = utils.regvIndex[param2]
		machine.memory[machine.i] = math.floor(machine.reg_v[reg2]/100)
		machine.memory[machine.i+1] = math.floor(machine.reg_v[reg2]/10)%10
		machine.memory[machine.i+2] = machine.reg_v[reg2]%10
	elseif param1 == "[I]" then
		local reg2 = utils.regvIndex[param2]
		for i = 0, reg2 do
			machine.memory[machine.i+i] = machine.reg_v[i]
		end
	elseif param2 == "DT" then
		local reg1 = utils.regvIndex[param1]
		machine.reg_v[reg1] = machine.dt
	elseif param2 == "K" then
		local reg1 = utils.regvIndex[param1]
		local pressed = false
		repeat
			for i = 0, 0xF do
				if love.keyboard.isDown(utils.keyMap[i]) then
					machine.reg_v[reg1] = i
					pressed = true
					break
				end
			end
		until pressed
	elseif param2 == "[I]" then
		local reg1 = utils.regvIndex[param1]
		for i = 0, reg1 do
			machine.reg_v[i] = machine.memory[machine.i+i]
		end
	elseif type(param2) == "string" then
		local reg1 = utils.regvIndex[param1]
		local reg2 = utils.regvIndex[param2]
		machine.reg_v[reg1] = machine.reg_v[reg2]
	else
		local reg1 = utils.regvIndex[param1]
		machine.reg_v[reg1] = param2
	end
end

function handler.ADD(machine, param1, param2)
	if param1 == "I" then
		local reg2 = utils.regvIndex[param2]
		machine.i = machine.i + machine.reg_v[reg2]
	elseif type(param2) == "string" then
		local reg1 = utils.regvIndex[param1]
		local reg2 = utils.regvIndex[param2]
		machine.reg_v[reg1] = bit.band(machine.reg_v[reg1] + machine.reg_v[reg2], 0xFF)
	else
		local reg1 = utils.regvIndex[param1]
		machine.reg_v[reg1] = bit.band(machine.reg_v[reg1] + param2, 0xFF)
	end
end

function handler.OR(machine, param1, param2)
	local reg1 = utils.regvIndex[param1]
	local reg2 = utils.regvIndex[param2]
	machine.reg_v[reg1] = bit.bor(machine.reg_v[reg1], machine.reg_v[reg2])
end

function handler.AND(machine, param1, param2)
	local reg1 = utils.regvIndex[param1]
	local reg2 = utils.regvIndex[param2]
	machine.reg_v[reg1] = bit.band(machine.reg_v[reg1], machine.reg_v[reg2])
end

function handler.XOR(machine, param1, param2)
	local reg1 = utils.regvIndex[param1]
	local reg2 = utils.regvIndex[param2]
	machine.reg_v[reg1] = bit.bxor(machine.reg_v[reg1], machine.reg_v[reg2])
end

function handler.SUB(machine, param1, param2)
	local reg1 = utils.regvIndex[param1]
	local reg2 = utils.regvIndex[param2]
	if machine.reg_v[reg1]>machine.reg_v[reg2] then
		machine.reg_v[0xF] = 1
		machine.reg_v[reg1] = machine.reg_v[reg1] - machine.reg_v[reg2]
	else
		machine.reg_v[0xF] = 0
		machine.reg_v[reg1] = 0x100 + machine.reg_v[reg1] - machine.reg_v[reg2]
	end
end

function handler.SHR(machine, param1)
	local reg1 = utils.regvIndex[param1]
	if bit.band(machine.reg_v[reg1], 0x01) ~= 0x00 then
		machine.reg_v[0xF] = 1
	else
		machine.reg_v[0xF] = 0
	end
	machine.reg_v[reg1] = bit.rshift(machine.reg_v[reg1], 1)
end

function handler.SUBN(machine, param1, param2)
	local reg1 = utils.regvIndex[param1]
	local reg2 = utils.regvIndex[param2]
	if machine.reg_v[reg2]>machine.reg_v[reg1] then
		machine.reg_v[0xF] = 1
		machine.reg_v[reg1] = machine.reg_v[reg2] - machine.reg_v[reg1]
	else
		machine.reg_v[0xF] = 0
		machine.reg_v[reg1] = 0x100 + machine.reg_v[reg2] - machine.reg_v[reg1]
	end
end

function handler.SHL(machine, param1)
	local reg1 = utils.regvIndex[param1]
	if bit.band(machine.reg_v[reg1], 0x80) ~= 0x00 then
		machine.reg_v[0xF] = 1
	else
		machine.reg_v[0xF] = 0
	end
	machine.reg_v[reg1] = bit.band(bit.lshift(machine.reg_v[reg1], 1), 0xFF)
end

function handler.RND(machine, param1, param2)
	local reg1 = utils.regvIndex[param1]
	machine.reg_v[reg1] = bit.band(math.random(0x00, 0xFF), param2)
end

function handler.DRW(machine, param1, param2, param3)
	local reg1 = utils.regvIndex[param1]
	local reg2 = utils.regvIndex[param2]
	local x = machine.reg_v[reg1]
	local y = machine.reg_v[reg2]
	local nibble = param3
	machine.reg_v[0xF] = 0

	for sy = 0, nibble-1 do
		for sx = 0, 7 do
			local index = ((y+sy)%32)*64+(x+sx)%64
			if utils.getBit(machine.memory[machine.i+sy], 7-sx) ~= 0 then
				if utils.getBit(machine.memory[0x0F00 + bit.rshift(index, 3)], 7-bit.band(index, 0x0007)) == 0 then
					machine.memory[0x0F00 + bit.rshift(index, 3)] = utils.setBit(machine.memory[0x0F00 + bit.rshift(index, 3)], 7-bit.band(index, 0x0007), 1)
				else
					machine.memory[0x0F00 + bit.rshift(index, 3)] = utils.setBit(machine.memory[0x0F00 + bit.rshift(index, 3)], 7-bit.band(index, 0x0007), 0)
					machine.reg_v[0xF] = 1
				end
			end
		end
	end
end

function handler.SKP(machine, param1)
	local reg1 = utils.regvIndex[param1]
	if love.keyboard.isDown(utils.keyMap[machine.reg_v[reg1]]) then
		machine.pc = machine.pc+2
	end
end

function handler.SKNP(machine, param1)
	local reg1 = utils.regvIndex[param1]
	if not love.keyboard.isDown(utils.keyMap[machine.reg_v[reg1]]) then
		machine.pc = machine.pc+2
	end
end

return instruction