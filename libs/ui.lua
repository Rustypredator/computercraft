-- UI Library

-- imports
local updater = require("libs.updater")

-- Version of the box drawing library
local version = "0.0.1"

-- self update function
local function update()
    local url = "/libs/ui.lua"
    local versionUrl = "/libs/ui.ver"
    updater.update(version, url, versionUrl, "libs/ui.lua")
end

local function drawMonitorButton(monitor, x, y, width, height, bgColor, fgColor, text)
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(bgColor)
    monitor.setTextColor(fgColor)
    monitor.write(string.rep(" ", width))  -- Clear the line
    monitor.setCursorPos(x + math.floor((width - #text) / 2), y + math.floor(height / 2))
    monitor.write(text)
end

local function drawMonitorBox(monitor, x, y, width, height, topLeftLabel, topCenterLabel, topRightLabel, bottomLeftLabel, bottomCenterLabel, bottomRightLabel)
    -- Draw top border with corners and labels
    monitor.setCursorPos(x, y)
    local top = "+" .. string.rep("-", width - 2) .. "+"
    if topLeftLabel and #topLeftLabel > 0 then
        top = "+ " .. topLeftLabel .. " " .. string.rep("-", width - 4 - #topLeftLabel) .. "+"
    end
    if topCenterLabel and #topCenterLabel > 0 then
        local centerStart = math.floor((width - #topCenterLabel) / 2)
        top = top:sub(1, centerStart) .. topCenterLabel .. top:sub(centerStart + #topCenterLabel + 1)
    end
    if topRightLabel and #topRightLabel > 0 then
        top = top:sub(1, width - 2 - #topRightLabel) .. " " .. topRightLabel .. " +"
    end
    monitor.write(top)
    -- Draw sides
    for i = 1, height - 2 do
        monitor.setCursorPos(x, y + i)
        monitor.write("|" .. string.rep(" ", width - 2) .. "|")
    end
    -- Draw bottom border with corners and labels
    monitor.setCursorPos(x, y + height - 1)
    local bottom = "+" .. string.rep("-", width - 2) .. "+"
    if bottomLeftLabel and #bottomLeftLabel > 0 then
        bottom = "+ " .. bottomLeftLabel .. " " .. string.rep("-", width - 4 - #bottomLeftLabel) .. "+"
    end
    if bottomCenterLabel and #bottomCenterLabel > 0 then
        local centerStart = math.floor((width - #bottomCenterLabel) / 2)
        bottom = bottom:sub(1, centerStart) .. bottomCenterLabel .. bottom:sub(centerStart + #bottomCenterLabel + 1)
    end
    if bottomRightLabel and #bottomRightLabel > 0 then
        bottom = bottom:sub(1, width - 2 - #bottomRightLabel) .. " " .. bottomRightLabel .. " +"
    end
    monitor.write(bottom)
end

local function drawMonitorOuterBox(monitor, topLeftLabel, topCenterLabel, topRightLabel, bottomLeftLabel, bottomCenterLabel, bottomRightLabel)
    -- calculate monitor size
    local width, height = monitor.getSize()
    -- draw the outer box
    drawMonitorBox(monitor, 1, 1, width, height,
        topLeftLabel or "", topCenterLabel or "", topRightLabel or "",
        bottomLeftLabel or "", bottomCenterLabel or "", bottomRightLabel or "")
end

return {
    version = version,
    update = update,
    drawMonitorButton = drawMonitorButton,
    drawMonitorBox = drawMonitorBox,
    drawMonitorOuterBox = drawMonitorOuterBox
}