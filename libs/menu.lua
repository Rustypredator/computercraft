-- Menu-Drawing API

-- imports
local updater = require("libs.updater")
local ui = require("libs.ui")

-- Version of the box drawing library
local version = "0.0.9"

-- self update function
local function update()
    local url = "/libs/menu.lua"
    local versionUrl = "/libs/menu.ver"
    updater.update(version, url, versionUrl, "libs/menu.lua")
end

local function monitorSelect(monitor, options, prompt, title, subtitle)
    local timer = os.startTimer(10)  -- Set a timer for 10 seconds to prevent hanging
    local selectionMade = false
    while not selectionMade do
        monitor.clear()
        ui.drawMonitorOuterBox(monitor, "", title, "", "", "", subtitle)
        monitor.setCursorPos(3, 3)
        monitor.write(prompt .. ":")
        local startY = 4
        for i, option in ipairs(options) do
            monitor.setCursorPos(3, startY + i - 1)
            monitor.write("-> " .. option)
        end
        local selectedOption = nil
        while true do
            local event, side, x, y = os.pullEvent()
            if event == "monitor_touch" then
                if x >= 3 and x <= monitor.getSize() and y >= startY and y < startY + #options then
                    selectedOption = y - startY + 1
                    selectionMade = true
                    return selectedOption
                end
            elseif event == "timer" then
                print("No selection made within the time limit. Restarting selection...")
                -- break the inner loop to restart the selection process
                break
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