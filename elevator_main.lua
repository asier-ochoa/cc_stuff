-------------------------------
--- Smug's Elevator Control ---
--This program acts as the
--controller for the elevator
--mechanism.
--This program can receive 
--requests to 
--------TODO: Add computer id to responses
-------------------------------

---@class BaseMessage
---@field method string 
---@field c_id integer --Requester computer id
---@field msg any

---------HELPER FUNCTIONS----------
---@param msg BaseMessage
---@return boolean --Wether message is valid
local function validateMessage(msg)
    if msg.c_id == nil or type(msg.c_id) ~= "number" then
        return false
    end
    if msg.method == nil or type(msg.method) ~= "string" then
        return false
    end
    if msg.msg == nil then
        return false
    end
    return true
end

---@generic T
---@param list T[]
---@param func fun(a: T): boolean
---@return T[]
table.listFind = function (list, func)
    local results = {}
    for index, value in ipairs(list) do
        if func(value) then
            table.insert(results, value)
        end
    end
    return results
end
-----------------------------------

local prty = require "cc.pretty"

local LISTEN_CHANNEL = 443
--High is up, low is down
local GEARSHIFT_SIDE = "right"
local CLUTCH_SIDE = "left"
---@type string[]
local arg = {...}
local state = {
    elevatorFloor = nil, --Computer ID of floor where the elvator is
    isElevatorMoving = false,
    lastRequestedFloor = nil,
    rpm = 64,
    ---@type {c_id: number, y_coord: number}[]
    registeredFloors = {}
}
local api = {
    ---@param c_id number --Computer id
    ---@param args {y_coord: number} --y level registering floor
    registerFloor = function (c_id, args)
        local y_coord = args.y_coord
        print("--Floor at Y = "..y_coord)
        --Check if floor already registered
        local result = table.listFind(state.registeredFloors, function (a)
            return a.c_id == c_id
        end)
        if next(result) ~= nil then
            return {
                status = "failure", recipient = c_id, data = {reason = "Floor already registered"}
            }
        end

        table.insert(state.registeredFloors, {c_id=c_id, y_coord=y_coord})
        --Sort floors from lowest to highest
        table.sort(state.registeredFloors, function (a, b)
            return a.y_coord > b.y_coord
        end)
        return {
            status = "success", recipient = c_id, data = {}
        }
    end,
    ---@param c_id number --Computer id
    --Used to receive the floor the elevator is at, stops the elevator if the floor was the last requested
    reportElevatorFloor = function (c_id)
        if state.lastRequestedFloor ~= c_id then
            return {
                status = "failure", data = {reason = "You are not the last requested floor"}
            }
        end
        local result = table.listFind(state.registeredFloors, function (a)
            return a.c_id == c_id
        end)
        if next(result) == nil then
            return {
                status = "failure", data = {reason = "Floor not registered"}
            }
        end
        state.elevatorFloor = result[1].c_id
        state.isElevatorMoving = false
        --Stop the elevator
        redstone.setOutput(CLUTCH_SIDE, true)
        return {
            status = "success", recipient = c_id, data = {}
        }
    end,
    ---@param c_id number --Computer id
    requestElevator = function (c_id)
        --Only move elevator if floor is known and elevator is not moving
        if state.elevatorFloor == nil or state.isElevatorMoving then
            return {
                status = "failure", recipient = c_id, data = {reason = "Elevator is already moving"}
            }
        end
        --Find floor
        local result_requested = table.listFind(state.registeredFloors, function (a)
            return a.c_id == c_id
        end)
        if next(result_requested) == nil then
            return {
                status = "failure", recipient = c_id, data = {reason = "Floor is not registered"}
            }
        end
        local requestedFloorHeight = result_requested[1].y_coord
        local currentFloorHeight = table.listFind(state.registeredFloors, function (a)
            return a.c_id == state.elevatorFloor
        end)[1].y_coord
        if requestedFloorHeight == currentFloorHeight then
            return {
                status = "failure", recipient = c_id, data = {reason = "Elevator is in current floor"}
            }
        end

        --Decide whether to move up or down
        if requestedFloorHeight > currentFloorHeight then
            redstone.setOutput(GEARSHIFT_SIDE, true)
        else
            redstone.setOutput(GEARSHIFT_SIDE, false)
        end
        --Disable clutch until an elevator floor is reported
        redstone.setOutput(CLUTCH_SIDE, false)
        state.isElevatorMoving = true
        state.lastRequestedFloor = result_requested[1].c_id
        return {
            status = "success", data = {}
        }
    end,
    ---@param c_id number --Computer id
    ---@param args {floor: integer}
    goToFloor = function (c_id, args)
        print("Requested to go to floor"..args.floor)
        local floor = state.registeredFloors[args.floor]
        if state.isElevatorMoving or state.elevatorFloor ~= c_id then
            return {
                status = "failure", data = {reason = "Elevator is busy"}
            }
        end
        if floor == nil then
            return {
                status = "failure", data = {reason = "Goto floor doesn't exist"}
            }
        end
        if floor.c_id == c_id then
            return {
                status = "failure", data = {reason = "Elevator already at this floor"}
            }
        end

        local reqYCoord = floor.y_coord
        local currentFloorHeight = table.listFind(state.registeredFloors, function (a)
            return a.c_id == state.elevatorFloor
        end)[1].y_coord
        if reqYCoord > currentFloorHeight then
            redstone.setOutput(GEARSHIFT_SIDE, true)
        else
            redstone.setOutput(GEARSHIFT_SIDE, false)
        end
        redstone.setOutput(CLUTCH_SIDE, false)
        
        state.lastRequestedFloor = floor.c_id
        state.isElevatorMoving = true
        return {
            status = "success", recipient = c_id, data = {}
        }
    end
}

local function mainLoop()
    local modem = peripheral.find("modem")
    modem.closeAll()
    modem.open(LISTEN_CHANNEL)
    if modem == nil then
        error("No modem attached")
    end
    --Make sure clutch is activated
    redstone.setOutput(CLUTCH_SIDE, true)
    while true do
        local _, _, channel, replyChannel, data = os.pullEvent("modem_message")
        if validateMessage(data) then
            print("Received request from computer "..data.c_id.." in channel "..channel)
            ---@cast data BaseMessage
            print("--Attempting to call method "..data.method)
            local status, response = pcall(function ()
                return api[data.method](data.c_id, data.msg)
            end)
            if status == false then
                print("Request failed:\n"..response)
                response = {status="failure", data=response}
            else
                modem.transmit(
                    replyChannel, 0,
                    response
                )
            end
        else
            print("--Invalid message received, ignoring.\n--Details:")
            prty.pretty_print(data)
        end
        --Debug
        print("----STATE INFO----")
        prty.pretty_print(state)
        print("------------------")
    end
end

if type(tonumber(arg[1])) ~= "number" then
    print("Usage:\n  elevator_main <elevator C_ID:int>")
    return
else
    state.elevatorFloor = tonumber(arg[1])
    print("Elevator must be at computer with id "..state.elevatorFloor)
end

print("Started server")
print("Listening...")

parallel.waitForAll(mainLoop)