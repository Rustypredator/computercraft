-- Shooting Range Main Script

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("menu")
updater.updateLib("ui")
updater.updateLib("cmd")
-- require the libraries
local menu = require("libs.menu")
local cmd = require("libs.cmd")

local version = "0.0.5"

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

    local mon = peripheral.find("monitor")

    while true do
        -- Teleport Selection menu:
        local option = menu.monitorSelect(mon, {
                "- Range 1 [FREE]",
                "- Range 2 [FREE]",
                "- Range 3 [FREE]",
                "- Range 4 [FREE]",
                "- Range 5 [FREE]",
                "- Range 6 [FREE]"
            }, "Select an option", "Shooting Range", "v" .. version)
        -- Teleport the player to the selected position
        if option == 1 then
            cmd.tpPos("@p", "1381", "64", "-318")
        elseif option == 2 then
            cmd.tpPos("@p", "1381", "64", "-256")
        elseif option == 3 then
            cmd.tpPos("@p", "1381", "64", "-193")
        elseif option == 4 then
            cmd.tpPos("@p", "1381", "64", "-130")
        elseif option == 5 then
            cmd.tpPos("@p", "1381", "64", "-67")
        elseif option == 6 then
            cmd.tpPos("@p", "1381", "64", "-4")
        end
    end
end

-- Run the main function
main()