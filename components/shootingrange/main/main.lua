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

local version = "0.1.3"

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
    local timeout = os.startTimer(10) -- record all hits for 10 seconds
    local modem = peripheral.find("modem")
    local hits = {}
    if modem then
        modem.open(9832) -- Open the modem on channel 9832
        print("Modem opened on channel 9832. Listening for messages...")
    else
        print("Error: No modem found.")
        return {}
    end
    while true do
        local event, param1, param2, param3, param4 = os.pullEvent()
        if event == "modem_message" and param2 == 9832 then
            local side = param1
            local channel = param2
            local returnChannel = param3
            local message = param4
            print("Received Hit.")
            if type(message) == "table" and message.strength > 0 then
                table.insert(hits, message)
            else
                print("Unknown message type or format.")
            end
        elseif event == "timer" and param1 == timeout then
            print("Timeout reached. Stopping listening loop.")
            return hits
        end
    end
end

local function writeCentered(mon, y, text, width)
    local x = math.floor((width - #text) / 2) + 1
    mon.setCursorPos(x, y)
    mon.write(text)
end

local function main()
    if not init() then
        print("Initialization failed. Exiting...")
        return
    end

    local CHANNEL = 9832

    -- Try to find a monitor
    local mon = peripheral.find("monitor")
    local monW, monH = 0, 0
    if mon then
        monW, monH = mon.getSize()
    else
        print("No Monitor!")
        return
    end
    
    --- Main
    while true do
        term.clear()
        local option = menu.monitorSelect({
            "Start Round",
        }, "Select an option", "Shooting Range", "v" .. version)
        if option == 1 then
            print("Recording all hits for 10 seconds...")
            if mon then
                bd.monitorOuterRim("Shooting Range", "v" .. version, mon)
                writeCentered(mon, math.floor(monH/2), "Waiting for hits...", monW)
            end
            local hits = listeningLoop()
            if mon then
                bd.monitorOuterRim("Shooting Range", "v" .. version, mon)
                if #hits > 0 then
                    writeCentered(mon, math.floor(monH/2), "Hits recorded: " .. #hits, monW)
                    sleep(2)
                    mon.clear()
                    bd.monitorOuterRim("Shooting Range", "v" .. version, mon)
                    mon.setCursorPos(3, 2)
                    mon.write("Hits:")
                    local score = 0
                    for i, hit in ipairs(hits) do
                        local y = 3 + i
                        if y > monH - 1 then break end
                        mon.setCursorPos(3, y)
                        mon.write(i .. ": " .. hit.strength)
                        score = score + hit.strength
                    end
                    sleep(2)
                    mon.clear()
                    bd.monitorOuterRim("Shooting Range", "v" .. version, mon)
                    writeCentered(mon, math.floor(monH/2), "Total Score: " .. score, monW)
                    sleep(2)
                    mon.clear()
                    bd.monitorOuterRim("Shooting Range", "v" .. version, mon)
                else
                    writeCentered(mon, math.floor(monH/2), "No hits recorded.", monW)
                end
            end
            sleep(3)
        else
            print("You selected an invalid option.")
        end
    end
end

-- Run the main function
main()