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

local version = "0.0.8"

local config = {
    checkInterval = 100,
    redstoneInputSide = "top",
    templates = {
        {
            name = "top",
            position = {
                min = {x = 0, y = 0, z = 0},
                max = {x = 0, y = 0, z = 0}
            }
        },
        {
            name = "bottom",
            position = {
                min = {x = 0, y = 0, z = 0},
                max = {x = 0, y = 0, z = 0}
            }
        }
        min = {x = 0, y = 0, z = 0},
        max = {x = 0, y = 0, z = 0}
    },
    area = {
        size = 3, -- always squared.
        gap = 1,
        spawnOffset = {x = 0, y = 0, z = 0},
    },
    assignArea = {
        min = {x = 0, y = 0, z = 0},
        max = {x = 0, y = 0, z = 0}
    },
    areaStorageFolder = "data/areas/",
    areaPlayerMapFile = "data/areaPlayerMap.txt"
}

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/main/main.lua"
    local versionUrl = "/components/main/version"
    -- update this script
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

local Area = {
    loaded = false,
    id = nil,
    playerUuid = nil,
    -- dynamic data:
    playermap = nil,
    min = nil,
    max = nil,
    spawn = nil
}

function Area.loadPlayermap()
    -- load the file:
    local file = fs.open(config.areaPlayerMapFile, "r")
    -- get file content
    local content = file.readAll()
    -- deserialize the data
    local data = textutils.unserialize(content) or {}
    -- put data in area property
    Area.playermap = data
    -- loading done.
    return true
end

function Area.savePlayermap()
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
    -- calculate the coordinates of this area by multiplying the id with the coordinates and the size of each area i guess...
    -- this should set the min, max and spawn values for this area dynamically.
end

function Area.loadData(data)
    Area.id = data.id
    Area.playerUuid = data.playerUuid
    Area.calculateCoordinates()
end

function Area.load(areaId)
    -- Load all data for the specified area
    file = fs.open(config.areaStorageFolder .. areaId .. ".txt", "r")
    if file then
        local content = file.readAll()
        file.close()
        if content ~= "" then
            data = textutils.unserialize(content) or {}
            Area.loadData(data)
            Area.loaded = true
            return true
        end
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
    -- else return false:
    return false
end

function Area.save()
    -- assemble data to save:
    local saveData = {
        id = Area.id,
        playerUuid = Area.playerUuid
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
    Area.playermap = nil
    Area.min = nil
    Area.max = nil
    Area.spawn = nil
    return true
end

function Area.assign(playerUuid)
    -- assign the area to a player:
    Area.playerUuid = playerUuid
    return true
end

function Area.unassign()
    -- unassign the area.
    Area.playerUuid = nil
    return true
end

local function cloneTemplateToArea()
    if cmd.clone(config.templateCoords.min, config.templateCoords.max, Area.min) == true then
        print("Template clone successful.")
        return true
    end
    return false
end

local function checkPlayerList()
    local players = cmd.getAllPlayerUUIDs()

    for player in players do
        -- check if player.uuid is already assigned an area. if so, skip them.
        if Area.getAreaIdByPlayerUuid(player.uuid) == true then
            -- player has an area.
            print(player.name .. " Already has an area assigned.")
        else
            -- player does not have an area.
            print(player.name .. " is missing an area, assigning one...")
            -- assign a new area:
            local areaId = Area.getFirstUnassignedAreaId()
            if areaId ~= false then
                Area.load(areaId)
                if Area.assign(player.uuid) == true then
                    if Area.save() == true then
                        print(player.name .. " Has been assigned to area " .. Area.id)
                        cmd.message(player.name, "You have been assigned an Area.")
                        if cloneTemplateToArea() == true then
                            Area.unload()
                        end
                    else
                        print("Failed to save the area Data.")
                    end
                else
                    print(player.name .. " Could not be assigned to an area.")
                end
            else
                print("Failed to load an unassigned area, are we maxxed?")
            end
        end
    end
end

local function teleportToBunker(player)
    -- Load the Bunker for the player:
    if Area.getAreaIdByPlayerUuid(player.uuid) == true then
        if cmd.tpPos(player.name, Area.spawnX, Area.spawnY, Area.spawnZ) == true then
            print("Teleported Player to their area.")
        end
    end
end

local function mainLoop()
    while true do
        Tick_count = Tick_count + 1

        -- Check for new players periodically
        if Tick_count % config.checkInterval == 0 then
            checkPlayerList()
        end

        -- Check for redstone signal
        -- Redstone can come from different sides: "top", "bottom", "front", "back", "left", "right"
        -- You can also check multiple sides
        if redstone.getInput(config.redstoneInputSide) then
            print("[REDSTONE] Signal detected!")
            -- get nearest playerUuid and teleport them to their bunker.
            teleportToBunker(cmd.getNearestPlayerUUID())
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

    --- Main
    term.clear()
    local option = menu.termSelect({
        "Start Server",
        "Settings",
        "Exit"
    }, "Select an option", "VaultGuard Main Menu", "v" .. version)
    print("You selected option: " .. option)

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