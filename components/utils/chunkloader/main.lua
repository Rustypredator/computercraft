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
    local x, y = input:match("^(%-?%d+),%s*(%-?%d+)$")
    if x and y then
        return tonumber(x), tonumber(y)
    else
        return nil, nil
    end
end

local function getCoordinates()
    local configData = nil
    -- check for config file. if not found, ask user for dimensions and save to config
    -- if found, load dimensions from config
    if (fs.exists("chunkloader.cfg")) then
        local file = fs.open("chunkloader.cfg", "r")
        configData = textutils.unserialize(file.readAll())
        file.close()
    else
        print("No config file found. Please enter the dimensions for the chunkloader.")
        print("Please enter the coordinates of corner chunk 1 (format: x,y):")
        local corner1 = io.read()
        print("Please enter the coordinates of corner chunk 2 (format: x,y):")
        local corner2 = io.read()
        -- check input format and parse coordinates
        local x1, y1 = parseCoordinates(corner1)
        local x2, y2 = parseCoordinates(corner2)
        if x1 and y1 and x2 and y2 then
            configData = {
                dimensions = {
                    {x = x1, y = y1},
                    {x = x2, y = y2}
                }
            }
            local file = fs.open("chunkloader.cfg", "w")
            file.write(textutils.serialize(configData))
            file.close()
            print("Config saved successfully.")
        else
            print("Invalid input format. Please enter coordinates in the format: x,y")
            print("Exiting.")
            return
        end
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