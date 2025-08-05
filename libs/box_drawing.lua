-- box-drawing api

-- imports
local updater = require("libs.updater")

-- Version of the box drawing library
local version = "0.0.6"

-- Box drawing characters
local topLeftCorner = "+"
local topRightCorner = "+"
local bottomLeftCorner = "+"
local bottomRightCorner = "+"
local horizontalLine = "-"
local verticalLine = "|"

-- self update function
local function update()
    local url = "/libs/box_drawing.lua"
    local versionUrl = "/libs/box_drawing.ver"
    updater.update(version, url, versionUrl, "libs/box_drawing.lua")
end

-- draws a box on the whole outline of the screen
-- optionally a title and subtitle can be added
-- title will be centered on the top line
-- subtitle will be bottom right aligned
local function termOuterRim(title, subtitle)
    local width, height = term.getSize()
    term.setCursorPos(1, 1)
    term.write(topLeftCorner .. string.rep(horizontalLine, width - 2) .. topRightCorner)

    for y = 2, height - 1 do
        term.setCursorPos(1, y)
        term.write(verticalLine .. string.rep(" ", width - 2) .. verticalLine)
    end

    term.setCursorPos(1, height)
    term.write(bottomLeftCorner .. string.rep(horizontalLine, width - 2) .. bottomRightCorner)

    if title then
        local titlePos = math.floor((width - #title) / 2) + 1
        term.setCursorPos(titlePos, 1)
        term.write(title)
    end

    if subtitle then
        local subPos = width - (#subtitle + 3) -- leave 2 spaces in bottom right corner to avoid overlap with the corner
        term.setCursorPos(subPos, height)
        term.write(" " .. subtitle .. " ")
    end

    -- reset cursor position
    term.setCursorPos(2, 2) -- move cursor to the second line, second column (inside the box)
end

local function monitorOuterRim(title, subtitle, monitor)
    if not monitor then
        print("No monitor found. Please connect a monitor to use this function.")
        return
    end
    local width, height = monitor.getSize()
    monitor.setCursorPos(1, 1)
    monitor.write(topLeftCorner .. string.rep(horizontalLine, width - 2) .. topRightCorner)

    for y = 2, height - 1 do
        monitor.setCursorPos(1, y)
        monitor.write(verticalLine .. string.rep(" ", width - 2) .. verticalLine)
    end

    monitor.setCursorPos(1, height)
    monitor.write(bottomLeftCorner .. string.rep(horizontalLine, width - 2) .. bottomRightCorner)

    if title then
        local titlePos = math.floor((width - #title) / 2) + 1
        monitor.setCursorPos(titlePos, 1)
        monitor.write(title)
    end

    if subtitle then
        local subPos = width - (#subtitle + 3) -- leave 2 spaces in bottom right corner to avoid overlap with the corner
        monitor.setCursorPos(subPos, height)
        monitor.write(" " .. subtitle .. " ")
    end

    -- reset cursor position
    monitor.setCursorPos(2, 2) -- move cursor to the second line, second column (inside the box)
end

return {
    version = version,
    update = update,
    termOuterRim = termOuterRim,
    monitorOuterRim = monitorOuterRim
}