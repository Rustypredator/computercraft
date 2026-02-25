-- CMD Util Library

-- imports
local updater = require("libs.updater")

-- Version of the CMD library
local version = "0.1.0"

-- self update function
local function update()
    local url = "/libs/cmd.lua"
    local versionUrl = "/libs/cmd.ver"
    updater.update(version, url, versionUrl, "libs/cmd.lua")
end

-- Helper function to safely concatenate output tables
local function concatOutput(output)
    if type(output) == "table" then
        return table.concat(output, "\n")
    end
    return tostring(output or "")
end

-- Convert int32 array to UUID string (optimized)
local function uuidFromIntArray(a0, a1, a2, a3)
    -- Handle nil or invalid inputs
    if not a0 or not a1 or not a2 or not a3 then
        return nil
    end
    
    local function int32ToBytes(n)
        local b = {}
        for i = 3, 0, -1 do
            b[4 - i] = math.floor(n / (2^(i*8))) % 256
        end
        return b
    end

    -- Pack each int32 into bytes (big-endian)
    local bytes = {}
    for _, int in ipairs({a0, a1, a2, a3}) do
        local b = int32ToBytes(int)
        for i = 1, 4 do
            table.insert(bytes, b[i])
        end
    end

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

-- Get nearest player UUID
local function getNearestPlayerUUID()
    local success, output = commands.exec("data get entity @p UUID")
    if success and output and #output > 0 then
        local data = concatOutput(output)
        local uuidInt = data:match("%[I; ([%-0-9, ]+)%]")
        if uuidInt then
            local a0, a1, a2, a3 = uuidInt:match("([%-0-9]+), ([%-0-9]+), ([%-0-9]+), ([%-0-9]+)")
            if a0 and a1 and a2 and a3 then
                return uuidFromIntArray(tonumber(a0), tonumber(a1), tonumber(a2), tonumber(a3))
            end
        end
    end
    return nil
end

-- Get UUID for a specific player
local function getPlayerUUID(player)
    local success, output = commands.exec("data get entity " .. player .. " UUID")
    if success and output and #output > 0 then
        local data = concatOutput(output)
        local uuidInt = data:match("%[I; ([%-0-9, ]+)%]")
        if uuidInt then
            local a0, a1, a2, a3 = uuidInt:match("([%-0-9]+), ([%-0-9]+), ([%-0-9]+), ([%-0-9]+)")
            if a0 and a1 and a2 and a3 then
                return uuidFromIntArray(tonumber(a0), tonumber(a1), tonumber(a2), tonumber(a3))
            end
        end
    end
    return nil
end

-- Get all players with their UUIDs
local function getAllPlayerUUIDs()
    local players = {}
    local success, player_data = commands.exec("list uuids")

    if success and player_data then
        local output = concatOutput(player_data)
        -- Parse player data from format: "PlayerName (UUID)"
        for player_name, uuid in string.gmatch(output, "([%w_]+)%s+%(([a-f0-9%-]+)%)") do
            table.insert(players, {name = player_name, uuid = uuid})
        end
    end

    return players
end

-- Get list of all online players
local function getOnlinePlayers()
    local players = {}
    local success, output = commands.exec("list")
    
    if success and output and #output > 0 then
        local data = concatOutput(output)
        -- Extract the part after "players online: "
        local players_section = data:match("players online: (.+)")
        if players_section then
            -- Split by ", " to get individual player names
            for name in players_section:gmatch("([%w_]+)") do
                table.insert(players, name)
            end
        end
    end
    
    return players
end

-- Teleport player to target player/entity
local function tp(player, target)
    return commands.exec("tp " .. player .. " " .. target)
end

-- Teleport player to coordinates
local function tpPos(player, pos)
    return commands.exec("tp " .. player .. " " .. pos.x .. " " .. pos.y .. " " .. pos.z)
end

-- Teleport player to coordinates with rotation
local function tpPosRot(player, pos, yaw, pitch)
    return commands.exec("tp " .. player .. " " .. pos.x .. " " .. pos.y .. " " .. pos.z .. " " .. (yaw or "~") .. " " .. (pitch or "~"))
end

