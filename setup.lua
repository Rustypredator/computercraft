-- VaultGuard Setup Script

local baseurl = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main"

local function downloadLibraries()
    local libraries = {
        {
            name = "box_drawing",
            url = baseurl .. "/libs/box_drawing.lua"
        },
        {
            name = "updater",
            url = baseurl .. "/libs/updater.lua"
        }
    }

    for _, lib in ipairs(libraries) do
        local response = http.get(lib.url)
        if response then
            local file = fs.open("libs/" .. lib.name .. ".lua", "w")
            file.write(response.readAll())
            file.close()
            print("Downloaded " .. lib.name .. " library successfully.")
        else
            print("Failed to download " .. lib.name .. " library. Please check your internet connection.")
        end
    end
end

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
    downloadLibraries()
else
    print("Failed to download the script. Please check your internet connection.")
end