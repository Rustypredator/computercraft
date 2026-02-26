-- VaultGuard Terminal Control Center
-- Provides a monitor-based interface for players to manage their area.

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("ui")
updater.updateLib("menu")
updater.updateLib("cmd")
updater.updateLib("area")
-- require the libraries
local ui = require("libs.ui")
local menu = require("libs.menu")
local cmd = require("libs.cmd")
local Area = require("libs.area")

local version = "0.0.2"

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/vaultguard/term/term.lua"
    local versionUrl = "/components/vaultguard/term/version"
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

------------------------------------------------------------------------
-- Monitor detection
------------------------------------------------------------------------
local monitor = nil

local function findMonitor()
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "monitor" then
            return peripheral.wrap(side)
        end
    end
    local monitors = {peripheral.find("monitor")}
    if #monitors > 0 then
        return monitors[1]
    end
    return nil
end

------------------------------------------------------------------------
-- Player identification
------------------------------------------------------------------------
local function identifyPlayer()
    local name = cmd.getNearestPlayerName("Welcome to VaultGuard Terminal")
    if not name or name == "unknown" then
        return nil
    end
    local uuid = cmd.getPlayerUUID(name)
    if not uuid then
        return nil
    end
    return {name = name, uuid = uuid}
end

------------------------------------------------------------------------
-- Screen: Area Info
------------------------------------------------------------------------
local function showAreaInfo(mon, player)
    local areaId = Area.getAreaIdByPlayerUuid(player.uuid)
    if not areaId then
        menu.monitorStatus(mon, "You have no area assigned.\nPlease use the main terminal\nto get an area first.", "No Area")
        return
    end

    if not Area.load(areaId) then
        menu.monitorStatus(mon, "Failed to load area data.", "Error")
        return
    end

    local width, height = mon.getSize()
    mon.clear()
    ui.drawMonitorOuterBox(mon, "", "Area Info", "", "", "", "v" .. version)

    local y = 3
    ui.drawMonitorText(mon, 3, y, "Player: " .. player.name, colors.yellow)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Area ID: " .. Area._state.id)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Slices: " .. #Area._state.slices)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Min: " .. Area._state.min.x .. ", " .. Area._state.min.y .. ", " .. Area._state.min.z)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Max: " .. Area._state.max.x .. ", " .. Area._state.max.y .. ", " .. Area._state.max.z)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Spawn: " .. Area._state.spawn.x .. ", " .. Area._state.spawn.y .. ", " .. Area._state.spawn.z)

    -- Back button
    y = height - 1
    ui.drawMonitorButton(mon, 3, y, width - 4, 1, colors.gray, colors.white, "< Back")

    Area.unload()

    while true do
        local event, side, x, touchY = os.pullEvent("monitor_touch")
        if touchY == y then
            return
        end
    end
end

------------------------------------------------------------------------
-- Screen: Add Template
------------------------------------------------------------------------
local function showAddTemplate(mon, player)
    local areaId = Area.getAreaIdByPlayerUuid(player.uuid)
    if not areaId then
        menu.monitorStatus(mon, "You have no area assigned.\nPlease use the main terminal\nto get an area first.", "No Area")
        return
    end

    if not Area.load(areaId) then
        menu.monitorStatus(mon, "Failed to load area data.", "Error")
        return
    end

    -- Need at least 3 slices (top cap + new template + at least 1 below to shift into)
    if #Area._state.slices < 3 then
        menu.monitorStatus(mon, "Not enough vertical space\nto add more templates.", "No Room")
        Area.unload()
        return
    end

    Area.unload()

    -- Build options list from available templates
    local areaConfig = Area.getConfig()
    local optionNames = {}
    local optionKeys = {}
    for _, key in ipairs(areaConfig.availableTemplates) do
        local tmpl = areaConfig.templates[key]
        if tmpl then
            table.insert(optionNames, tmpl.label or key)
            table.insert(optionKeys, key)
        end
    end
    table.insert(optionNames, "< Back")

    local choice = menu.monitorSelect(mon, optionNames, "Select a template", "Add Template", "v" .. version)

    if choice == #optionNames then
        return
    end

    local selectedKey = optionKeys[choice]
    local selectedLabel = optionNames[choice]

    local confirmed = menu.monitorConfirm(mon, "Add '" .. selectedLabel .. "'?", "Confirm")
    if not confirmed then
        return
    end

    if not Area.load(areaId) then
        menu.monitorStatus(mon, "Failed to load area data.", "Error")
        return
    end

    menu.monitorStatus(mon, "Shifting sections down\nand cloning template...\nPlease wait.", "Working...", 1)

    -- Insert at slot 2 from top (right below the top cap)
    local success = Area.shiftDownAndInsert(2, selectedKey)

    if success then
        Area.save()
        Area.unload()
        menu.monitorStatus(mon, "Template '" .. selectedLabel .. "'\nhas been added to your area!", "Success")
    else
        Area.unload()
        menu.monitorStatus(mon, "Failed to add template.\nCheck the server console.", "Error")
    end
end

------------------------------------------------------------------------
-- Main Menu
------------------------------------------------------------------------
local function showMainMenu(mon, player)
    while true do
        local choice = menu.monitorSelect(mon, {
            "Area Info",
            "Add Template",
            "Exit"
        }, "Welcome, " .. player.name, "VaultGuard", "v" .. version)

        if choice == 1 then
            showAreaInfo(mon, player)
        elseif choice == 2 then
            showAddTemplate(mon, player)
        elseif choice == 3 then
            return
        end
    end
end

------------------------------------------------------------------------
-- Initialization & Main Loop
------------------------------------------------------------------------
local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("VaultGuard Terminal v" .. version)

    if not http then
        print("Warning: HTTP API not enabled.")
        print("  -> Updates will not work.")
        for i = 1, 3 do
            print(".")
            sleep(1)
        end
    else
        print(" -> Checking for updates...")
        local updateResult = updateSelf()
        if updateResult == 0 then
            print(" -> UPDATE SUCCESSFUL - REBOOTING")
            sleep(2)
            os.reboot()
        elseif updateResult == 1 then
            print(" -> Up to date.")
        elseif updateResult == -1 then
            print(" -> Update failed.")
            sleep(2)
        end
    end

    -- Find monitor
    monitor = findMonitor()
    if not monitor then
        print("ERROR: No monitor found!")
        print("Please attach a monitor to this computer.")
        return false
    end
    print(" -> Monitor found.")
    monitor.setTextScale(0.5)

    -- Verify command computer
    if not commands then
        print("ERROR: This is not a command computer!")
        return false
    end
    print(" -> Command computer OK.")

    return true
end

local function mainLoop()
    while true do
        -- Idle screen
        monitor.clear()
        ui.drawMonitorOuterBox(monitor, "", "VaultGuard", "", "", "", "v" .. version)
        local _, monHeight = monitor.getSize()
        ui.drawMonitorCenteredText(monitor, math.floor(monHeight / 2), "Tap to begin", colors.lightGray)

        -- Wait for touch to start session
        os.pullEvent("monitor_touch")

        -- Identify nearest player
        local player = identifyPlayer()
        if player then
            print("Session started for: " .. player.name)
            showMainMenu(monitor, player)
            print("Session ended for: " .. player.name)
        else
            menu.monitorStatus(monitor, "Could not identify player.\nPlease stand closer and\ntry again.", "Error", 3)
        end

        sleep(1)
    end
end

local function main()
    if not init() then
        print("Initialization failed. Exiting...")
        return
    end
    mainLoop()
end

main()