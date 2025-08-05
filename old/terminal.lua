-- Vault Guard Terminal 0.1

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- initialize variables
local version = "0.1"
local mainComputer = peripheral.find("computer")
local term_w, term_h = term.getSize()
local connected = false
local lastStatus = nil
local responseMessage = nil

-- check if main computer is found
if not mainComputer then
    print("No main computer found.")
    return
end

-- set computer label
os.setComputerLabel("Vault Guard Terminal")

-- Open rednet at initialization
rednet.open("bottom") -- modem is on bottom

function selfUpdate()
    -- urls
    local baseUrl = "https://raw.githubusercontent.com/Rustypredator/computercraft/refs/heads/main"
    local url = baseUrl .. "/old/terminal.lua"
    local versionUrl = baseUrl .. "/old/terminal.ver"
    -- get the latest version from the version URL
    local response = http.get(versionUrl)
    if not response then
        print("Error: Could not fetch the latest version from " .. versionUrl)
        return -1
    end
    local latestVersion = response.readAll()
    response.close()
    -- compare the latest version with the current version
    if latestVersion ~= version then
        local updateResponse = http.get(url)
        if not updateResponse then
            print("Error: Could not download the update from " .. url)
            return -1
        end
        
        local file = fs.open("startup.lua", "w")
        file.write(updateResponse.readAll())
        file.close()
        
        print("Update successful to version " .. latestVersion)
        return 0
    else
        print("No update needed, already on the latest version: " .. version)
        return 1
    end
end

function connectToMainComputer()
    -- Look for main computer
    rednet.broadcast({action = "status"}, "vaultGuard")
    local timeout = os.startTimer(3)
    while true do
        local event, param, message, protocol = os.pullEvent()
        if event == "rednet_message" and protocol == "vaultGuard" then
            connected = true
            lastStatus = message.locked
            return true
        elseif event == "timer" and param == timeout then
            return false
        end
    end
end

function displayUI()
    term.clear()
    term.setCursorPos(1, 1)
    term.write("========== Vault Guard Terminal " .. version .. " ==========")

    term.setCursorPos(1, 3)
    if connected then
        term.setTextColor(colors.green)
        term.write("Connected to main computer")
        term.setTextColor(colors.white)

        term.setCursorPos(1, 5)
        if lastStatus == true then
            term.setTextColor(colors.yellow)
            term.write("Vault is LOCKED")
            term.setTextColor(colors.white)

            term.setCursorPos(1, 7)
            term.write("Enter password to unlock: ")
        else
            term.setTextColor(colors.red)
            term.write("Vault is UNLOCKED")
            term.setTextColor(colors.white)

            term.setCursorPos(1, 7)
            term.write("Press [L] to lock the vault")
        end
    else
        term.setTextColor(colors.red)
        term.write("Not connected to main computer")
        term.setTextColor(colors.white)

        term.setCursorPos(1, 5)
        term.write("Attempting to connect...")
    end

    -- Display any response message
    if responseMessage then
        term.setCursorPos(1, 9)
        if responseMessage.success then
            term.setTextColor(colors.green)
        else
            term.setTextColor(colors.red)
        end
        term.write(responseMessage.message)
        term.setTextColor(colors.white)
    end

    term.setCursorPos(1, term_h)
    term.write("======== " .. os.date("%H:%M:%S") .. " ========")
end

function getStatus()
    rednet.broadcast({action = "status"}, "vaultGuard")
    local timeout = os.startTimer(1)

    while true do
        local event, param, message, protocol = os.pullEvent()
        if event == "rednet_message" and protocol == "vaultGuard" then
            lastStatus = message.locked
            return true
        elseif event == "timer" and param == timeout then
            connected = false
            return false
        end
    end
end

function unlockVault(password)
    rednet.broadcast({action = "unlock", password = password}, "vaultGuard")
    local timeout = os.startTimer(4) -- wait 4 seconds for response

    while true do
        local event, param, message, protocol = os.pullEvent()
        if event == "rednet_message" and protocol == "vaultGuard" then
            responseMessage = message
            if message.success then
                lastStatus = false
            end
            return true
        elseif event == "timer" and param == timeout then
            responseMessage = {success = false, message = "No response from main computer"}
            return false
        end
    end
end

function lockVault()
    rednet.broadcast({action = "lock"}, "vaultGuard")
    local timeout = os.startTimer(4) -- wait 4 seconds for response

    while true do
        local event, param, message, protocol = os.pullEvent()
        if event == "rednet_message" and protocol == "vaultGuard" then
            responseMessage = message
            if message.success then
                lastStatus = true
            end
            return true
        elseif event == "timer" and param == timeout then
            responseMessage = {success = false, message = "No response from main computer"}
            return false
        end
    end
end

selfUpdate()

-- Check that main computer is online, turn it on if not
if not mainComputer.isOn() then
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Main computer is offline. Turning it on...")
    mainComputer.turnOn()
    os.sleep(2) -- Give time for the main computer to boot
end

-- First time connection
connectToMainComputer()

-- Main loop with parallel event handling
while true do
    -- Function to handle rednet message events
    local function listenForRednet()
        while true do
            local event, sender, message, protocol = os.pullEvent("rednet_message")
            if protocol == "vaultGuard" then
                if type(message) == "table" then
                    -- Check if it's a status update
                    if message.locked ~= nil then
                        lastStatus = message.locked
                        connected = true
                        displayUI() -- Redraw immediately when status changes
                        return
                    -- Check if it's a response message
                    elseif message.success ~= nil then
                        responseMessage = message
                        if message.success and message.message and message.message:find("unlocked") then
                            lastStatus = false
                        elseif message.success and message.message and message.message:find("locked") then
                            lastStatus = true
                        end
                        displayUI() -- Redraw immediately when receiving a response
                        return
                    -- Check if it's a password change notification
                    elseif message.passwordChanged then
                        responseMessage = { success = true, message = message.message or "Password has been updated" }
                        displayUI() -- Redraw to show the password change notification
                        return
                    end
                end
            end
        end
    end

    -- Function to handle user input
    local function handleUserInput()
        if connected then
            if lastStatus == true then
                -- Vault is locked, prompt for password
                term.setCursorPos(26, 7)
                local password = read("*")
                if password and #password > 0 then
                    unlockVault(password)
                    displayUI()
                end
                return
            else
                -- Vault is unlocked, wait for lock command
                term.setCursorPos(1, term_h - 2)
                local event, key = os.pullEvent("key")
                if key == keys.l then
                    lockVault()
                end
                responseMessage = nil
                displayUI()
                return
            end
        else
            -- Not connected, reconnect
            connectToMainComputer()
            displayUI()
            return
        end
    end

    -- Function to handle periodic status check (without redrawing)
    local function checkStatus()
        local timer = os.startTimer(5) -- Increased to 5 seconds since we're not using this for UI updates
        while true do
            local event, param = os.pullEvent("timer")
            if param == timer then
                -- Check status occasionally to ensure we're still connected, but don't redraw
                if connected then
                    rednet.broadcast({action = "status"}, "vaultGuard")
                end
                return
            end
        end
    end

    -- Run only two functions in parallel - listen for rednet events and handle user input
    -- We removed the periodic UI refresh and now rely on rednet updates to trigger UI changes
    parallel.waitForAny(listenForRednet, handleUserInput, checkStatus)
end