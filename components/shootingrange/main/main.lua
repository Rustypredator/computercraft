-- Shooting Range Main Script

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("menu")
updater.updateLib("txtutil")
updater.updateLib("ui")
updater.updateLib("cmd")
updater.updateLib("crypt")
-- require the libraries
local menu = require("libs.menu")
local txtutil = require("libs.txtutil")
local ui = require("libs.ui")
local cmd = require("libs.cmd")
local crypt = require("libs.crypt")

local version = "0.2.9"

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

local function countdown(mon, seconds)
    -- display a countdown on the monitor
    if not mon then
        print("No monitor found for countdown.")
        return
    end
    mon.clear()
    ui.drawMonitorOuterBox(mon, "", "Shooting Range", "v" .. version)
    for i = seconds, 1, -1 do
        txtutil.writeCentered(mon, math.floor(mon.getSize() / 2), tostring(i), mon.getSize())
        sleep(1)
    end
end

local function listeningLoop(CHANNEL)
    local timeout = os.startTimer(10) -- record all hits for 10 seconds
    local modem = peripheral.find("modem")
    local hits = {}
    if modem then
        modem.open(CHANNEL) -- Open the modem on the specified channel
        print("Modem opened on channel " .. CHANNEL .. ". Listening for messages...")
    else
        print("Error: No modem found.")
        return {}
    end
    while true do
        local event, param1, param2, param3, param4 = os.pullEvent()
        if event == "modem_message" and param2 == CHANNEL then
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

local function getSecret()
    if not fs.exists("secret.txt") then
        local secretFile = fs.open("secret.txt", "w")
        secretFile.write("CHANGEME")
        secretFile.close()
    end
    local secretFile = fs.open("secret.txt", "r")
    local secret = secretFile.readAll()
    secretFile.close()
    return secret
end

local function saveSession(hits, playerName, playerUUID)
    print("Saving " .. #hits .. " hits for player: " .. playerName)
    local unixTimestamp = math.floor(os.epoch("utc") / 1000)
    -- save all hits to a file with the current timestamp in json format
    local sessionDir = "sessions"
    if not fs.exists(sessionDir) then
        fs.makeDir(sessionDir)
    end
    local fileName = sessionDir .. "/hits_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
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
    local data = {
        hits = hits,
        player = playerName,
        uuid = playerUUID,
        timestamp = unixTimestamp
    }
    local json = textutils.serializeJSON(data)
    file.write(json)
    file.close()
    -- try to save the data to the web api:
    -- create a hash to identify myself:
    local secret = getSecret()
    local hash = crypt.sha256(unixTimestamp .. secret)
    local requestData = {
        playerName = playerName,
        playerUUID = playerUUID,
        timestamp = unixTimestamp,
        hits = hits,
        hash = hash
    }
    local url = "https://taczsrscores.create-st.net/api/save"
    local response = http.post(url, textutils.serializeJSON(requestData), {
        ["Content-Type"] = "application/json"
    })
    if response and response.getResponseCode() == 200 then
        print("Session saved successfully to the webdb.")
    else
        print("Error saving session to the webdb:")
        print(response.getResponseCode())
        print(response.readAll())
    end
    return true
end

local function getSessionsList()
    -- produce a table of all files in the sessions directory
    local sessionsDir = "sessions"
    if not fs.exists(sessionsDir) then
        fs.makeDir(sessionsDir)
    end
    local files = fs.list(sessionsDir)
    -- sanitize file names to not include path or file extension.
    for i, file in ipairs(files) do
        files[i] = file:gsub("%.json$", "") -- remove .json extension
    end
    return files
end

local function getSession(sessionName)
    -- get a single session by name
    local sessionDir = "sessions"
    if not fs.exists(sessionDir) then
        fs.makeDir(sessionDir)
    end
    local fileName = sessionDir .. "/" .. sessionName .. ".json"
    if not fs.exists(fileName) then
        print("Error: File does not exist: " .. fileName)
        return nil
    end
    local file = fs.open(fileName, "r")
    if not file then
        print("Error: Could not open file for reading: " .. fileName)
        return nil
    end
    local fileContent = file.readAll()
    file.close()
    local data = textutils.unserializeJSON(fileContent)
    return data
end

local function calculateTotalScore(hits)
    local totalScore = 0
    for _, hit in ipairs(hits) do
        totalScore = totalScore + hit.strength
    end
    return totalScore
end

local function calculateAverageScore(hits)
    if #hits == 0 then return 0 end
    local totalScore = calculateTotalScore(hits)
    return totalScore / #hits
end

local function main()
    if not init() then
        print("Initialization failed. Exiting...")
        return
    end

    local CHANNEL = 9832

    -- Get Frequency
    local frequencyFile = fs.open("frequency.txt", "r")
    if frequencyFile then
        local line = frequencyFile.readLine()
        if line then
            CHANNEL = tonumber(line)
        end
        frequencyFile.close()
    else
        print("No frequency.txt file found. Using default frequency 9832.")
        local frequencyFile = fs.open("frequency.txt", "w")
        frequencyFile.write("9832")
        frequencyFile.close()
    end

    print("Channel: " .. CHANNEL)

    -- Try to find a monitor
    local mon = peripheral.find("monitor")
    local monW, monH = 0, 0
    if mon then
        monW, monH = mon.getSize()
        mon.setTextScale(0.5)
    else
        print("No Monitor!")
        return
    end
    -- try to find a speaker
    local speaker = peripheral.find("speaker")
    
    --- Main
    while true do
        txtutil.writeCentered(mon, math.floor(monH/2), "Please visit this url for a list of sessions:", monW)
        txtutil.writeCentered(mon, math.floor(monH/2) + 1, "https://taczsrscores.create-st.net", monW)
        txtutil.writeCentered(mon, math.floor(monH/2) + 2, "This is due to limitations with cc Displays", monW)
        local option = menu.monitorSelect(mon, {
            "Start Round"
        }, "Select an option", "Shooting Range", "v" .. version)
        if option == 1 then
            -- get nearest player name (should be the one who clicked the monitor)
            local playerName = cmd.getNearestPlayerName("Your Session is starting in 3 seconds, Get ready! (Listen for the Whistle)")
            local playerUUID = cmd.getNearestPlayerUUID()
            print("Recording all hits for 10 seconds...")
            countdown(mon, 3)
            if speaker then
                speaker.playSound("create_things_and_misc:portable_whistle", 1, 1)
            end
            txtutil.writeCentered(mon, math.floor(monH/2), "Waiting for hits...", monW)
            local hits = listeningLoop(CHANNEL)
            if speaker then
                speaker.playSound("create_things_and_misc:portable_whistle", 1, 1)
            end
            saveSession(hits, playerName, playerUUID)
            if mon then
                ui.drawMonitorOuterBox(mon, "", "Shooting Range", "v" .. version)
                if #hits > 0 then
                    txtutil.writeCentered(mon, math.floor(monH/2), "Hits recorded: " .. #hits, monW)
                    sleep(2)
                    mon.clear()
                    ui.drawMonitorOuterBox(mon, "", "Shooting Range", "v" .. version)
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
                    ui.drawMonitorOuterBox(mon, "", "Shooting Range", "v" .. version)
                    txtutil.writeCentered(mon, math.floor(monH/2), "Total: " .. calculateTotalScore(hits) .. " | Average: " .. calculateAverageScore(hits), monW)
                    sleep(2)
                    mon.clear()
                    ui.drawMonitorOuterBox(mon, "", "Shooting Range", "v" .. version)
                else
                    txtutil.writeCentered(mon, math.floor(monH/2), "No hits recorded.", monW)
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