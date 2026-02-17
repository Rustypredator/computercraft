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
    templateCoords = {
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
    }
}

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/main/main.lua"
    local versionUrl = "/components/main/version"
    -- update this script
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

local Area = {
    id = nil,
    playerUuid = nil,
    min = {x = nil, y = nil, z = nil},
    max = {x = nil, y = nil, z = nil},
    spawn = {x = nil, y = nil, z = nil}
}

function Area.loadData(data)
    Area.id = data.id
    Area.playerUuid = data.playerUuid
    Area.min = data.min
    Area.max = data.max
    Area.spawn = data.spawn
end

function Area.load(areaId)
    -- Load all data for the specified area
    file = fs.open("data/areas/" .. areaId .. ".txt", "r")
    if file then
        local content = file.readAll()
        file.close()
        if content ~= "" then
            data = textutils.unserialize(content) or {}
            Area.loadData(data)
            return true
        end
    end
    return false
end

function Area.loadFirstUnassigned()
    -- load the first unassigned area.
    return false
end

function Area.loadByPlayerUuid(playerUuid)
    -- load the first area that is assigned to the playerUuid.
    return false
end

function Area.save()
    -- save all data to a file.
    return false
end

function Area.unload()
    -- Reset area data
    return false
end

function Area.assign(playerUuid)
    -- assign the area to a player.
    return false
end

function Area.unassign()
    -- unassign the area.
    return false
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
        if Area.loadByPlayerUuid(player.uuid) == true then
            -- player has an area.
            print(player.name .. " Already has an area assigned.")
        else
            -- player does not have an area.
            print(player.name .. " is missing an area, assigning one...")
            -- assign a new area:
            if Area.loadFirstUnassigned() == true then
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
    if Area.loadByPlayerUuid(player.uuid) == true then
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