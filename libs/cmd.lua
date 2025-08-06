-- CMD Util Library

-- imports
local updater = require("libs.updater")

-- Version of the CMD library
local version = "0.0.3"

-- self update function
local function update()
    local url = "/libs/cmd.lua"
    local versionUrl = "/libs/cmd.ver"
    updater.update(version, url, versionUrl, "libs/cmd.lua")
end

local function getNearestPlayerName(message)
    local success, output = commands.exec("tell @p " .. (message or "dont mind me :)"))
    if success and output and #output > 0 then
        local name = output[1]:match("You whisper to ([^ ]+):")
        name = tostring(name)
        if name and #name > 0 then
            return name
        else
            return "unknown"
        end
    end
end

return {
    version = version,
    update = update,
    getNearestPlayerName = getNearestPlayerName,
}