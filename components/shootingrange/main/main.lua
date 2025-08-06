-- Shooting Range Main Script

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("menu")
updater.updateLib("txtutil")
updater.updateLib("ui")
-- require the libraries
local menu = require("libs.menu")
local txtutil = require("libs.txtutil")
local ui = require("libs.ui")

local version = "0.1.6"

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

local function saveHits(hits)
    -- save all hits to a file with the current timestamp in json format
    local hitsDir = "hits"
    if not fs.exists(hitsDir) then
        fs.makeDir(hitsDir)
    end
    local fileName = "hits/hits_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
    -- create file if it doesnt exist
    if fs.exists(fileName) then
        print("File already exists: " .. fileName)
        return false
    end
    local file = fs.open(fileName, "w")
    if not file then
        print("Error: Could not open file for writing: " .. fileName)
        return false
    end
    local json = textutils.serializeJSON(hits)
    file.write(json)
    file.close()
    return true
end

local function getSessionslist()
    -- produce a table of all files in the hits directory
    local hitsDir = "hits"
    if not fs.exists(hitsDir) then
        fs.makeDir(hitsDir)
    end
    local files = fs.list(hitsDir)
    return files
end

local function calculateTotalScore(hits)
    local totalScore = 0
    for _, hit in ipairs(hits) do
        totalScore = totalScore + hit.strength
    end
    return totalScore
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
            "List Previous Sessions",
        }, "Select an option", "Shooting Range", "v" .. version)
        if option == 1 then
            print("Recording all hits for 10 seconds...")
            if mon then
                ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                txtutil.writeCentered(mon, math.floor(monH/2), "Waiting for hits...", monW)
            end
            local hits = listeningLoop()
            saveHits(hits)
            if mon then
                ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                if #hits > 0 then
                    txtutil.writeCentered(mon, math.floor(monH/2), "Hits recorded: " .. #hits, monW)
                    sleep(2)
                    mon.clear()
                    ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                    mon.setCursorPos(3, 2)
                    mon.write("Hits:")
                    local score = 0
                    for i, hit in ipairs(hits) do
                        local y = 3 + i
                        if y > monH - 1 then break end
                        mon.setCursorPos(3, y)
                        mon.write(i .. ": " .. hit.strength)
                    end
                    sleep(2)
                    mon.clear()
                    ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                    txtutil.writeCentered(mon, math.floor(monH/2), "Total Score: " .. calculateTotalScore(hits), monW)
                    sleep(2)
                    mon.clear()
                    ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                else
                    txtutil.writeCentered(mon, math.floor(monH/2), "No hits recorded.", monW)
                end
            end
            sleep(3)
        elseif option == 2 then
            -- get a session list
            local sessions = getSessionslist()
            if #sessions == 0 then
                mon.clear()
                ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                txtutil.writeCentered(mon, math.floor(monH/2), "No sessions found.", monW)
                sleep(2)
            else
                while true do
                    mon.clear()
                    ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                    txtutil.writeCentered(mon, 2, "Previous Sessions:", monW)
                    -- Draw exit button at (2,5)
                    ui.drawMonitorButton(mon, 2, 5, 7, 1, colors.red, colors.white, "[ Exit ]")
                    -- Draw session list below button
                    for i, session in ipairs(sessions) do
                        local y = 6 + i
                        if y > monH - 1 then break end
                        mon.setCursorPos(3, y)
                        mon.write(session)
                    end
                    -- Wait for touch event
                    local event, side, x, y = os.pullEvent("monitor_touch")
                    if x >= 2 and x <= 8 and y == 5 then
                        break -- Exit button pressed
                    end
                    -- Check if a session was selected (simulate menu.monitorSelect)
                    for i, session in ipairs(sessions) do
                        local sy = 6 + i
                        if x >= 3 and x <= (3 + #session - 1) and y == sy then
                            -- Session selected, show session view
                            mon.clear()
                            ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                            txtutil.writeCentered(mon, 2, "Session: " .. session, monW)
                            local fileName = "hits/" .. session
                            if fs.exists(fileName) then
                                local hits = textutils.unserializeJSON(fs.read(fileName))
                                if hits then
                                    while true do
                                        mon.clear()
                                        ui.drawMonitorOuterBox("Shooting Range", "v" .. version, mon)
                                        txtutil.writeCentered(mon, 2, "Hits for session: " .. session, monW)
                                        txtutil.writeCentered(mon, 3, "Total Hits: " .. #hits .. " | Total Score: " .. calculateTotalScore(hits), monW)
                                        -- Draw exit button at (2,5)
                                        ui.drawMonitorButton(mon, 2, 5, 7, 1, colors.red, colors.white, "[ Exit ]")
                                        -- Draw hits below button
                                        for j, hit in ipairs(hits) do
                                            local hy = 6 + j
                                            if hy > monH - 1 then break end
                                            mon.setCursorPos(3, hy)
                                            mon.write(hit)
                                        end
                                        -- Wait for touch event
                                        local e, s, tx, ty = os.pullEvent("monitor_touch")
                                        if tx >= 2 and tx <= 8 and ty == 5 then
                                            break -- Exit button pressed
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            print("You selected an invalid option.")
        end
    end
end

-- Run the main function
main()