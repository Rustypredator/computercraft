-- VaultGuard Main Server Script

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("cmd")
updater.updateLib("area")
updater.updateLib("netprotocol")
-- require the libraries
local cmd = require("libs.cmd")
local Area = require("libs.area")
local netprotocol = require("libs.netprotocol")

local version = "0.1.5"

-- VaultGuard-specific network protocol config
local Actions = {
    PING                   = "ping",
    GET_AREA_BY_PLAYER     = "getAreaByPlayer",
    GET_AREA_INFO          = "getAreaInfo",
    GET_CONFIG             = "getConfig",
    CHECK_BALANCE          = "checkBalance",
    ADD_TEMPLATE           = "addTemplate",
    CLONE_TEMPLATE_TO_AREA = "cloneTemplateToArea",
}

local net = netprotocol.create({
    protocol = "vaultguard",
    hostname = "vaultguard-server",
    timeout  = 5,
})

local config = {
    checkInterval = 100,
    redstoneInputSide = "top",
}

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/vaultguard/main/main.lua"
    local versionUrl = "/components/vaultguard/main/version"
    -- update this script
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

local function cloneTemplateToArea()
    -- Clone the top template into the topmost slice
    local topSlice = Area.getSliceFromTop(1)
    local topSuccess = Area.cloneTemplateToSlice(topSlice, "top")
    if not topSuccess then
        return false
    end

    -- Clone the bottom template into the second slice from the top
    local bottomSlice = Area.getSliceFromTop(2)
    local bottomSuccess = Area.cloneTemplateToSlice(bottomSlice, "bottom")
    if not bottomSuccess then
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
            if cmd.tpPos(player.name, Area._state.spawn) then
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

------------------------------------------------------------------------
-- Network request handler
------------------------------------------------------------------------

local function handleNetworkRequest(senderId, request)
    local action = request.action
    local data = request.data or {}

    if action == Actions.PING then
        net.sendResponse(senderId, net.buildResponse(action, {online = true}))

    elseif action == Actions.GET_AREA_BY_PLAYER then
        local areaId = Area.getAreaIdByPlayerUuid(data.uuid)
        net.sendResponse(senderId, net.buildResponse(action, {areaId = areaId}))

    elseif action == Actions.GET_AREA_INFO then
        if Area.load(data.areaId) then
            local info = {
                id         = Area._state.id,
                playerUuid = Area._state.playerUuid,
                slices     = Area._state.slices,
                min        = Area._state.min,
                max        = Area._state.max,
                spawn      = Area._state.spawn,
            }
            Area.unload()
            net.sendResponse(senderId, net.buildResponse(action, info))
        else
            net.sendResponse(senderId, net.buildError(action, "Failed to load area " .. tostring(data.areaId)))
        end

    elseif action == Actions.GET_CONFIG then
        local cfg = Area.getConfig()
        net.sendResponse(senderId, net.buildResponse(action, {
            templates          = cfg.templates,
            availableTemplates = cfg.availableTemplates,
            currencyItem       = cfg.currencyItem,
        }))

    elseif action == Actions.CHECK_BALANCE then
        local count = cmd.countItem(data.playerName, Area.getConfig().currencyItem)
        net.sendResponse(senderId, net.buildResponse(action, {balance = count}))

    elseif action == Actions.ADD_TEMPLATE then
        -- Validate template exists and get cost
        local cfg = Area.getConfig()
        local template = cfg.templates[data.templateKey]
        if not template then
            net.sendResponse(senderId, net.buildError(action, "Unknown template."))
            return
        end

        local cost = template.cost or 0

        -- Check if player can afford it
        if cost > 0 and data.playerName then
            local balance = cmd.countItem(data.playerName, cfg.currencyItem)
            if balance < cost then
                net.sendResponse(senderId, net.buildError(action,
                    "Not enough items. Need " .. cost .. ", have " .. balance .. "."))
                return
            end
        end

        if Area.load(data.areaId) then
            if #Area._state.slices < 3 then
                Area.unload()
                net.sendResponse(senderId, net.buildError(action, "Not enough vertical space to add more templates."))
                return
            end
            local fromTop = data.fromTopIndex or 2
            local success = Area.shiftDownAndInsert(fromTop, data.templateKey)
            if success then
                Area.save()
            end
            Area.unload()
            if success then
                -- Charge the player
                if cost > 0 and data.playerName then
                    cmd.clearItem(data.playerName, cfg.currencyItem, cost)
                end
                net.sendResponse(senderId, net.buildResponse(action, {success = true}))
            else
                net.sendResponse(senderId, net.buildError(action, "Failed to add template."))
            end
        else
            net.sendResponse(senderId, net.buildError(action, "Failed to load area " .. tostring(data.areaId)))
        end

    elseif action == Actions.CLONE_TEMPLATE_TO_AREA then
        if Area.load(data.areaId) then
            local success = cloneTemplateToArea()
            if success then Area.save() end
            Area.unload()
            if success then
                net.sendResponse(senderId, net.buildResponse(action, {success = true}))
            else
                net.sendResponse(senderId, net.buildError(action, "Clone failed."))
            end
        else
            net.sendResponse(senderId, net.buildError(action, "Failed to load area " .. tostring(data.areaId)))
        end

    else
        net.sendResponse(senderId, net.buildError(action, "Unknown action: " .. tostring(action)))
    end
end

------------------------------------------------------------------------
-- Network listener loop
------------------------------------------------------------------------

local function networkLoop()
    print("[NET] Network listener started.")
    while true do
        local senderId, request = net.receiveRequest()
        if senderId and request then
            print("[NET] Request from #" .. senderId .. ": " .. tostring(request.action))
            handleNetworkRequest(senderId, request)
        end
    end
end

------------------------------------------------------------------------
-- Redstone detection loop
------------------------------------------------------------------------

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
                                        print(player.name .. " has been assigned to area " .. Area._state.id)
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
            -- Debounce - wait for signal to go LOW before accepting again
            while redstone.getInput(config.redstoneInputSide) do
                sleep(0.1)
            end
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

    -- Open modem for Rednet
    local modemSide = netprotocol.openModem()
    if not modemSide then
        print("WARNING: No modem found!")
        print("  -> Terminal access will not work.")
        print("  -> Attach a modem and reboot.")
    else
        net.host()
        print(" -> Rednet hosted on: " .. modemSide)
        print(" -> Protocol: " .. net.protocol)
    end

    return true
end

local function main()
    if not init() then
        print("Initialization failed. Exiting...")
        return
    end

    -- Run the redstone detection loop and network listener in parallel
    parallel.waitForAll(mainLoop, networkLoop)
end

-- Verify this is a command computer
if not commands then
    print("ERROR: This is not a command computer!")
    print("Please place this program on a command computer.")
    return
end
-- Run the main function
main()