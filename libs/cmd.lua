-- CMD Util Library

-- imports
local updater = require("libs.updater")

-- Version of the CMD library
local version = "0.1.8"
-- Maximum volume for a single /clone command in Minecraft
local CLONE_LIMIT = 32768

-- Helper function to safely concatenate output tables
local function concatOutput(output)
    if type(output) == "table" then
        return table.concat(output, "\n")
    end
    return tostring(output or "")
end

-- Track currently forceloaded regions to avoid redundant load/unload cycles
-- Each entry: { x1, z1, x2, z2, refCount }
local activeForceloads = {}

-- Forceload all chunks covering a block-coordinate region using range syntax.
-- Uses reference counting so nested/overlapping calls don't unload prematurely.
-- If the region exceeds 256 chunks, it is split recursively.
-- @param minPos {x, z} - one corner of the region
-- @param maxPos {x, z} - opposite corner of the region
-- @return table  a handle to pass to forceloadRemove()
local function forceloadRegion(minPos, maxPos)
    -- Normalize to min/max
    local x1 = math.min(minPos.x, maxPos.x)
    local z1 = math.min(minPos.z, maxPos.z)
    local x2 = math.max(minPos.x, maxPos.x)
    local z2 = math.max(minPos.z, maxPos.z)

    -- Calculate chunk dimensions (each chunk is 16x16 blocks)
    local chunkCountX = math.floor((x2 - x1) / 16) + 1
    local chunkCountZ = math.floor((z2 - z1) / 16) + 1
    local totalChunks = chunkCountX * chunkCountZ

    -- If region exceeds 256 chunks, split it recursively
    if totalChunks > 256 then
        local subHandles = {}
        
        -- Split along the longest dimension
        if chunkCountX >= chunkCountZ then
            -- Split along X axis
            local midX = x1 + math.floor((x2 - x1) / 2)
            table.insert(subHandles, forceloadRegion({x = x1, z = z1}, {x = midX, z = z2}))
            table.insert(subHandles, forceloadRegion({x = midX + 1, z = z1}, {x = x2, z = z2}))
        else
            -- Split along Z axis
            local midZ = z1 + math.floor((z2 - z1) / 2)
            table.insert(subHandles, forceloadRegion({x = x1, z = z1}, {x = x2, z = midZ}))
            table.insert(subHandles, forceloadRegion({x = x1, z = midZ + 1}, {x = x2, z = z2}))
        end
        
        -- Create composite handle that tracks all sub-handles
        local handle = {
            x1 = x1, z1 = z1, x2 = x2, z2 = z2,
            refCount = 1,
            subHandles = subHandles,
            isComposite = true
        }
        table.insert(activeForceloads, handle)
        return handle
    end

    -- Check if this exact region is already forceloaded
    for _, entry in ipairs(activeForceloads) do
        if entry.x1 == x1 and entry.z1 == z1 and entry.x2 == x2 and entry.z2 == z2 then
            entry.refCount = entry.refCount + 1
            return entry
        end
    end

    -- New region — single command with range syntax: forceload add <from_x> <from_z> <to_x> <to_z>
    local success, output = commands.exec(string.format("forceload add %d %d %d %d", x1, z1, x2, z2))
    if not success then
        print("Forceload region failed: " .. concatOutput(output))
    else
        -- Wait for chunks to load and generate.
        -- For never-visited areas, chunks must be generated which can take several ticks.
        local outputStr = concatOutput(output)
        if outputStr:find("already") then
            -- Chunks were already force-loaded, just need a tick to sync
            sleep(0.1)
        else
            -- Newly force-loaded chunks — wait for generation, then verify
            sleep(0.5)
            -- Probe the four corners of the region to confirm chunks are accessible.
            -- 'fill ... air keep' is a no-op that requires loaded chunks to succeed.
            local corners = {
                {x = x1, z = z1},
                {x = x1, z = z2},
                {x = x2, z = z1},
                {x = x2, z = z2},
            }
            local allReady = false
            for attempt = 1, 20 do
                allReady = true
                for _, c in ipairs(corners) do
                    local ok = commands.exec(string.format(
                        "fill %d 0 %d %d 0 %d air keep", c.x, c.z, c.x, c.z))
                    if not ok then
                        allReady = false
                        break
                    end
                end
                if allReady then break end
                sleep(0.5)
            end
            if not allReady then
                print("Warning: Some chunks may not be fully generated after waiting.")
            end
        end
    end

    local entry = { x1 = x1, z1 = z1, x2 = x2, z2 = z2, refCount = 1, loaded = success }
    table.insert(activeForceloads, entry)
    return entry
end

