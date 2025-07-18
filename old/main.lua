-- Vault Guard

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- initialize variables
local version = "0.1"
local monitor = peripheral.find("monitor")
local sgs = peripheral.find("Create_SequencedGearshift")
local terminal = peripheral.find("computer")

-- set computer label
os.setComputerLabel("Vault Guard Main Computer")

if not monitor then
    print("No monitor found.")
    return
end
if not sgs then
    print("No Sequenced Gearshift found.")
    return
end
if not terminal then
    print("No computer found.")
    return
end

function selfUpdate()
    -- urls
    local baseUrl = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main"
    local url = baseUrl .. "/old/main.lua"
    local versionUrl = baseUrl .. "/old/main.ver"
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

function LoadPassword()
    -- Load the password from a file named "password.txt"
    -- if the file is not present, create it with a default random password
    local file = fs.open("password.txt", "r")
    if not file then
        file = fs.open("password.txt", "w")
        local password = RandomPassword()
        file.writeLine(password)
        file.close()
        return password
    else
        local password = file.readLine()
        file.close()
        return password
    end
end

function UpdatePassword(newPassword)
    -- Update the password in the "password.txt" file
    local file = fs.open("password.txt", "w")
    file.writeLine(newPassword)
    file.close()
end

function RandomPassword()
    -- Generate a random password of 8 characters
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local password = ""
    for i = 1, 8 do
        password = password .. string.sub(chars, math.random(1, #chars), math.random(1, #chars))
    end
    return password
end

function IsLocked()
    -- Top of computer receives a redstone signal when unlocked
    local locked = redstone.getInput("top")
    if locked then
        return false -- If the top receives a redstone signal, it is unlocked
    else
        return true -- If the top does not receive a redstone signal, it is locked
    end
end

function Lock()
    if not sgs then
        print("No Sequenced Gearshift found.")
        return false
    end
    -- Check if the gearshift is already locked
    if IsLocked() then
        print("Vault is already locked.")
        return true
    end
    
    -- Print locking message
    MonitorPrintLocking()
    
    -- move gearshift to 50 degrees
    sgs.rotate(50)
    
    -- wait for the door to be locked:
    while not IsLocked() do
        os.sleep(0.1) -- wait for the gearshift to lock
        monitor.write(".")
    end
    
    monitor.setCursorPos(1, 3)
    monitor.write("-> Vault locked.")
    -- Broadcast the state change to all terminals
    rednet.broadcast({locked = IsLocked(), message = "Vault has been locked"}, "vaultGuard")
    
    return true
end

function Unlock()
    if not sgs then
        print("No Sequenced Gearshift found.")
        return false
    end

    -- Print unlocking message
    MonitorPrintUnlocking()

    -- move gearshift to 0 degrees by rotating 50 degrees in the opposite direction
    sgs.rotate(50, -1)

    -- wait for the door to be unlocked:
    while IsLocked() do
        os.sleep(0.1) -- wait for the gearshift to unlock
        monitor.write(".")
    end

    monitor.setCursorPos(1, 3)
    monitor.write("-> Vault unlocked.")
    -- Broadcast the state change to all terminals
    rednet.broadcast({locked = IsLocked(), message = "Vault has been unlocked"}, "vaultGuard")

    return true
end

function Initialize()
    -- Initialize the monitor
    monitor.setTextScale(0.5)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Vault Guard " .. version)
    monitor.setCursorPos(1, 2)
    monitor.write("-> Initializing...")
    
    -- Load the password from a file
    local password = LoadPassword()
    
    monitor.setCursorPos(1, 3)
    monitor.write("-> Password loaded...")
    -- we assume the gearshift is currently in locked position (50 degrees)
    monitor.setCursorPos(1, 4)
    if IsLocked() then
        monitor.write("-> Vault is locked.")
    else
        monitor.write("-> Vault is unlocked, locking it now...")
    end
    
    -- Lock the vault if it's unlocked
    if not IsLocked() then
        Lock()
    end
    
    -- The terminal is another computer that will just be used to input the password from the outside of the vault.
    monitor.setCursorPos(1, 5)
    if terminal.isOn() then
        monitor.write("-> Terminal is on.")
    else
        monitor.write("-> Terminal is off, Turning it on...")
    end
    
    if not terminal.isOn() then
        terminal.turnOn()
    end
    
    monitor.setCursorPos(1, 6)
    monitor.write("-> Terminal ready...")
    monitor.setCursorPos(1, 8)
    monitor.write("Use the main Computer to access settings.")
end

function MonitorPrintLocking()
    -- clear the monitor and print the locking message
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Vault Guard " .. version)
    monitor.setCursorPos(1, 2)
    monitor.write("-> Locking vault.")
end

function MonitorPrintUnlocking()
    -- clear the monitor and print the unlocking message
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Vault Guard " .. version)
    monitor.setCursorPos(1, 2)
    monitor.write("-> Unlocking vault.")
end

function MonitorPrintPasswordUpdate()
    -- clear the monitor and print the password update message
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Vault Guard " .. version)
    monitor.setCursorPos(1, 2)
    monitor.write("-> Updating password.")
    monitor.setCursorPos(1, 3)
    monitor.setTextColor(colors.yellow)
    monitor.write("-> Please enter the new password at the main Computer.")
    monitor.setTextColor(colors.white)
    monitor.setCursorPos(1, 4)
    monitor.write("-> Waiting for input...")
end

function MonitorPrintMainMenu()
    -- monitor dimensions: 36x24
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("========== " .. "Vault Guard " .. version .. " ==========")
    monitor.setCursorPos(1, 3)
    -- status with according text:
    if IsLocked() then
        monitor.setTextColor(colors.green)
        monitor.write("Vault is locked.")
        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1, 5)
        monitor.write("-> Unlock Vault")
    else
        monitor.setTextColor(colors.red)
        monitor.write("Vault is unlocked.")
        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1, 5)
        monitor.write("-> Lock Vault")
    end
    -- button to update the password
    monitor.setCursorPos(1, 6)
    monitor.write("-> Update Password")
    -- button to exit the program
    monitor.setCursorPos(1, 7)
    monitor.write("-> Exit")
    monitor.setCursorPos(1, 24)
    monitor.write("======== " .. os.date("%H:%M:%S") .. " ========")
