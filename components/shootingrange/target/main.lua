-- Shooting Range Target Script

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- updater
local updater = require("libs.updater")
updater.updateSelf()

local version = "0.0.7"

-- Self Update function
local function updateSelf()
    local updateUrl = "/components/shootingrange/target/main.lua"
    local versionUrl = "/components/shootingrange/target/main.ver"
    -- update this script
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("Shooting Range Target Script " .. version)
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
    local pos = nil
    
    -- Try to get GPS position
    print("Getting GPS coordinates...")
    local x, y, z = gps.locate(5) -- 5 second timeout
    
    if x then
        pos = {x = x, y = y, z = z}
        print(string.format("Position: %.1f, %.1f, %.1f", x, y, z))
    else
        print("GPS location failed. No GPS network or out of range.")
        print("Using dummy coordinates.")
        pos = {x = 0, y = 0, z = 0}
    end

    -- Find and open the first available modem
    local modem = peripheral.find("modem")
    if not modem then
        print("No modem found!")
        return
    end
    if not modem.isOpen(CHANNEL) then
        modem.open(CHANNEL)
    end
    while true do
        -- Wait for redstone signal ON (rising edge)
        while not redstone.getInput("top") do
            sleep(0.05)
        end
        -- Send one message when signal is detected

        local strength = redstone.getAnalogInput("top") -- Get the strength of the redstone signal
        if (strength < 1) {
            strength = 1 -- default score of 1
        }
        local message = {
            strength = strength, -- Get the strength of the redstone signal
            position = pos,
            time = os.time()
        }
        modem.transmit(CHANNEL, CHANNEL, message)
        print("Hit with Score of " .. strength .. " recorded.")
        -- Wait for redstone signal OFF (falling edge)
        while redstone.getInput("top") do
            sleep(0.05)
        end
        print("Redstone signal reset. Ready for next trigger.")
    end
end

-- Run the main function
main()