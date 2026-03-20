-- CHANGEME

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("cmd")

-- require the libraries
local cmd = require("libs.cmd")

local version = "0.0.1"

--- Self Update function
local function updateSelf()
    local updateUrl = "/components/templates/main/main.lua"
    local versionUrl = "/components/templates/main/main.ver"
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

--- Initialize the script
local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("TEMPLATE v" .. version)
    print("")
    
    print("Checking for updates...")
    local updateResult = updateSelf()
    if updateResult == 0 then
        print("UPDATE SUCCESSFUL - REBOOTING")
        sleep(2)
        os.reboot()
    elseif updateResult == 1 then
        print("UP TO DATE")
    elseif updateResult == -1 then
        print("UPDATE FAILED")
        sleep(2)
    end
    
    return true
end

--- Main function
local function main()
    if not init() then
        print("Initialization failed. Exiting.")
        return
    end
    
    print("Initialization complete. Starting Template...")
    
    -- do stuff here
    
    print("\nPress ENTER to exit.")
    io.read()
end

-- Run the main function
main()