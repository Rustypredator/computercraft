-- VaultGuard Main Server Script

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("ui")
updater.updateLib("menu")
updater.updateLib("cmd")
-- require the libraries
local ui = require("libs.ui")
local menu = require("libs.menu")
local cmd = require("libs.cmd")

local version = "0.1.2"

local config = {
    checkInterval = 100,
    redstoneInputSide = "top",
    templates = {
        top = {
            min = {x = 29999071, y = 304, z = 29999039},
            max = {x = 29999024, y = 320, z = 29998992}
        },
        bottom = {
            min = {x = 29999071, y = 304, z = 29998992},
            max = {x = 29999024, y = 320, z = 29998944}
        }
    },
    area = {
        size = 3, -- always squared.
        gap = 1,
        spawnOffset = {x = 0, y = 0, z = 0},
    },
    assignArea = {
        min = {x = -28800000, y = -64, z = -28800000},
        max = {x = 28800000, y = 320, z = 28800000}
    },
    areaStorageFolder = "data/areas/",
    areaPlayerMapFile = "data/areaPlayerMap.txt"
}

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/vaultguard/main/main.lua"
    local versionUrl = "/components/vaultguard/main/version"
    -- update this script
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

local Area = {
    loaded = false,
    id = nil,
    playerUuid = nil,
    -- dynamic data:
    slices = nil,
    playermap = nil,
    min = nil,
    max = nil,
    spawn = nil
}

function Area.loadPlayermap()
    -- Ensure directory exists
    local dir = string.match(config.areaPlayerMapFile, "^(.*)/")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    -- load the file:
    local file = fs.open(config.areaPlayerMapFile, "r")
    if file then
        local content = file.readAll()
        file.close()
        -- deserialize the data
        local data = textutils.unserialize(content) or {}
        -- put data in area property
        Area.playermap = data
    else
        Area.playermap = {}
    end
    -- loading done.
    return true
end

function Area.savePlayermap()
    -- Ensure directory exists
    local dir = string.match(config.areaPlayerMapFile, "^(.*)/")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    -- serialize data:
    local data = textutils.serialize({})
    if Area.playermap ~= nil then
        data = textutils.serialize(Area.playermap)
    end
    -- open file for writing
    local file = fs.open(config.areaPlayerMapFile, "w")
    -- write the data
    file.write(data)
    -- close the file
    file.close()
    -- saving successful
    return true
end

function Area.calculateCoordinates()
    -- Calculate coordinates based on area ID, size, and gap
    -- Each area is positioned in a grid pattern
    local areaWidth = config.area.size * 16  -- Convert chunks to blocks (16 blocks per chunk)
    local gapWidth = config.area.gap * 16
    local totalWidth = areaWidth + gapWidth
    
    -- Calculate how many areas fit per row based on assignArea
    -- assignArea coordinates are inclusive, so width = max - min + 1
    local assignWidthX = config.assignArea.max.x - config.assignArea.min.x + 1
    local assignWidthZ = config.assignArea.max.z - config.assignArea.min.z + 1
    local columnsPerRow = math.floor(assignWidthX / totalWidth)
    local rowsPerAssign = math.floor(assignWidthZ / totalWidth)
    
    -- Calculate grid position (columns and rows) starting from assignArea.min
    local columnIndex = (Area.id - 1) % columnsPerRow
    local rowIndex = math.floor((Area.id - 1) / columnsPerRow)
    
    local x_start = config.assignArea.min.x + columnIndex * totalWidth
    local z_start = config.assignArea.min.z + rowIndex * totalWidth
    
    -- Set area min and max coordinates
    Area.min = {x = x_start, y = config.assignArea.min.y, z = z_start}
    Area.max = {x = x_start + areaWidth - 1, y = config.assignArea.max.y, z = z_start + areaWidth - 1}
    
    -- Calculate spawn position: center of the topmost slice, offset from Area.max.y
    -- The topmost slice spans from (Area.max.y - 15) to Area.max.y,
    -- so its vertical center is Area.max.y - 7.
    Area.spawn = {
        x = x_start + math.floor(areaWidth / 2) + config.area.spawnOffset.x,
        y = config.assignArea.max.y - 8 + config.area.spawnOffset.y,
        z = z_start + math.floor(areaWidth / 2) + config.area.spawnOffset.z
    }
end

