----------------------------
--- Remote Code Executor ---
--Program that exposes an api
--over rednet that allows for
--remote control of the 
--computer.

-----------------------------------
--               API             --
---@class Request
---@field type "call" | "storeFunc" | "store" | "read" | "readAll" | "clear"
---@field data string[]

---@class Reply
---@field type any

---@type string[]
local arg = {...}
local g_modems = {peripheral.find("modem")}
---@type {[string]: fun(g_data: table)}
local g_functions = {}
local g_data = {}
local g_api = {
    ---@param funcName string --Function name
    call = function (funcName)
        local func = g_functions[funcName]
        if func == nil then
            error("No function called \""..funcName.."\"")
        end
        return func(g_data)
    end,
    ---@param code string --Code to be stored
    ---@param name string --Name of function, must have single parameter for g_data
    storeFunc = function (code, name)
        if g_functions[name] == nil then
            local func, status = loadstring(code)
            if func == nil then
                error("Function store failed with \""..status.."\"")
            end
            g_functions[name] = func
        end
    end,
    ---@param name string
    ---@param value any
    store = function (name, value)
        g_data[name] = value
    end,
    ---@param name string
    read = function (name)
        return g_data[name]
    end
}


--Validate channel arguments
---@type number[]
local channels = {}
if arg == nil then
    return "Usage:\n  - Channel: [number, ...]"
end
for i, channel in ipairs(arg) do
    local n_channel = tonumber(channel)
    if n_channel == nil then
        return "Usage:\n  - Channel: [number, ...]"
    end
    channels[i] = n_channel
end

--Open modems
for i, modem in ipairs(g_modems) do
    modem.closeAll()
    for k, channel in ipairs(channels) do
        modem.open(channel)
    end
end

local function mainLoop ()
    while true do
        os.pullEvent("modem_message")
    end
end