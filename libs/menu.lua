-- Menu-Drawing API

-- imports
local updater = require("libs.updater")
local ui = require("libs.ui")

-- Version of the box drawing library
local version = "0.1.1"

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

local function termSelect(options, prompt)
    print(prompt .. ":")
    for i, option in ipairs(options) do
        print(i .. ". " .. option)
    end
    local choice = nil
    while not choice do
        local input = io.read()
        local num = tonumber(input)
        if num and num >= 1 and num <= #options then
            choice = num
        else
            print("Invalid choice. Please enter a number between 1 and " .. #options)
        end
    end
    return choice
end

-- Display a yes/no confirmation dialog on a monitor
-- @param monitor: wrapped monitor peripheral
-- @param message: the question to display
-- @param title: title for the box
-- @return boolean: true if confirmed, false if cancelled
local function monitorConfirm(monitor, message, title)
    local width, height = monitor.getSize()
    monitor.clear()
    ui.drawMonitorOuterBox(monitor, "", title or "Confirm", "", "", "", "")
    -- Draw the message centered
    monitor.setCursorPos(3, 3)
    monitor.write(message)
    -- Draw Yes/No buttons
    local btnWidth = math.floor((width - 6) / 2)
    local btnY = math.floor(height / 2) + 1
    ui.drawMonitorButton(monitor, 3, btnY, btnWidth, 1, colors.green, colors.white, "Yes")
    ui.drawMonitorButton(monitor, 3 + btnWidth + 1, btnY, btnWidth, 1, colors.red, colors.white, "No")
    -- Wait for touch
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if y == btnY then
            if x >= 3 and x < 3 + btnWidth then
                return true
            elseif x >= 3 + btnWidth + 1 and x < 3 + btnWidth * 2 + 1 then
                return false
            end
        end
    end
end

-- Display a status/message screen on a monitor with an auto-dismiss timer
-- @param monitor: wrapped monitor peripheral
-- @param message: status message to display
-- @param title: title for the box
-- @param duration: seconds to display before auto-dismiss (nil = wait for touch)
local function monitorStatus(monitor, message, title, duration)
    local width, height = monitor.getSize()
    monitor.clear()
    ui.drawMonitorOuterBox(monitor, "", title or "Status", "", "", "", "")
    -- Word-wrap and display message
    local maxWidth = width - 4
    local lines = {}
    for line in message:gmatch("[^\n]+") do
        while #line > maxWidth do
            table.insert(lines, line:sub(1, maxWidth))
            line = line:sub(maxWidth + 1)
        end
        table.insert(lines, line)
    end
    local startY = 3
    for i, line in ipairs(lines) do
        if startY + i - 1 < height then
            monitor.setCursorPos(3, startY + i - 1)
            monitor.write(line)
        end
    end
    if duration then
        sleep(duration)
    else
        -- Show "tap to continue" and wait for touch
        monitor.setCursorPos(3, height - 1)
        monitor.setTextColor(colors.gray)
        monitor.write("Tap to continue...")
        monitor.setTextColor(colors.white)
        os.pullEvent("monitor_touch")
    end
end

return {
    version = version,
    update = update,
    termSelect = termSelect,
    monitorSelect = monitorSelect,
    monitorConfirm = monitorConfirm,
    monitorStatus = monitorStatus
}