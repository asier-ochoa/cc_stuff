-- Code for an automated farm using flint knives
local SIDES = {"top", "bottom", "front", "back", "left", "right"}

local COLLECTOR_ROUTER_NAME = ""
local DEPLOYER_ROUTER_NAME = ""

local COLLECTOR_SIDE = "right"
local DEPLOYER_SIDE = "left"

-- This list represents all states the machine can be in
local STEPS = {"deploying_forwards", "deploying_backwards", "collecting_inching", "collecting_backwards"}
local current_step = 1

local routers = {
	[COLLECTOR_ROUTER_NAME]={methods=nil, state={}},
	[COLLECTOR_CTRL_NAME]={methods=nil, state={}},
	[DEPLOYER_CTRL_NAME]={methods=nil, state={}},
	[DEPLOYER_ROUTER_NAME]={methods=nil, state={}}
}
for k, v in pairs(routers) do
	for i, side in ipairs(SIDES) do
		routers[k].state[side] = {new=false, old=false}	
	end
end


local function getRedRouters()
	routers[COLLECTOR_ROUTER_NAME].methods = peripheral.wrap(COLLECTOR_ROUTER_NAME)
	routers[DEPLOYER_ROUTER_NAME].methods = peripheral.wrap(DEPLOYER_ROUTER_NAME)

	for i, side in ipairs(SIDES) do
		routers[COLLECTOR_ROUTER_NAME].methods.setOutput(side, false)
		routers[DEPLOYER_ROUTER_NAME].methods.setOutput(side, false)
	end
end

local function updateRedstoneState()
	for k, v in pairs(routers) do
		-- Iterate through every side of the block
		for side, rS in pairs(v.state) do
			rS.old = rs.new
			rS.new = v.methods.getInput(side)		
		end
	end
end

-- Activate both clutches (redstone has a 2 tick blocking time)
-- Clutch will be top, gearshift will be right
routers[DEPLOYER_CTRL_NAME].methods.setOutput("top", true)
routers[COLLECTOR_CTRL_NAME].methods.setOutput("top", true)

local function mainLoop()
	os.pullevent("redstone")
	updateRedstoneState()

	{
		"deploying_forwards" = function()
			
			-- Check if deployers reached the end
			if routers[DEPLOYER_ROUTER_NAME].state.top.new and not routers[DEPLOYER_ROUTER_NAME].state.top.old then
				
			else
				
			end
		end,
		"deploying_backwards" = function()
		end,
		"collecting_inching" = function()
		end,
		"collecting_backwards" = function()
		end
	}[STEPS[current_step]]()
end

parallel.waitForAll(mainLoop)
