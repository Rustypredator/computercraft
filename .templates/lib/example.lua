-- Example Library

-- imports
local updater = require("libs.updater")

-- Version of the Example library
local version = "0.0.1"

-- self update function
local function update()
    local url = "/libs/example.lua"
    local versionUrl = "/libs/example.ver"
    updater.update(version, url, versionUrl, "libs/example.lua")
end

-- add methods here

return {
    version = version,
    update = update,
    -- export methods or variables by adding them here
}