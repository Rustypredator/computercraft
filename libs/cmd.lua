-- CMD Util Library

-- imports
local updater = require("libs.updater")

-- Version of the CMD library
local version = "0.0.2"

-- self update function
local function update()
    local url = "/libs/cmd.lua"
    local versionUrl = "/libs/cmd.ver"
    updater.update(version, url, versionUrl, "libs/cmd.lua")
end

local function getNearestPlayerName()
    local success, output = commands.exec("execute as @p run data get entity @s")
    if success and output and #output > 0 then
        -- Output example: "Player data for Player123 has the following properties: ..."
        local name = output[1]:match("Player data for ([^ ]+)")
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