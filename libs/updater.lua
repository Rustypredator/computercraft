
local baseUrl = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main"
local version = "0.0"

-- Update function to check for updates and download the latest version
-- @param currentVersion The current version of the script
-- @param url The URL to download the update from
-- @param versionUrl The URL to check the latest version
-- @param filePath The local file path to save the update
-- @return int 0 if the update was successful, 1 if no update was needed, or -1 if there was an error.
local function update(currentVersion, url, versionUrl, filePath)
    local response = http.get(versionUrl)
    if not response then
        return -1
    end
    
    local latestVersion = response.readAll()
    response.close()
    
    if latestVersion ~= currentVersion then
        local updateResponse = http.get(url)
        if not updateResponse then
            return -1
        end
        
        local file = fs.open(filePath, "w")
        file.write(updateResponse.readAll())
        file.close()
        
        return 0
    else
        return 1
    end
end

local function selfUpdate()
    local url = baseUrl .. "/libs/updater.lua"
    local versionUrl = baseUrl .. "/libs/updater.ver"
    
    update(version, url, versionUrl, "libs/updater.lua")
end