---@class pretty
---@field pretty_print fun(table)
local prty = require "cc.pretty"


---------------------HELPER FUNCTIONS---------------------

---@param filter string? -- Used to match each line of peripheral.getType()
---@return table<string, string> -- Key is the name, value is the type
local function getAllPeripherals(filter)
    ---@type table[]
    local peripheralList = {}
    local filterFunc = function ()
        return true
    end
    if filter ~= nil then
        ---@cast filter string
        filterFunc = string.match
    end
    for i, v in ipairs(peripheral.getNames()) do
        local pType = peripheral.getType(v)
        if filterFunc(pType, filter) ~= nil then
            table[v] = pType
        end
    end
    return peripheralList
end

---@generic T
---@param list T[]
---@param func fun(a: T, i: number?): boolean
---@return T[]
table.listFind = function (list, func)
    local results = {}
    for index, value in ipairs(list) do
        if func(value, index) then
            table.insert(results, value)
        end
    end
    return results
end
-----------------------------------------------------------


---@class ItemDetail
---@field count number
---@field maxCount number
---@field displayName string
---@field name string
---@field tags table<string, boolean>

---@class StorageEntry
---@field peripheral_type string
---@field methods table<string, fun(...): any>
---@field contents (ItemDetail | nil)[]

---@type table<string, StorageEntry> -- Internal representation of all storage chests
local storageTable = {}
---@type string[]
local excludedChests = {}
local combinedItemList = {}

-- Loop through every chest to refresh storageTable
---@param t StorageEntry[]
---@param excluded_chests string[] -- Peripheral names of non-storage chests
local function refreshStorage(t, excluded_chests)
    local chests = getAllPeripherals(".*chest.*")
    for k, v in pairs(chests) do
        if excludedChests[k] == nil then
            ---@type StorageEntry
            local chest = {
                peripheral_type=v,
                methods=peripheral.getMethods(k),
                contents={}
            }
            t[k] = chest

            -- Go through every item in chest, set missing slots as nil
            for i=1, chest.methods.size() do
                local item = chest.methods.getItemDetail(i)
                if item ~= nil then
                    table.insert(chest.contents, {
                        count=item.count,
                        maxCount=item.maxCount,
                        displayName=item.displayName,
                        name=item.name,
                        tags=item.tags
                    })
                else
                    table.insert(chest.contents, nil)
                end
            end
        end
    end
end

---@class ItemSearchResult
---@field count number
---@field locations {peripheral_name: string, item: ItemDetail}[]

---@param t table<string, StorageEntry>
---@return ItemSearchResult
local function findItem(t, itemName, tags, displayName)
    ---@type ItemSearchResult
    local results = {
        count = 0,
        locations = {}
    }
    for k, v in pairs(t) do
        local foundItems = table.listFind(v.contents, function (a)
            if a == nil then
                return false
            else
                return a.name == itemName
            end
        end)
        for i, item in ipairs(foundItems) do
            results.count = results.count + item.count
            table.insert(results.locations, {
                peripheral_name = k,
                item = item
            })
        end
    end
    return results
end
