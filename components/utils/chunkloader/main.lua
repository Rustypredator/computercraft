-- Chunkloader

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("cmd")

-- require the libraries
local cmd = require("libs.cmd")

local version = "0.0.1"

--- Self Update function
local function updateSelf()
    local updateUrl = "/components/utils/chunkloader/main.lua"
    local versionUrl = "/components/utils/chunkloader/main.ver"
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

--- Initialize the script
local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("Chunkloader v" .. version)
    print("")
    
    print("Checking for updates...")
    local updateResult = updateSelf()
    if updateResult == 0 then
        print("UPDATE SUCCESSFUL - REBOOTING")
        sleep(2)
        os.reboot()
    elseif updateResult == 1 then
        print("UP TO DATE")
    elseif updateResult == -1 then
        print("UPDATE FAILED")
        sleep(2)
    end
    
    return true
end

local function parseCoordinates(input)
    local x, z = input:match("^(%-?%d+),%s*(%-?%d+)$")
    if x and z then
        return tonumber(x), tonumber(z)
    else
        return nil, nil
    end
end

local function normalizeDimensions(configData)
    if type(configData) ~= "table" or type(configData.dimensions) ~= "table" then
        return nil, false
    end

    local corner1 = configData.dimensions[1]
    local corner2 = configData.dimensions[2]
    if type(corner1) ~= "table" or type(corner2) ~= "table" then
        return nil, false
    end

    local x1 = tonumber(corner1.x)
    local z1 = tonumber(corner1.z or corner1.y)
    local x2 = tonumber(corner2.x)
    local z2 = tonumber(corner2.z or corner2.y)
    if not (x1 and z1 and x2 and z2) then
        return nil, false
    end

    local normalized = {
        dimensions = {
            {x = x1, z = z1},
            {x = x2, z = z2}
        }
    }
    local migrated = (corner1.z == nil and corner1.y ~= nil) or (corner2.z == nil and corner2.y ~= nil)
    return normalized, migrated
end

local function getCoordinates()
    local configData = nil
    local migrated = false
    -- check for config file. if not found, ask user for dimensions and save to config
    -- if found, load dimensions from config
    if (fs.exists("chunkloader.cfg")) then
        local file = fs.open("chunkloader.cfg", "r")
        local loadedConfig = textutils.unserialize(file.readAll())
        file.close()

        configData, migrated = normalizeDimensions(loadedConfig)
        if not configData then
            print("Invalid config file format. Please re-enter dimensions.")
        end
    end

    if not configData then
        print("No config file found. Please enter the dimensions for the chunkloader.")
        print("Please enter the coordinates of corner chunk 1 (format: x,z):")
        local corner1 = io.read()
        print("Please enter the coordinates of corner chunk 2 (format: x,z):")
        local corner2 = io.read()
        -- check input format and parse coordinates
        local x1, z1 = parseCoordinates(corner1)
        local x2, z2 = parseCoordinates(corner2)
        if x1 and z1 and x2 and z2 then
            configData = {
                dimensions = {
                    {x = x1, z = z1},
                    {x = x2, z = z2}
                }
            }
        else
            print("Invalid input format. Please enter coordinates in the format: x,z")
            print("Exiting.")
            return
        end
    end

    local file = fs.open("chunkloader.cfg", "w")
    file.write(textutils.serialize(configData))
    file.close()
    if migrated then
        print("Config migrated to x,z format.")
    else
        print("Config saved successfully.")
    end

    return configData.dimensions
end

--- Main function
local function main()
    if not init() then
        print("Initialization failed. Exiting.")
        return
    end
    
    print("Initialization complete. Starting chunkloader utility...")
    
    local dimensions = getCoordinates()
    if not dimensions then
        return
    end
    
    -- use dimensions to load chunks here
    cmd.forceLoadChunkRegion(dimensions[1], dimensions[2])
    
    print("\nPress ENTER to exit.")
    io.read()
end

-- Run the main function
main()