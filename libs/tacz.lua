-- TACZ Library

-- imports
local updater = require("libs.updater")
local cmd = require("libs.cmd")

-- Version of the TACZ library
local version = "0.0.1"

-- self update function
local function update()
    local url = "/libs/tacz.lua"
    local versionUrl = "/libs/tacz.ver"
    updater.update(version, url, versionUrl, "libs/tacz.lua")
end

-- planned methods:
-- isgun (bool)
-- extract gunid
-- extract ammoid

return {
    version = version,
    update = update
}