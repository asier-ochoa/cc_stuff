local ELEVATOR_DETECTION_SIDE = "back"
local REQUEST_SIDE = "front"
local SEND_PORT = 443
local Y_HEIGHT = 30
local C_ID = os.getComputerID()
local NUM_KEYS_SUB = 48

----------------------HELPER FUNCTIONS-----------
---@param modem table --Modem peripheral
---@param port number
---@param data any
---@param timeout number? --In seconds
local function request(modem, port, data, timeout)
    local timerid
    if timeout then
        timerid = os.startTimer(timeout)
    end

    modem.transmit(SEND_PORT, SEND_PORT, data)
    local _, response, channel = nil, nil, nil
    repeat
        local event = {os.pullEvent()}
        if event[1] == "timer" and event[2] == timerid then
            return {status="timeout", recipient=nil, data={}}
        end
        channel, response = event[3], event[5]
    until event[1] == "modem_message" and channel == port and (response ~= nil or response.recipient == C_ID)
    return response
end


local prty = require "cc.pretty"

if type(tonumber(arg[1])) ~= "number" then
    print("Usage:\n  elevator_floor <floor height:int>")
    return
else
    Y_HEIGHT = tonumber(arg[1])
    print("Floor is at height "..Y_HEIGHT)
end

local modem = peripheral.find("modem")
modem.closeAll()
modem.open(SEND_PORT)
if modem == nil then
    error("No modem attached")
end

--Register Floor
repeat
    local implicitElevator = nil
    if redstone.getInput(ELEVATOR_DETECTION_SIDE) then
        implicitElevator = true
    end
    local resp = request(modem, SEND_PORT, 
        {method="registerFloor", c_id=C_ID, msg={y_coord=Y_HEIGHT, elevatorPresent=implicitElevator}}, 5
    )
    if resp.status == "timeout" then
        print("No elevator_main responded, retrying...")
    end
until resp.recipient == C_ID and (resp.status == "success" or resp.data.reason == "Floor already registered")
print("Registered floor")

local function mainLoop()
    --Initialize redstone state tracking
    local elevatorLastRedstoneState = redstone.getInput(ELEVATOR_DETECTION_SIDE)
    local requestLastRestoneState = redstone.getInput(REQUEST_SIDE)
    local elevatorRedstoneState = redstone.getInput(ELEVATOR_DETECTION_SIDE)
    local requestRestoneState = redstone.getInput(REQUEST_SIDE)
    while true do
        local event = {os.pullEvent()}
        if event[1] == "redstone" then
            elevatorLastRedstoneState = elevatorRedstoneState
            elevatorRedstoneState = redstone.getInput(ELEVATOR_DETECTION_SIDE)
            requestLastRestoneState = requestRestoneState
            requestRestoneState = redstone.getInput(REQUEST_SIDE)

            --This means the elevator has arrived
            if not elevatorLastRedstoneState and elevatorRedstoneState then
                print("Elvator has arrived, sending reportElevatorFloor")
                local resp = request(modem, SEND_PORT,
                    {method="reportElevatorFloor", c_id=C_ID, msg={}}
                )
                print("Reponse status: \""..resp.status.."\"")
                if resp.status ~= "success" then
                    print("Reason: "..resp.data.reason)
                end
            end

            --Detect rising edge for requesting elevator
            if not requestLastRestoneState and requestRestoneState then
                print("Requesting elevator")
                local resp = request(
                    modem, SEND_PORT,
                    {method="requestElevator", c_id=C_ID, msg={}}
                )
                print("Reponse status: \""..resp.status.."\"")
                if resp.status ~= "success" then
                    print("Reason: "..resp.data.reason)
                end
            end
        end
        if event[1] == "key" then
            local reqFloor = event[2] - NUM_KEYS_SUB
            print("Attempting to send elevator to floor "..reqFloor)

            local resp = request(
                modem, SEND_PORT,
                {method="goToFloor", c_id=C_ID, msg={floor=reqFloor}}
            )
            print("Reponse status: \""..resp.status.."\"")
            if resp.status ~= "success" then
                print("Reason: "..resp.data.reason)
            end
        end
    end
end

print("Waiting on redstone updates...")

parallel.waitForAll(mainLoop)