end

function HostRednet()
    -- create a rednet host:
    rednet.open("left")
    rednet.host("vaultGuard", "main_computer")
end

selfUpdate()
Initialize()
HostRednet() -- host the rednet service for terminals to connect to

-- Setup flag for password update mode
local passwordUpdateMode = false

-- wait for user input
while true do
    -- Draw the menu at the beginning of each loop iteration
    MonitorPrintMainMenu()
    
    -- Check if we need to handle password update mode first
    if passwordUpdateMode then
        MonitorPrintPasswordUpdate()
        print("Please enter the new password:")
        
        -- Now read() will block as expected since we're not in parallel mode
        local newPassword = read('*')
        
        if newPassword and #newPassword > 0 then
            UpdatePassword(newPassword)
            print("Password updated successfully.")
            monitor.setCursorPos(1, 4)
            monitor.write("-> Password updated.")
            
            -- Notify terminals that password has been changed
            rednet.broadcast({
                passwordChanged = true, 
                message = "Password has been updated"
            }, "vaultGuard")
            
            -- Wait a moment so the user can see the update confirmation
            os.sleep(1.5)
        else
            monitor.setCursorPos(1, 4)
            monitor.write("-> Invalid password.")
            
            -- Wait a moment so the user can see the error message
            os.sleep(1.5)
        end
        
        -- Reset the flag
        passwordUpdateMode = false
    else
        -- Define functions for parallel execution
        local function handleMonitorEvents()
            while true do
                local event, side, x, y = os.pullEvent("monitor_touch")
                if event == "monitor_touch" then
                    if x >= 1 and y == 5 then
                        -- user clicked the lock / unlock button
                        if IsLocked() then
                            MonitorPrintUnlocking()
                            Unlock()
                        else
                            MonitorPrintLocking()
                            Lock()
                        end
                    elseif x >= 1 and y == 6 then
                        -- Signal that we want to enter password update mode
                        passwordUpdateMode = true
                        return
                    elseif x >= 1 and y == 7 then
                        -- user clicked the exit button
                        monitor.clear()
                        monitor.setCursorPos(1, 1)
                        monitor.write("Vault Guard " .. version)
                        monitor.setCursorPos(1, 3)
                        monitor.write("-> Exiting...")
                        
                        -- Wait a moment to show the exit message
                        os.sleep(1)
                        return -- exit the function, which will end the parallel API
                    end
                    return -- Return after handling an event to refresh the menu
                end
            end
        end
        
        local function handleRednet()
            while true do
                local event, sender, message, protocol = os.pullEvent("rednet_message")
                if protocol == "vaultGuard" then
                    -- Process rednet message
                    if type(message) == "table" and message.action then
                        if message.action == "unlock" and message.password then
                            local storedPassword = LoadPassword()
                            if message.password == storedPassword then
                                if IsLocked() then
                                    MonitorPrintUnlocking()
                                    Unlock()
                                    rednet.send(sender, {success = true, message = "Vault unlocked."}, "vaultGuard")
                                else
                                    rednet.send(sender, {success = false, message = "Vault is already unlocked."}, "vaultGuard")
                                end
                            else
                                rednet.send(sender, {success = false, message = "Incorrect password."}, "vaultGuard")
                            end
                        elseif message.action == "lock" then
                            if not IsLocked() then
                                MonitorPrintLocking()
                                Lock()
                                rednet.send(sender, {success = true, message = "Vault locked."}, "vaultGuard")
                            else
                                rednet.send(sender, {success = false, message = "Vault is already locked."}, "vaultGuard")
                            end
                        elseif message.action == "status" then
                            rednet.send(sender, {locked = IsLocked()}, "vaultGuard")
                        end
                    end
                    return -- Return after handling to refresh the menu
                end
            end
        end

        local function handlePeriodicRefresh()
            -- Create a timer that will trigger every second
            local timer = os.startTimer(1)
            while true do
                local event, param = os.pullEvent("timer")
                if param == timer then
                    -- Timer expired, return to refresh the menu in the main loop
                    return
                end
            end
        end
        
        -- Run all three event handlers in parallel, exit when any completes
        parallel.waitForAny(handleMonitorEvents, handleRednet, handlePeriodicRefresh)
    end
    
    os.sleep(0.1) -- Small delay before refreshing
end