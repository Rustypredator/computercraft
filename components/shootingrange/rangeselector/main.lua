-- Shooting Range Main Script

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("menu")
updater.updateLib("cmd")
-- require the libraries
local menu = require("libs.menu")
local cmd = require("libs.cmd")

local version = "0.0.1"

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/shootingrange/rangeselector/main.lua"
    local versionUrl = "/components/shootingrange/rangeselector/main.ver"
    -- update this script
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("Shooting Range Rangeselector Script " .. version)
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

    while true do
        -- Clear the screen
        term.clear()
        term.setCursorPos(1, 1)
        -- Teleport Selection menu:
        local option = menu.monitorSelect(mon, {
                "1 - FFA",
                "2 - Pistols (WIP)",
                "3 - SMGs (WIP)",
                "4 - Shotguns (WIP)",
                "5 - Snipers (WIP)",
                "6 - Rifles (WIP)",
                "7 - Snipers (WIP)"
            }, "Select an option", "Shooting Range", "v" .. version)
        -- Teleport the player to the selected position
        if option == 1 then
            cmd.tpPos("@p", "1381", "64", "-318")
        elseif option == 2 then
            cmd.tpPos("@p", "1381", "64", "-318")
        elseif option == 3 then
            cmd.tpPos("@p", "1381", "64", "-318")
        elseif option == 4 then
            cmd.tpPos("@p", "1381", "64", "-318")
        elseif option == 5 then
            cmd.tpPos("@p", "1381", "64", "-318")
        elseif option == 6 then
            cmd.tpPos("@p", "1381", "64", "-318")
        elseif option == 7 then
            cmd.tpPos("@p", "1381", "64", "-318")
        end
    end
end

-- Run the main function
main()