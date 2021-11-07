local bit = require "bit"
local instruction = require "instruction"
local utils = require "utils"

local machine

function love.load()
	-- initialize machine
	machine = {
		-- memory
		memory = utils.newArray(0x1000, 0x00),
		-- register
		reg_v = utils.newArray(0x10, 0x00),
		pc = 0x0200,
		sp = 0x00,
		i  = 0x0000,
		-- timer
		dt = 0x00,
		st = 0x00,
	}

	-- load internal sprites
	utils.loadInternalSprites(machine.memory)

	-- load rom
	utils.loadRom(machine.memory, "rom.ch8")
end

local updateFlag = false
local interval = 0
function love.update(dt)
	-- set update flag
	interval = interval+dt
	if interval*120 >= 1 then
		updateFlag = true
		interval = 0
	end

	if updateFlag then
		-- update timers
		if machine.dt>0 then
			machine.dt = machine.dt-1
		end
		if machine.st>0 then
			machine.st = machine.st-1
		end

		-- run one cycle
		instruction.runOneCycle(machine)

		-- reset update flag
		updateFlag = false
	end
end

function love.draw()
	-- draw frame
	for i = 0x0000, 0x00FF do
		for j = 7, 0, -1 do
			if utils.getBit(machine.memory[0x0F00+i], j) ~= 0 then
				local index = i*8+(7-j)
				love.graphics.rectangle("fill", index%64*10, math.floor(index/64)*10, 10, 10)
			end
		end
	end
end