-- VaultGuard Terminal Server Script

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("box_drawing")
updater.updateLib("menu")
-- require the libraries
local bd = require("libs.box_drawing")
local menu = require("libs.menu")

local version = "0.0.1"

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/term/main.lua"
    local versionUrl = "/components/term/version"
    -- update this script
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("VaultGuard Terminal Server Script " .. version)
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
end

-- Run the main function
main()