-- Forceload all chunks covering a chunk-coordinate region defined by two opposite corners.
-- @param minChunk {x, z} - one corner of the region in chunk coordinates
-- @param maxChunk {x, z} - opposite corner of the region in chunk coordinates
-- @return table  a handle to pass to forceloadRemove()
local function forceLoadChunkRegion(minChunk, maxChunk)
    -- convert to block coordinates and call forceloadRegion.
    -- Each chunk is 16x16 blocks, so multiply by 16. The forceload command is inclusive, so we need to add 15 to the max corner.
    local minPos = {x = minChunk.x * 16, z = minChunk.z * 16}
    local maxPos = {x = maxChunk.x * 16 + 15, z = maxChunk.z * 16 + 15}
    return forceloadRegion(minPos, maxPos)
end

-- Remove forceload for a region handle returned by forceloadRegion.
-- Only actually removes when the last reference is released.
local function forceloadRemove(handle)
    if not handle then return end

    handle.refCount = handle.refCount - 1
    if handle.refCount > 0 then
        return  -- other operations still need these chunks
    end

    -- If this is a composite handle, recursively remove sub-handles
    if handle.isComposite then
        for _, subHandle in ipairs(handle.subHandles) do
            forceloadRemove(subHandle)
        end
    else
        -- Actually remove the forceload
        if handle.loaded then
            local success, output = commands.exec(string.format(
                "forceload remove %d %d %d %d", handle.x1, handle.z1, handle.x2, handle.z2))
            if not success then
                print("Forceload remove failed: " .. concatOutput(output))
            end
        end
    end

    -- Remove from active list
    for i, entry in ipairs(activeForceloads) do
        if entry == handle then
            table.remove(activeForceloads, i)
            break
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

local function getNearestPlayerName(message)
    -- Primary method: get the nearest player's UUID (stable via /data), then
    -- resolve it to a name via /list uuids. This avoids server chat decorations.
    local uuid = getNearestPlayerUUID()
    if uuid then
        local players = getAllPlayerUUIDs()
        for _, p in ipairs(players) do
            if p.uuid == uuid then
                return p.name
            end
        end
    end

    -- Fallback: use /tell and strip any server tags/decorations
    local success, output = commands.exec("tell @p " .. (message or "dont mind me :)"))
    if success and output and #output > 0 then
        local raw = output[1]:match("You whisper to (.+):")
        if raw then
            -- Minecraft usernames are 3-16 characters: letters, digits, underscores only.
            local name = raw:match("[%w_]+$")
            if name and #name >= 3 and #name <= 16 then
                return name
            end
        end
    end

    return "unknown"
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

-- Count how many of a specific item a player has in their inventory.
-- Uses /clear with maxCount 0 which removes nothing but reports the count.
-- @param player: player name
-- @param item: item id (e.g. "minecraft:diamond")
-- @return number  the count of matching items, or 0
local function countItem(player, item)
    local success, output = commands.exec("clear " .. player .. " " .. item .. " 0")
    if success and output and #output > 0 then
        local data = concatOutput(output)
        -- Output format: "Found X matching items on player <name>"
        local count = data:match("Found (%d+)")
        if count then
            return tonumber(count)
        end
    end
    return 0
end

