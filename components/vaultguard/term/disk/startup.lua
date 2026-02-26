-- VaultGuard Terminal Disk Bootstrapper
-- Place this on a floppy disk in a disk drive adjacent to the terminal computer.
-- On first boot it downloads the terminal program & updater to the computer.
-- The script stays on the disk but skips itself on subsequent boots.
--
-- IMPORTANT: /clone copies disk NBT including the disk ID, so all cloned
-- floppies share the same virtual filesystem. Do NOT delete this script
-- or it will disappear for all cloned terminals.

-- Skip if the computer already has a startup script installed
if fs.exists("startup.lua") then
    return
end

local baseurl = "https://raw.githubusercontent.com/Rustypredator/computercraft/refs/heads/main"

print("[Bootstrap] Setting up VaultGuard Terminal...")

-- Download the terminal program
print("[Bootstrap] Downloading terminal program...")
local response = http.get(baseurl .. "/components/vaultguard/term/term.lua")
if not response then
    print("[Bootstrap] ERROR: Failed to download terminal program.")
    print("[Bootstrap] Check HTTP is enabled and try again.")
    sleep(5)
    return
end
local file = fs.open("startup.lua", "w")
file.write(response.readAll())
file.close()
response.close()
print("[Bootstrap] Terminal program installed.")

-- Download the updater library (required for first boot)
print("[Bootstrap] Downloading updater library...")
if not fs.exists("libs") then
    fs.makeDir("libs")
end
local updaterResponse = http.get(baseurl .. "/libs/updater.lua")
if updaterResponse then
    local updaterFile = fs.open("libs/updater.lua", "w")
    updaterFile.write(updaterResponse.readAll())
    updaterFile.close()
    updaterResponse.close()
    print("[Bootstrap] Updater library installed.")
else
    print("[Bootstrap] WARNING: Failed to download updater library.")
    print("[Bootstrap] The terminal may fail on first boot.")
end

print("[Bootstrap] Setup complete! Rebooting...")
sleep(1)
os.reboot()
