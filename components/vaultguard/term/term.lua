-- VaultGuard Terminal Control Center
-- Thin client that communicates with the main server via Rednet.
-- The main server MUST be running for this terminal to function.

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("ui")
updater.updateLib("menu")
updater.updateLib("cmd")
updater.updateLib("netprotocol")
-- require the libraries
local ui = require("libs.ui")
local menu = require("libs.menu")
local cmd = require("libs.cmd")
local netprotocol = require("libs.netprotocol")

local version = "0.0.3"

-- VaultGuard-specific network protocol config
local Actions = {
    PING                   = "ping",
    GET_AREA_BY_PLAYER     = "getAreaByPlayer",
    GET_AREA_INFO          = "getAreaInfo",
    GET_CONFIG             = "getConfig",
    ADD_TEMPLATE           = "addTemplate",
    CLONE_TEMPLATE_TO_AREA = "cloneTemplateToArea",
}

local net = netprotocol.create({
    protocol = "vaultguard",
    hostname = "vaultguard-server",
    timeout  = 5,
})

local serverId = nil
local monitor = nil

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/vaultguard/term/term.lua"
    local versionUrl = "/components/vaultguard/term/version"
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

------------------------------------------------------------------------
-- Monitor detection
------------------------------------------------------------------------

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
-- Server connection
------------------------------------------------------------------------

local function connectToServer()
    serverId = net.findServer()
    if not serverId then
        return false
    end
    -- Ping to verify
    local response = net.sendRequest(serverId, Actions.PING, {})
    if response and response.success then
        return true
    end
    serverId = nil
    return false
end

--- Send a request, auto-reconnecting once on failure.
local function serverRequest(action, data)
    if not serverId then
        if not connectToServer() then
            return nil
        end
    end
    local response = net.sendRequest(serverId, action, data)
    if not response then
        -- Retry once after reconnecting
        if connectToServer() then
            response = net.sendRequest(serverId, action, data)
        end
    end
    return response
end

