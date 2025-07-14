-- VaultGuard Setup Script

print("VaultGuard Setup Script")
print("Select what component you are installing:")
print("1. VaultGuard Main Server")
print("2. VaultGuard Door")
print("3. VaultGuard Terminal")

local choice = io.read()
local url = ""

if choice == "1" then
    print("Installing VaultGuard Main Server...")
    url = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main/components/main/main.lua"
elseif choice == "2" then
    print("Installing VaultGuard Door...")
    url = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main/components/door/door.lua"
elseif choice == "3" then
    print("Installing VaultGuard Terminal...")
    url = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main/components/term/term.lua"
else
    print("Invalid choice. Please run the setup script again.")
end

local response = http.get(url)
if response then
    local file = fs.open("startup.lua", "w")
    file.write(response.readAll())
    file.close()
    print("Script downloaded successfully.")
else
    print("Failed to download the script. Please check your internet connection.")
end