-- Get player position
local function getPlayerPos(player)
    local success, output = commands.exec("data get entity " .. player .. " Pos")
    if success and output and #output > 0 then
        local data = concatOutput(output)
        local x, y, z = data:match("%[([%-0-9.]+)d,([%-0-9.]+)d,([%-0-9.]+)d%]")
        if x and y and z then
            return {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
        end
    end
    return nil
end

-- Clear player inventory
local function clearPlayerInventory(player)
    return commands.exec("clear " .. player)
end

-- Give item to player
local function giveItem(player, item, count)
    count = count or 1
    return commands.exec("give " .. player .. " " .. item .. " " .. count)
end

-- Get player inventory
local function getInventory(player)
    local success, output = commands.exec("data get entity " .. player .. " Inventory")
    if success and output then
        return output
    end
    return nil
end

-- Kill player
local function killPlayer(player)
    return commands.exec("kill " .. player)
end

-- Set player gamemode
local function setGamemode(player, gamemode)
    -- gamemode: survival, creative, adventure, spectator
    return commands.exec("gamemode " .. gamemode .. " " .. player)
end

-- Get player health
local function getPlayerHealth(player)
    local success, output = commands.exec("data get entity " .. player .. " Health")
    if success and output and #output > 0 then
        local data = concatOutput(output)
        local health = data:match("(%d+%.?%d*)")
        return health and tonumber(health) or nil
    end
    return nil
end

-- Set player health
local function setPlayerHealth(player, health)
    return commands.exec("data modify entity " .. player .. " Health set value " .. health)
end

-- Clone region
local function clone(source1, source2, target)
    local clone_cmd = string.format(
        "clone %d %d %d %d %d %d %d %d %d",
        source1.x, source1.y, source1.z,
        source2.x, source2.y, source2.z,
        target.x, target.y, target.z
    )
    
    return commands.exec(clone_cmd)
end

-- Fill region with blocks
local function fill(pos1, pos2, block, mode)
    -- mode: replace, destroy, keep, outline, hollow
    mode = mode or "replace"
    local cmd = string.format(
        "fill %d %d %d %d %d %d %s %s",
        pos1.x, pos1.y, pos1.z,
        pos2.x, pos2.y, pos2.z,
        block, mode
    )
    return commands.exec(cmd)
end

-- Set a single block
local function setBlock(pos, block)
    return commands.exec("setblock " .. pos.x .. " " .. pos.y .. " " .. pos.z .. " " .. block)
end

-- Send message to player
local function message(player_name, text)
    -- Escape quotes in text
    text = text:gsub('"', '\\"')
    local cmd = string.format("tellraw %s {\"text\":\"%s\"}", player_name, text)
    return commands.exec(cmd)
end

-- Send colored message to player
local function colorMessage(player_name, text, color)
    text = text:gsub('"', '\\"')
    local cmd = string.format("tellraw %s {\"text\":\"%s\",\"color\":\"%s\"}", player_name, text, color)
    return commands.exec(cmd)
end

-- Broadcast message to all players
local function broadcast(text)
    text = text:gsub('"', '\\"')
    local cmd = string.format("tellraw @a {\"text\":\"%s\"}", text)
    return commands.exec(cmd)
end

-- Ban player
local function banPlayer(player)
    return commands.exec("ban " .. player)
end

-- Unban player
local function unbanPlayer(player)
    return commands.exec("pardon " .. player)
end

-- Execute command as player
local function executeAs(player, cmd)
    return commands.exec("execute as " .. player .. " run " .. cmd)
end

-- Set world time
local function setTime(time)
    return commands.exec("time set " .. time)
end

-- Set weather
local function setWeather(weather)
    -- weather: clear, rain, thunder
    return commands.exec("weather " .. weather)
end

-- Stop server
local function stop()
    return commands.exec("stop")
end

return {
    -- Version and updates
    version = version,
    update = update,
    
    -- Player info functions
    getNearestPlayerName = getNearestPlayerName,
    getNearestPlayerUUID = getNearestPlayerUUID,
    getPlayerUUID = getPlayerUUID,
    getAllPlayerUUIDs = getAllPlayerUUIDs,
    getOnlinePlayers = getOnlinePlayers,
    getPlayerPos = getPlayerPos,
    getPlayerHealth = getPlayerHealth,
    
    -- Teleport functions
    tp = tp,
    tpPos = tpPos,
    tpPosRot = tpPosRot,
    
    -- Inventory functions
    clearPlayerInventory = clearPlayerInventory,
    getInventory = getInventory,
    giveItem = giveItem,
    
    -- Player manipulation
    killPlayer = killPlayer,
    setGamemode = setGamemode,
    setPlayerHealth = setPlayerHealth,
    
    -- World manipulation
    clone = clone,
    fill = fill,
    setBlock = setBlock,
    
    -- Communication
    message = message,
    colorMessage = colorMessage,
    broadcast = broadcast,
    
    -- Server management
    banPlayer = banPlayer,
    unbanPlayer = unbanPlayer,
    executeAs = executeAs,
    setTime = setTime,
    setWeather = setWeather,
    stop = stop,
    
    -- Utility functions
    uuidFromIntArray = uuidFromIntArray,
    concatOutput = concatOutput
}