-- Remove a specific number of items from a player's inventory.
-- @param player: player name
-- @param item: item id (e.g. "minecraft:diamond")
-- @param count: number of items to remove
-- @return boolean success
local function clearItem(player, item, count)
    count = count or 1
    local success, output = commands.exec("clear " .. player .. " " .. item .. " " .. count)
    return success
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
-- @param cloneMode: (optional) "force", "move", or "normal" — appended to /clone as 'replace <mode>'
-- @return success boolean
local function clone(source1, source2, target, cloneMode)
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

    -- Build clone mode suffix (e.g. " replace force")
    local modeSuffix = cloneMode and (" replace " .. cloneMode) or ""

    local volume = sizeX * sizeY * sizeZ

    -- If within the limit, do a single clone
    if volume <= CLONE_LIMIT then
        local clone_cmd = string.format(
            "clone %d %d %d %d %d %d %d %d %d",
            srcMin.x, srcMin.y, srcMin.z,
            srcMax.x, srcMax.y, srcMax.z,
            target.x, target.y, target.z
        ) .. modeSuffix
        local success, output = commands.exec(clone_cmd)
        if not success then
            -- Retry — chunks may still be generating
            for retry = 1, 3 do
                sleep(1)
                success, output = commands.exec(clone_cmd)
                if success then break end
            end
            if not success then
                print("Clone command failed: " .. concatOutput(output))
            end
        end
        -- Remove forceloads
        forceloadRemove(srcLoaded)
        forceloadRemove(tgtLoaded)
        return success
    end

    -- Volume exceeds limit — find optimal chunk sizes to minimize total number of splits.
    -- Strategy: try reducing a single axis (pick the one giving fewest total chunks),
    -- then fall back to balanced halving if single-axis reduction is not sufficient.
    local chunkX, chunkY, chunkZ = sizeX, sizeY, sizeZ

    local bestTotal = math.huge
    local bestCX, bestCY, bestCZ = 1, 1, 1

    -- Try reducing each single axis and pick the option with the fewest chunk count
    local axes = {
        {other1 = sizeY, other2 = sizeZ, full = sizeX, axis = "x"},
        {other1 = sizeX, other2 = sizeZ, full = sizeY, axis = "y"},
        {other1 = sizeX, other2 = sizeY, full = sizeZ, axis = "z"},
    }
    for _, opt in ipairs(axes) do
        local otherProduct = opt.other1 * opt.other2
        if otherProduct > 0 and otherProduct <= CLONE_LIMIT then
            local cs = math.floor(CLONE_LIMIT / otherProduct)
            if cs > opt.full then cs = opt.full end
            if cs >= 1 then
                local total = math.ceil(opt.full / cs)
                if total < bestTotal then
                    bestTotal = total
                    if opt.axis == "x" then
                        bestCX, bestCY, bestCZ = cs, sizeY, sizeZ
                    elseif opt.axis == "y" then
                        bestCX, bestCY, bestCZ = sizeX, cs, sizeZ
                    else
                        bestCX, bestCY, bestCZ = sizeX, sizeY, cs
                    end
                end
            end
        end
    end

    if bestTotal < math.huge then
        chunkX, chunkY, chunkZ = bestCX, bestCY, bestCZ
    else
        -- Single-axis reduction insufficient — halve the largest dimension repeatedly
        while chunkX * chunkY * chunkZ > CLONE_LIMIT do
            if chunkX >= chunkY and chunkX >= chunkZ then
                chunkX = math.ceil(chunkX / 2)
            elseif chunkY >= chunkZ then
                chunkY = math.ceil(chunkY / 2)
            else
                chunkZ = math.ceil(chunkZ / 2)
            end
        end
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
                ) .. modeSuffix
                local success, output = commands.exec(clone_cmd)
                if not success then
                    -- Retry — chunks may still be generating
                    for retry = 1, 3 do
                        sleep(1)
                        success, output = commands.exec(clone_cmd)
                        if success then break end
                    end
                end
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

------------------------------------------------------------------------
-- /data command helpers
------------------------------------------------------------------------

-- Get NBT data from a block at the given position
-- @param pos: {x, y, z}
-- @param path: (optional) NBT path, e.g. "Items" or "On"
-- @return success, output
local function dataGetBlock(pos, path)
    local cmd = string.format("data get block %d %d %d", pos.x, pos.y, pos.z)
    if path then
        cmd = cmd .. " " .. path
    end
    return commands.exec(cmd)
end

-- Get NBT data from an entity
-- @param target: entity selector or player name, e.g. "@p" or "Steve"
-- @param path: (optional) NBT path
-- @return success, output
local function dataGetEntity(target, path)
    local cmd = string.format("data get entity %s", target)
    if path then
        cmd = cmd .. " " .. path
    end
    return commands.exec(cmd)
end

-- Merge NBT data into a block
-- @param pos: {x, y, z}
-- @param nbt: SNBT string, e.g. '{On:1b}'
-- @return success, output
local function dataMergeBlock(pos, nbt)
    local cmd = string.format("data merge block %d %d %d %s", pos.x, pos.y, pos.z, nbt)
    return commands.exec(cmd)
end

-- Merge NBT data into an entity
-- @param target: entity selector or player name
-- @param nbt: SNBT string
-- @return success, output
local function dataMergeEntity(target, nbt)
    local cmd = string.format("data merge entity %s %s", target, nbt)
    return commands.exec(cmd)
end

-- Modify a specific NBT path on a block
-- @param pos: {x, y, z}
-- @param path: NBT path, e.g. "On"
-- @param action: "set", "append", "prepend", "insert", "merge"
-- @param value: SNBT value string, e.g. "1b"
-- @return success, output
local function dataModifyBlock(pos, path, action, value)
    local cmd = string.format("data modify block %d %d %d %s %s value %s",
        pos.x, pos.y, pos.z, path, action, value)
    return commands.exec(cmd)
end

-- Remove NBT data from a block
-- @param pos: {x, y, z}
-- @param path: NBT path to remove
-- @return success, output
local function dataRemoveBlock(pos, path)
    local cmd = string.format("data remove block %d %d %d %s", pos.x, pos.y, pos.z, path)
    return commands.exec(cmd)
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
    countItem = countItem,
    clearItem = clearItem,
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
    forceLoadChunkRegion = forceLoadChunkRegion,
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
    
    -- Data (NBT) commands
    dataGetBlock = dataGetBlock,
    dataGetEntity = dataGetEntity,
    dataMergeBlock = dataMergeBlock,
    dataMergeEntity = dataMergeEntity,
    dataModifyBlock = dataModifyBlock,
    dataRemoveBlock = dataRemoveBlock,

    -- Utility functions
    uuidFromIntArray = uuidFromIntArray,
    concatOutput = concatOutput
}