
local baseUrl = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main"
local version = "0.0.4"

-- Update function to check for updates and download the latest version
-- @param currentVersion The current version of the script
-- @param url The URL to download the update from
-- @param versionUrl The URL to check the latest version
-- @param filePath The local file path to save the update
-- @return int 0 if the update was successful, 1 if no update was needed, or -1 if there was an error.
local function update(currentVersion, url, versionUrl, filePath)
    -- combine base URL with the provided URLs
    url = baseUrl .. url
    versionUrl = baseUrl .. versionUrl
    -- get the latest version from the version URL
    local response = http.get(versionUrl)
    if not response then
        print("Error: Could not fetch the latest version from " .. versionUrl)
        return -1
    end
    
    local latestVersion = response.readAll()
    response.close()
    -- compare the latest version with the current version
    if latestVersion ~= currentVersion then
        local updateResponse = http.get(url)
        if not updateResponse then
            print("Error: Could not download the update from " .. url)
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

local function updateLib(libName)
    local url = "/libs/" .. libName .. ".lua"
    local versionUrl = "/libs/" .. libName .. ".ver"
    local version = "0.0.0"
    if fs.exists("libs/" .. libName .. ".lua") then
        local lib = require("libs." .. libName)
        if lib and lib.version then
            version = lib.version  -- Get the version from the library if it exists
        end
    end
    
    return update(version, url, versionUrl, "libs/" .. libName .. ".lua")
end

local function selfUpdate()
    local url = "/libs/updater.lua"
    local versionUrl = "/libs/updater.ver"
    
    return update(version, url, versionUrl, "libs/updater.lua")
end

return {
    version = version,
    update = update,
    updateLib = updateLib,
    selfUpdate = selfUpdate
}