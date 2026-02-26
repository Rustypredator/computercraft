-- CMD Util Library

-- imports
local updater = require("libs.updater")

-- Version of the CMD library
local version = "0.1.3"
-- Maximum volume for a single /clone command in Minecraft
local CLONE_LIMIT = 32768

-- Helper function to safely concatenate output tables
local function concatOutput(output)
    if type(output) == "table" then
        return table.concat(output, "\n")
    end
    return tostring(output or "")
end

-- Forceload all chunks covering a block-coordinate region (min to max, X/Z only)
-- Returns a list of {x, z} chunk coords that were forceloaded, for later removal
local function forceloadRegion(minPos, maxPos)
    local loaded = {}
    -- Convert block coords to chunk coords (floor division by 16)
    local chunkMinX = math.floor(minPos.x / 16)
    local chunkMinZ = math.floor(minPos.z / 16)
    local chunkMaxX = math.floor(maxPos.x / 16)
    local chunkMaxZ = math.floor(maxPos.z / 16)
    -- Ensure min <= max
    if chunkMinX > chunkMaxX then chunkMinX, chunkMaxX = chunkMaxX, chunkMinX end
    if chunkMinZ > chunkMaxZ then chunkMinZ, chunkMaxZ = chunkMaxZ, chunkMinZ end

    for cx = chunkMinX, chunkMaxX do
        for cz = chunkMinZ, chunkMaxZ do
            -- forceload add uses block coordinates; any block inside the chunk works
            local bx = cx * 16
            local bz = cz * 16
            local success, output = commands.exec(string.format("forceload add %d %d", bx, bz))
            if success then
                table.insert(loaded, {x = bx, z = bz})
            else
                print("Forceload add failed at chunk (" .. cx .. ", " .. cz .. "): " .. concatOutput(output))
            end
        end
    end
    return loaded
end

-- Remove forceload for a list of chunk positions returned by forceloadRegion
local function forceloadRemove(loadedList)
    for _, pos in ipairs(loadedList) do
        local success, output = commands.exec(string.format("forceload remove %d %d", pos.x, pos.z))
        if not success then
            print("Forceload remove failed at (" .. pos.x .. ", " .. pos.z .. "): " .. concatOutput(output))
        end
    end
end

-- self update function
local function update()
    local url = "/libs/cmd.lua"
    local versionUrl = "/libs/cmd.ver"
    updater.update(version, url, versionUrl, "libs/cmd.lua")
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

-- Clone region (auto-chunks if volume exceeds the configured block-limit)
-- @param source1: {x, y, z} - first corner of the source region
-- @param source2: {x, y, z} - opposite corner of the source region
-- @param target: {x, y, z} - target position for the cloned region (lowest-coordinate corner)
-- @return success boolean
local function clone(source1, source2, target)
    -- Normalize source coordinates to get actual min/max
    local srcMin = {
        x = math.min(source1.x, source2.x),
        y = math.min(source1.y, source2.y),
        z = math.min(source1.z, source2.z)
    }
    local srcMax = {
        x = math.max(source1.x, source2.x),
        y = math.max(source1.y, source2.y),
        z = math.max(source1.z, source2.z)
    }

    local sizeX = srcMax.x - srcMin.x + 1
    local sizeY = srcMax.y - srcMin.y + 1
    local sizeZ = srcMax.z - srcMin.z + 1

    -- Calculate target max corner
    local tgtMin = {x = target.x, y = target.y, z = target.z}
    local tgtMax = {x = target.x + sizeX - 1, y = target.y + sizeY - 1, z = target.z + sizeZ - 1}

    -- Forceload source and target chunks
    local srcLoaded = forceloadRegion(srcMin, srcMax)
    local tgtLoaded = forceloadRegion(tgtMin, tgtMax)

    local volume = sizeX * sizeY * sizeZ

    -- If within the limit, do a single clone
    if volume <= CLONE_LIMIT then
        local clone_cmd = string.format(
            "clone %d %d %d %d %d %d %d %d %d",
            srcMin.x, srcMin.y, srcMin.z,
            srcMax.x, srcMax.y, srcMax.z,
            target.x, target.y, target.z
        )
        local success, output = commands.exec(clone_cmd)
        if not success then
            print("Clone command failed: " .. concatOutput(output))
        end
        -- Remove forceloads
        forceloadRemove(srcLoaded)
        forceloadRemove(tgtLoaded)
        return success
    end

    -- Volume exceeds limit — split into chunks that fit.
    -- Reduce chunk sizes along X, then Z, then Y until each chunk is within the limit.
    local chunkX = sizeX
    local chunkY = sizeY
    local chunkZ = sizeZ

    if chunkX * chunkY * chunkZ > CLONE_LIMIT then
        chunkX = math.floor(CLONE_LIMIT / (chunkY * chunkZ))
        if chunkX < 1 then chunkX = 1 end
    end
    if chunkX * chunkY * chunkZ > CLONE_LIMIT then
        chunkZ = math.floor(CLONE_LIMIT / (chunkX * chunkY))
        if chunkZ < 1 then chunkZ = 1 end
    end
    if chunkX * chunkY * chunkZ > CLONE_LIMIT then
        chunkY = math.floor(CLONE_LIMIT / (chunkX * chunkZ))
        if chunkY < 1 then chunkY = 1 end
    end

    local allSuccess = true
    local chunkCount = 0

    for ox = 0, sizeX - 1, chunkX do
        for oz = 0, sizeZ - 1, chunkZ do
            for oy = 0, sizeY - 1, chunkY do
                -- Source sub-region
                local cx1 = srcMin.x + ox
                local cy1 = srcMin.y + oy
                local cz1 = srcMin.z + oz
                local cx2 = math.min(cx1 + chunkX - 1, srcMax.x)
                local cy2 = math.min(cy1 + chunkY - 1, srcMax.y)
                local cz2 = math.min(cz1 + chunkZ - 1, srcMax.z)

                -- Corresponding target position (offset from target origin)
                local tx = target.x + ox
                local ty = target.y + oy
                local tz = target.z + oz

                local clone_cmd = string.format(
                    "clone %d %d %d %d %d %d %d %d %d",
                    cx1, cy1, cz1,
                    cx2, cy2, cz2,
                    tx, ty, tz
                )
                local success, output = commands.exec(clone_cmd)
                chunkCount = chunkCount + 1
                if not success then
                    print("Clone chunk " .. chunkCount .. " failed: " .. concatOutput(output))
                    allSuccess = false
                end
            end
        end
    end

    print("Clone completed in " .. chunkCount .. " chunks.")
    -- Remove forceloads
    forceloadRemove(srcLoaded)
    forceloadRemove(tgtLoaded)
    return allSuccess
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
    forceloadRegion = forceloadRegion,
    forceloadRemove = forceloadRemove,
    
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