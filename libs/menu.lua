-- Menu-Drawing API

-- imports
local updater = require("libs.updater")
local bd = require("libs.box_drawing")

-- Version of the box drawing library
local version = "0.0.6"

-- self update function
local function update()
    local url = "/libs/menu.lua"
    local versionUrl = "/libs/menu.ver"
    updater.update(version, url, versionUrl, "libs/menu.lua")
end

-- Draws a menu with options and handles user input
-- @param options Table containing menu options
-- @return Selected option index or nil if no selection was made
local function termSelect(options, prompt, title, subtitle)
    -- we assume the screen has not been cleared, we do that.
    term.clear()
    -- draw an outer box
    bd.termOuterRim(title, subtitle)
    -- we draw the menu options inside the box
    term.setCursorPos(3, 3)
    term.write(prompt .. ":")
    -- start drawing from the fourth line, third column, so there is a space above, and a space to the left
    -- then add each option on a new line
    local startY = 4
    for i, option in ipairs(options) do
        term.setCursorPos(3, startY + i - 1)
        term.write("-> " .. option)
    end
    -- wait for user input
    local selectedOption = nil
    while true do
        local event, side, x, y = os.pullEvent("mouse_click")
        if event == "mouse_click" then
            -- check if the click is within the menu options
            if x >= 3 and x <= term.getSize() and y >= startY and y < startY + #options then
                -- calculate the selected option index
                selectedOption = y - startY + 1
                return selectedOption
            end
        end
    end
end

local function monitorSelect(options, prompt, title, subtitle)
    monitor = peripheral.find("monitor")
    if not monitor then
        print("No monitor found. Please connect a monitor to use this function.")
        return nil
    end
    monitor.clear()
    bd.monitorOuterRim(title, subtitle, monitor)
    monitor.setCursorPos(3, 3)
    monitor.write(prompt .. ":")
    local startY = 4
    for i, option in ipairs(options) do
        monitor.setCursorPos(3, startY + i - 1)
        monitor.write("-> " .. option)
    end
    local selectedOption = nil
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if event == "monitor_touch" then
            if x >= 3 and x <= monitor.getSize() and y >= startY and y < startY + #options then
                selectedOption = y - startY + 1
                return selectedOption
            end
        end
    end
end

return {
    version = version,
    update = update,
    termSelect = termSelect,
    monitorSelect = monitorSelect
}