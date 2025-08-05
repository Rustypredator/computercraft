-- Shooting Range Main Script

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("box_drawing")
updater.updateLib("menu")
-- require the libraries
local bd = require("libs.box_drawing")
local menu = require("libs.menu")

local version = "0.0.2"

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/shootingrange/main/main.lua"
    local versionUrl = "/components/shootingrange/main/main.ver"
    -- update this script
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("Shooting Range Main Script " .. version)
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

    local CHANNEL = 9832

    --- Main
    term.clear()
    while true do
        -- open modem on target channel and listen for messages
        print("Opening modem on channel " .. CHANNEL)
        local modem = peripheral.find("modem")
        if modem then
            modem.open(CHANNEL)
            print("Modem opened successfully.")
        else
            print("Error: No modem found.")
            return
        end
        print("Listening for messages on channel " .. CHANNEL)
        local event, channel, message = os.pullEvent("modem_message")
        if channel == CHANNEL then
            print("Received message on channel " .. channel)
            if type(message) == "table" and message.type == "target" then
                print("Target message received: " .. message.data)
                -- Here you can handle the target message, e.g., update the target position
                -- For now, just print it
                print("Target data: " .. textutils.serialize(message.data))
            else
                print("Unknown message type or format.")
            end
        end
    end
end

-- Run the main function
main()