function Area.loadData(data)
    Area.id = data.id
    Area.playerUuid = data.playerUuid
    Area.slices = data.slices
    Area.calculateCoordinates()
end

function Area.load(areaId)
    -- Load all data for the specified area
    local filePath = config.areaStorageFolder .. areaId .. ".txt"
    
    if fs.exists(filePath) then
        -- File exists, load it
        local file = fs.open(filePath, "r")
        if file then
            local content = file.readAll()
            file.close()
            if content ~= "" then
                local data = textutils.unserialize(content) or {}
                Area.loadData(data)
                Area.loaded = true
                return true
            end
        end
    else
        -- File doesn't exist, create it with default values
        Area.id = areaId
        Area.playerUuid = nil
        Area.slices = {}
        Area.calculateCoordinates()
        
        -- Initialize slices as empty (will be populated when assigned)
        local sliceCount = math.floor((Area.max.y - Area.min.y + 1) / 16)
        for i = 1, sliceCount do
            Area.slices[i] = {
                index = i,
                yMin = Area.min.y + (i - 1) * 16,
                yMax = Area.min.y + i * 16 - 1
            }
        end
        
        -- Save the newly created area
        Area.loaded = true
        Area.save()
        return true
    end
    
    return false
end

function Area.getFirstUnassignedAreaId()
    -- check files for gap in numbering (first non-existent file):
    local free = false
    local counter = 1
    while not free do
        local path = config.areaStorageFolder .. counter .. ".txt"
        -- if the file doesnt exist, return the counter as this is the first free area id.
        if not fs.exists(path) then
            return counter
        end
        counter = counter + 1
    end
    return false
end

function Area.getAreaIdByPlayerUuid(playerUuid)
    -- load the playermap:
    Area.loadPlayermap()
    -- check the playermap if uuid is already present:
    if Area.playermap[playerUuid] ~= nil then
        -- if so, return the assigned area id:
        return Area.playermap[playerUuid]
    end
    -- else return nil:
    return nil
end

function Area.save()
    -- Ensure directory exists
    if not fs.exists(config.areaStorageFolder) then
        fs.makeDir(config.areaStorageFolder)
    end
    -- assemble data to save:
    local saveData = {
        id = Area.id,
        playerUuid = Area.playerUuid,
        slices = Area.slices
    }
    -- serialize the data:
    local content = textutils.serialize(saveData)
    -- write to file:
    local file = fs.open(config.areaStorageFolder .. Area.id .. ".txt", "w")
    file.write(content)
    file.close()
    return true
end

function Area.unload()
    Area.loaded = false
    Area.id = nil
    Area.playerUuid = nil
    Area.slices = nil
    Area.playermap = nil
    Area.min = nil
    Area.max = nil
    Area.spawn = nil
    return true
end

function Area.assign(playerUuid)
    -- assign the area to a player:
    Area.playerUuid = playerUuid
    -- Initialize slices for this area
    -- Each slice represents a vertical 16-block (1-chunk) layer
    local sliceCount = math.floor((Area.max.y - Area.min.y + 1) / 16)
    Area.slices = {}
    for i = 1, sliceCount do
        Area.slices[i] = {
            index = i,
            yMin = Area.min.y + (i - 1) * 16,
            yMax = Area.min.y + i * 16 - 1
        }
    end
    -- Update the playermap
    Area.loadPlayermap()
    Area.playermap[playerUuid] = Area.id
    Area.savePlayermap()
    return true
end

function Area.unassign()
    -- unassign the area.
    Area.playerUuid = nil
    return true
end

local function cloneTemplateToArea()
    -- Clone the top template to the top of the area
    local topTemplateMin = config.templates.top.min
    local topTemplateMax = config.templates.top.max
    local topAreaPos = {x = Area.min.x, y = Area.max.y - 15, z = Area.min.z}  -- Top 16 blocks (1 chunk)
    
    local topSuccess = cmd.clone(topTemplateMin, topTemplateMax, topAreaPos)
    
    if not topSuccess then
        print("Top template clone failed.")
        return false
    end
    
    -- Clone the bottom template to the bottom of the area
    local bottomTemplateMin = config.templates.bottom.min
    local bottomTemplateMax = config.templates.bottom.max
    local bottomAreaPos = {x = Area.min.x, y = Area.min.y, z = Area.min.z}  -- Bottom 16 blocks (1 chunk)
    
    local bottomSuccess = cmd.clone(bottomTemplateMin, bottomTemplateMax, bottomAreaPos)
    
    if not bottomSuccess then
        print("Bottom template clone failed.")
        return false
    end
    
    print("Template clones successful.")
    return true
