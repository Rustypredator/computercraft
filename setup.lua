-- VaultGuard Setup Script

local baseurl = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main"

print("VaultGuard Setup Script")
print("Select what component you are installing:")
print("1. VaultGuard Main Server")
print("2. VaultGuard Door")
print("3. VaultGuard Terminal")

local choice = io.read()
local url = ""

if choice == "1" then
    print("Installing VaultGuard Main Server...")
    url = baseurl .. "/components/main/main.lua"
elseif choice == "2" then
    print("Installing VaultGuard Door...")
    url = baseurl .. "/components/door/door.lua"
elseif choice == "3" then
    print("Installing VaultGuard Terminal...")
    url = baseurl .. "/components/term/term.lua"
else
    print("Invalid choice. Please run the setup script again.")
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