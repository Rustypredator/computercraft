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

local version = "0.0.3"

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

local function listeningLoop()
    local timeout = os.startTimer(10) -- record all hits for 10 seconds^
    local modem = peripheral.find("modem")
    local hits = {}
    if modem then
        modem.open(9832) -- Open the modem on channel 9832
        print("Modem opened on channel 9832. Listening for messages...")
    else
        print("Error: No modem found.")
        return
    end
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        if event == "modem_message" and param1 == 9832 then
            print("Received message: " .. textutils.serialize(param3))
            if type(param3) == "table" and param3.type == "hit" then
                table.insert(hits, param3.data)
                print("Hit recorded: " .. textutils.serialize(param3.data))
            else
                print("Unknown message type or format.")
            end
        elseif event == "timer" and param1 == timeout then
            print("Timeout reached. Stopping listening loop.")
            return hits
            break
        end
    end
end

local function main()
    if not init() then
        print("Initialization failed. Exiting...")
        return
    end

    local CHANNEL = 9832

    --- Main
    term.clear()
    local option = menu.termSelect({
        "Start Round",
    }, "Select an option", "Shooting Range", "v" .. version)
    if option == "Start Round" then
        print("Recording all hits for 10 seconds...")
        hits = listeningLoop()
        if #hits > 0 then
            print("Hits recorded: " .. #hits)
            for i, hit in ipairs(hits) do
                print("Hit " .. i .. ": " .. textutils.serialize(hit))
            end
        else
            print("No hits recorded.")
        end
    else
        print("You selected an invalid option.")
    end
end

-- Run the main function
main()