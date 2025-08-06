-- Text Util Library

-- imports
local updater = require("libs.updater")

-- Version of the box drawing library
local version = "0.0.1"

-- self update function
local function update()
    local url = "/libs/txtutil.lua"
    local versionUrl = "/libs/txtutil.ver"
    updater.update(version, url, versionUrl, "libs/txtutil.lua")
end

local function writeCentered(mon, y, text, width)
    local x = math.floor((width - #text) / 2) + 1
    mon.setCursorPos(x, y)
    mon.write(text)
end

return {
    version = version,
    update = update,
    writeCentered = writeCentered
}