end

local function teleportToArea(player)
    -- Load the Bunker for the player:
    local areaId = Area.getAreaIdByPlayerUuid(player.uuid)
    if areaId ~= nil then
        -- Load the area to get spawn coordinates
        if Area.load(areaId) then
            if cmd.tpPos(player.name, Area.spawn) then
                print("Teleported " .. player.name .. " to their area.")
            else
                print("Failed to teleport " .. player.name .. " to their area.")
            end
            Area.unload()
        else
            print("Failed to load area " .. areaId .. " for player " .. player.name)
        end
    else
        print("Player " .. player.name .. " has no assigned area.")
    end
end

local function mainLoop()
    local tick_count = 0
    while true do
        tick_count = tick_count + 1

        -- check for redstone input on the configured side:
        if redstone.getInput(config.redstoneInputSide) then
            print("[REDSTONE] Signal detected!")
            -- get nearest player
            local nearestPlayerName = cmd.getNearestPlayerName()
            if nearestPlayerName then
                local nearestPlayerUuid = cmd.getPlayerUUID(nearestPlayerName)
                -- Check if the player already has an area assigned, if not assign one:
                if nearestPlayerUuid then
                    local player = {name = nearestPlayerName, uuid = nearestPlayerUuid}
                    local assignedAreaId = Area.getAreaIdByPlayerUuid(player.uuid)
                    if assignedAreaId ~= nil then
                        -- player has an area.
                        print(player.name .. " already has an area assigned (ID: " .. assignedAreaId .. ").")
                        -- Teleport the player to the area:
                        teleportToArea(player)
                    else
                        -- player does not have an area.
                        print(player.name .. " is missing an area, assigning one...")
                        -- assign a new area:
                        local areaId = Area.getFirstUnassignedAreaId()
                        if areaId ~= false then
                            print("Assigning area " .. areaId .. " to player " .. player.name)
                            if Area.load(areaId) == true then
                                if Area.assign(player.uuid) == true then
                                    if Area.save() == true then
                                        print(player.name .. " has been assigned to area " .. Area.id)
                                        cmd.message(player.name, "You have been assigned an Area. Cloning templates...")
                                        local cloneSuccess = cloneTemplateToArea()
                                        if cloneSuccess == true then
                                            cmd.message(player.name, "Your area is ready! Teleporting you there now...")
                                            -- Teleport the player to the area:
                                            teleportToArea(player)
                                        end
                                        Area.unload()
                                    else
                                        print("Failed to save the area data.")
                                    end
                                else
                                    print(player.name .. " could not be assigned to an area.")
                                end
                            else
                                print("Failed to load area " .. areaId .. " for assignment.")
                            end
                        else
                            print("Failed to load an unassigned area, are we maxxed?")
                        end
                    end
                    -- make sure to unload the area.
                    Area.unload()
                else
                    print("Failed to get UUID for nearest player: " .. nearestPlayerName)
                end
            else
                print("No players found nearby.")
            end
            -- Debounce - wait before checking again
            sleep(0.5)
        end
        -- Main loop tick
        sleep(0.1)
    end
end

local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("VaultGuard Main Server Script " .. version)
    -- do some checks:
    if not http then
        print("Error: HTTP API is not enabled.")
        print("  -> Updates will not work")
        print("  -> Please enable it in the settings.")
        -- do not break, just warn
        for i = 1, 5 do
            print(".")
            sleep(1)
        end
    else
        print(" -> HTTP API")
        print(" -> Checking for updates...")
        local updateResult = updateSelf()
        if updateResult == 0 then
            print(" -> UPDATE SUCCESSFUL")
            print(" -> REBOOTING")
            sleep(2)
            os.reboot()  -- Reboot to apply the update
        elseif updateResult == 1 then
            print(" -> UP TO DATE")
        elseif updateResult == -1 then
            print(" -> UPDATE FAILED")
            sleep(2)
        end
    end
    return true
end

local function main()
    if not init() then
        print("Initialization failed. Exiting...")
        return
    end

    mainLoop()
end

-- Verify this is a command computer
if not commands then
    print("ERROR: This is not a command computer!")
    print("Please place this program on a command computer.")
    return
end
-- Run the main function
main()