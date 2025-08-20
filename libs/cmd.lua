-- CMD Util Library

-- imports
local updater = require("libs.updater")

-- Version of the CMD library
local version = "0.0.7"

-- self update function
local function update()
    local url = "/libs/cmd.lua"
    local versionUrl = "/libs/cmd.ver"
    updater.update(version, url, versionUrl, "libs/cmd.lua")
end

local function getNearestPlayerName(message)
    local success, output = commands.exec("tell @p " .. (message or "dont mind me :)"))
    if success and output and #output > 0 then
        local name = output[1]:match("You whisper to ([^ ]+):")
        name = tostring(name)
        if name and #name > 0 then
            return name
        else
            return "unknown"
        end
    end
end

-- Converts 4 integers to a UUID string
function uuidFromIntArray(a0, a1, a2, a3)
    local bytes = {}
    local function int32ToBytes(n)
        local b = {}
        for i = 3, 0, -1 do
            b[4 - i] = n / (2^(i*8)) % 256
        end
        return b
    end

    -- Pack each int32 into bytes (big-endian)
    local b0 = int32ToBytes(a0)
    local b1 = int32ToBytes(a1)
    local b2 = int32ToBytes(a2)
    local b3 = int32ToBytes(a3)
    for i = 1, 4 do table.insert(bytes, b0[i]) end
    for i = 1, 4 do table.insert(bytes, b1[i]) end
    for i = 1, 4 do table.insert(bytes, b2[i]) end
    for i = 1, 4 do table.insert(bytes, b3[i]) end

    -- Convert bytes to hex string
    local hex = ""
    for i = 1, 16 do
        hex = hex .. string.format("%02x", bytes[i])
    end

    -- Format as UUID: 8-4-4-4-12
    return string.format("%s-%s-%s-%s-%s",
        hex:sub(1,8),
        hex:sub(9,12),
        hex:sub(13,16),
        hex:sub(17,20),
        hex:sub(21,32)
    )
end

local function getNearestPlayerUUID()
    local success, output = commands.exec("data get entity @p UUID")
    if success and output and #output > 0 then
        local uuidInt = output[1]:match("%[I; ([%-0-9, ]+)%]") -- should produce 4 comma separated integers that represent the uuid
		local a0, a1, a2, a3 = uuidInt:match("([%-0-9]+), ([%-0-9]+), ([%-0-9]+), ([%-0-9]+)")
        -- convert int uuid into string uuid:
		local uuidString = uuidFromIntArray(a0, a1, a2, a3)
        return uuidString
    end
end

local function tp(player, target)
    commands.exec("tp " .. player .. " " .. target)
end

local function tpPos(player, x, y, z)
    commands.exec("tp " .. player .. " " .. x .. " " .. y .. " " .. z)
end

local function clearPlayerInventory(player)
    local success, output = commands.exec("clear " .. player)
    if success then
        return true
    end
    return false
end

local function getInventory(player)
    local success, output = commands.exec("data get entity " .. player .. " Inventory")
    if success and output then
        return output
    end
end

return {
    version = version,
    update = update,
    getNearestPlayerName = getNearestPlayerName,
    getNearestPlayerUUID = getNearestPlayerUUID,
    tp = tp,
    tpPos = tpPos,
    clearPlayerInventory = clearPlayerInventory,
    getInventory = getInventory
}