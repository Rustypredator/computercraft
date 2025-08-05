-- VaultGuard Setup Script

local baseurl = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main"

print("VaultGuard Setup Script")
print("Select what component you are installing:")
print("1. VaultGuard")
print("2. Shooting Range")

local choice = io.read()
local url = ""

if choice == "1" then
    -- submenu for VaultGuard
    print("Select VaultGuard component:")
    print("1. Main Server")
    print("2. Door")
    print("3. User Terminal")
    local subChoice = io.read()
    if subChoice == "1" then
        url = baseurl .. "/components/vaultguard/main/main.lua"
    elseif subChoice == "2" then
        url = baseurl .. "/components/vaultguard/door/main.lua"
    elseif subChoice == "3" then
        url = baseurl .. "/components/vaultguard/terminal/main.lua"
    else
        print("Invalid choice. Exiting setup.")
        os.exit(1)
    end
elseif choice == "2" then
    -- submenu for Shooting Range
    print("Select Shooting Range component:")
    print("1. Main Computer")
    print("2. Target")
    local subChoice = io.read()
    if subChoice == "1" then
        url = baseurl .. "/components/shootingrange/main/main.lua"
    elseif subChoice == "2" then
        url = baseurl .. "/components/shootingrange/target/main.lua"
    else
        print("Invalid choice. Exiting setup.")
        os.exit(1)
    end
else
    print("Invalid choice. Exiting setup.")
    os.exit(1)
end

local response = http.get(url)
if response then
    local file = fs.open("startup.lua", "w")
    file.write(response.readAll())
    file.close()
    print("Script downloaded successfully.")
    print("Downloading required libraries...")
    -- download updater library
    local updaterUrl = baseurl .. "/libs/updater.lua"
    local updaterResponse = http.get(updaterUrl)
    if updaterResponse then
        local updaterFile = fs.open("libs/updater.lua", "w")
        updaterFile.write(updaterResponse.readAll())
        updaterFile.close()
        print("Updater library downloaded successfully.")
    else
        print("Failed to download the updater library. Please check your internet connection.")
    end
else
    print("Failed to download the script. Please check your internet connection.")
end