------------------------------------------------------------------------
-- Player identification (local command computer operation)
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
    -- Ask server for area ID
    local resp = serverRequest(Actions.GET_AREA_BY_PLAYER, {uuid = player.uuid})
    if not resp or not resp.success then
        menu.monitorStatus(mon, "Server unreachable.\nIs the main server running?", "Connection Error")
        return
    end

    local areaId = resp.data.areaId
    if not areaId then
        menu.monitorStatus(mon, "You have no area assigned.\nPlease use the main terminal\nto get an area first.", "No Area")
        return
    end

    -- Ask server for area details
    local infoResp = serverRequest(Actions.GET_AREA_INFO, {areaId = areaId})
    if not infoResp or not infoResp.success then
        menu.monitorStatus(mon, "Failed to load area data.\n" .. (infoResp and infoResp.error or "Server unreachable."), "Error")
        return
    end

    local info = infoResp.data
    local width, height = mon.getSize()
    mon.clear()
    ui.drawMonitorOuterBox(mon, "", "Area Info", "", "", "", "v" .. version)

    local y = 3
    ui.drawMonitorText(mon, 3, y, "Player: " .. player.name, colors.yellow)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Area ID: " .. info.id)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Slices: " .. #info.slices)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Min: " .. info.min.x .. ", " .. info.min.y .. ", " .. info.min.z)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Max: " .. info.max.x .. ", " .. info.max.y .. ", " .. info.max.z)
    y = y + 1
    ui.drawMonitorText(mon, 3, y, "Spawn: " .. info.spawn.x .. ", " .. info.spawn.y .. ", " .. info.spawn.z)

    -- Back button
    y = height - 1
    ui.drawMonitorButton(mon, 3, y, width - 4, 1, colors.gray, colors.white, "< Back")

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
    -- Get area ID from server
    local resp = serverRequest(Actions.GET_AREA_BY_PLAYER, {uuid = player.uuid})
    if not resp or not resp.success then
        menu.monitorStatus(mon, "Server unreachable.", "Connection Error")
        return
    end

    local areaId = resp.data.areaId
    if not areaId then
        menu.monitorStatus(mon, "You have no area assigned.\nPlease use the main terminal\nto get an area first.", "No Area")
        return
    end

    -- Get area info to check slice count
    local infoResp = serverRequest(Actions.GET_AREA_INFO, {areaId = areaId})
    if not infoResp or not infoResp.success then
        menu.monitorStatus(mon, "Failed to load area data.", "Error")
        return
    end

    if #infoResp.data.slices < 3 then
        menu.monitorStatus(mon, "Not enough vertical space\nto add more templates.", "No Room")
        return
    end

    -- Get available templates from server
    local cfgResp = serverRequest(Actions.GET_CONFIG, {})
    if not cfgResp or not cfgResp.success then
        menu.monitorStatus(mon, "Failed to get server config.", "Error")
        return
    end

    local templates = cfgResp.data.templates
    local available = cfgResp.data.availableTemplates

    -- Build options list
    local optionNames = {}
    local optionKeys  = {}
    for _, key in ipairs(available) do
        local tmpl = templates[key]
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

    local selectedKey   = optionKeys[choice]
    local selectedLabel = optionNames[choice]

    local confirmed = menu.monitorConfirm(mon, "Add '" .. selectedLabel .. "'?", "Confirm")
    if not confirmed then
        return
    end

    menu.monitorStatus(mon, "Shifting sections down\nand cloning template...\nPlease wait.", "Working...", 1)

    -- Tell the server to do the actual clone work
    local addResp = serverRequest(Actions.ADD_TEMPLATE, {
        areaId       = areaId,
        templateKey  = selectedKey,
        fromTopIndex = 2,
    })

    if addResp and addResp.success then
        menu.monitorStatus(mon, "Template '" .. selectedLabel .. "'\nhas been added to your area!", "Success")
    else
        local errMsg = (addResp and addResp.error) or "Server unreachable."
        menu.monitorStatus(mon, "Failed to add template.\n" .. errMsg, "Error")
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

    -- Verify command computer (needed for player identification)
    if not commands then
        print("ERROR: This is not a command computer!")
        print("Player identification requires a command computer.")
        return false
    end
    print(" -> Command computer OK.")

    -- Open modem for Rednet
    local modemSide = netprotocol.openModem()
    if not modemSide then
        print("ERROR: No modem found!")
        print("Attach a modem to connect to the server.")
        return false
    end
    print(" -> Modem opened on: " .. modemSide)

    -- Try connecting to the server
    print(" -> Looking for VaultGuard server...")
    if connectToServer() then
        print(" -> Connected to server (ID: " .. serverId .. ")")
    else
        print("WARNING: Server not found!")
        print("  -> The main server must be running.")
        print("  -> Will retry when needed.")
    end

    return true
end

local function mainLoop()
    while true do
        -- Idle screen
        monitor.clear()
        ui.drawMonitorOuterBox(monitor, "", "VaultGuard", "", "", "", "v" .. version)
        local _, monHeight = monitor.getSize()

        -- Show connection status
        if serverId then
            ui.drawMonitorCenteredText(monitor, math.floor(monHeight / 2) - 1, "Connected to server", colors.green)
        else
            ui.drawMonitorCenteredText(monitor, math.floor(monHeight / 2) - 1, "Server offline", colors.red)
        end
        ui.drawMonitorCenteredText(monitor, math.floor(monHeight / 2) + 1, "Tap to begin", colors.lightGray)

        -- Wait for touch to start session
        os.pullEvent("monitor_touch")

        -- Try connecting if not connected
        local canProceed = true
        if not serverId then
            menu.monitorStatus(monitor, "Connecting to server...", "Please wait", 1)
            if not connectToServer() then
                menu.monitorStatus(monitor, "Could not reach the server.\nMake sure the main server\nis running and try again.", "Connection Error", 3)
                canProceed = false
            end
        end

        if canProceed then
            -- Identify nearest player
            local player = identifyPlayer()
            if player then
                print("Session started for: " .. player.name)
                showMainMenu(monitor, player)
                print("Session ended for: " .. player.name)
            else
                menu.monitorStatus(monitor, "Could not identify player.\nPlease stand closer and\ntry again.", "Error", 3)
            end
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