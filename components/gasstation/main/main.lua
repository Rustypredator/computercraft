-- Gas Station Configuration Module

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("menu")

-- require the libraries
local menu = require("libs.menu")

local version = "0.0.1"

-- Config file paths
local TANKS_CONFIG  = "gasstation_tanks.json"
local PRICES_CONFIG = "gasstation_prices.json"

--- Self Update function
local function updateSelf()
    local updateUrl = "/components/gasstation/main/main.lua"
    local versionUrl = "/components/gasstation/main/main.ver"
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

--- Load a JSON config file. Returns nil if the file does not exist or cannot be parsed.
local function loadConfig(path)
    if not fs.exists(path) then
        return nil
    end
    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()
    return textutils.unserialiseJSON(content)
end

--- Save a Lua table as a JSON config file.
local function saveConfig(path, data)
    local file = fs.open(path, "w")
    file.write(textutils.serialiseJSON(data))
    file.close()
end

--- Load tanks config, returning an empty list when the file is absent.
local function loadTanks()
    return loadConfig(TANKS_CONFIG) or {}
end

--- Load prices config, returning an empty table when the file is absent.
local function loadPrices()
    return loadConfig(PRICES_CONFIG) or {}
end

--- Print a visual separator line.
local function separator()
    print(string.rep("-", 40))
end

--- Prompt the user and return trimmed input.
local function prompt(label)
    io.write(label .. ": ")
    return io.read()
end

-- ---------------------------------------------------------------------------
-- Tank configuration screen
-- ---------------------------------------------------------------------------

local function configureTanks()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        local tanks = loadTanks()

        print("=== Fuel Tank Configuration ===")
        separator()
        if #tanks == 0 then
            print("  (no tanks configured)")
        else
            for i, tank in ipairs(tanks) do
                print(string.format(
                    "%d. [%s]  %-14s  %-12s  %d L  (%s)",
                    i, tank.id, tank.label, tank.fuelType, tank.maxVolume,
                    tank.networkName or "?"
                ))
            end
        end
        separator()

        local choice = menu.termSelect(
            {"Add Tank", "Edit Tank", "Remove Tank", "Back"},
            "Select option"
        )

        if choice == 1 then
            -- ---- Add a new tank ----
            local label = prompt("Tank label")
            local networkName = prompt("Network name (e.g. create:fluid_tank_1)")
            local fuelType = prompt("Fuel type (e.g. diesel, gasoline, kerosene)")
            local maxVolumeStr = prompt("Max volume in litres")
            local maxVolume = tonumber(maxVolumeStr)

            if not maxVolume or maxVolume <= 0 then
                print("Invalid max volume. Press ENTER to continue.")
                io.read()
            else
                local newId = "tank_" .. tostring(#tanks + 1)
                table.insert(tanks, {
                    id          = newId,
                    label       = label,
                    networkName = networkName,
                    fuelType    = fuelType,
                    maxVolume   = maxVolume,
                })
                saveConfig(TANKS_CONFIG, tanks)
                print("Tank '" .. label .. "' added (id: " .. newId .. "). Press ENTER.")
                io.read()
            end

        elseif choice == 2 then
            -- ---- Edit an existing tank ----
            if #tanks == 0 then
                print("No tanks to edit. Press ENTER.")
                io.read()
            else
                local numStr = prompt("Tank number to edit")
                local num = tonumber(numStr)
                if not num or num < 1 or num > #tanks then
                    print("Invalid selection. Press ENTER.")
                    io.read()
                else
                    local tank = tanks[num]
                    print("Editing: " .. tank.label)
                    separator()

                    local newLabel = prompt("New label (blank = keep '" .. tank.label .. "')")
                    if newLabel ~= "" then tank.label = newLabel end

                    local newNetName = prompt("New network name (blank = keep '" .. (tank.networkName or "") .. "')")
                    if newNetName ~= "" then tank.networkName = newNetName end

                    local newFuelType = prompt("New fuel type (blank = keep '" .. tank.fuelType .. "')")
                    if newFuelType ~= "" then tank.fuelType = newFuelType end

                    local newVolStr = prompt("New max volume (blank = keep " .. tank.maxVolume .. ")")
                    if newVolStr ~= "" then
                        local newVol = tonumber(newVolStr)
                        if newVol and newVol > 0 then
                            tank.maxVolume = newVol
                        else
                            print("Invalid volume — keeping old value.")
                        end
                    end

                    tanks[num] = tank
                    saveConfig(TANKS_CONFIG, tanks)
                    print("Tank updated. Press ENTER.")
                    io.read()
                end
            end

        elseif choice == 3 then
            -- ---- Remove a tank ----
            if #tanks == 0 then
                print("No tanks to remove. Press ENTER.")
                io.read()
            else
                local numStr = prompt("Tank number to remove")
                local num = tonumber(numStr)
                if not num or num < 1 or num > #tanks then
                    print("Invalid selection. Press ENTER.")
                    io.read()
                else
                    local removed = table.remove(tanks, num)
                    saveConfig(TANKS_CONFIG, tanks)
                    print("Removed: " .. removed.label .. ". Press ENTER.")
                    io.read()
                end
            end

        elseif choice == 4 then
            break
        end
    end
end

-- ---------------------------------------------------------------------------
-- Fuel price configuration screen
-- ---------------------------------------------------------------------------

local function configurePrices()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        local prices = loadPrices()

        print("=== Fuel Price Configuration ===")
        separator()

        local fuelList = {}
        for fuelType, price in pairs(prices) do
            table.insert(fuelList, fuelType)
            print(string.format("  %-16s  %.2f / L", fuelType, price))
        end
        if #fuelList == 0 then
            print("  (no prices configured)")
        end
        separator()

        local choice = menu.termSelect(
            {"Set / Update Price", "Remove Price Entry", "Back"},
            "Select option"
        )

        if choice == 1 then
            -- ---- Set or update a price ----
            local fuelType = prompt("Fuel type")
            if fuelType == "" then
                print("Fuel type cannot be empty. Press ENTER.")
                io.read()
            else
                local priceStr = prompt("Price per litre")
                local price = tonumber(priceStr)
                if not price or price < 0 then
                    print("Invalid price. Press ENTER.")
                    io.read()
                else
                    prices[fuelType] = price
                    saveConfig(PRICES_CONFIG, prices)
                    print(string.format("Price set: %s = %.2f / L. Press ENTER.", fuelType, price))
                    io.read()
                end
            end

        elseif choice == 2 then
            -- ---- Remove a price entry ----
            if #fuelList == 0 then
                print("No price entries to remove. Press ENTER.")
                io.read()
            else
                local fuelType = prompt("Fuel type to remove")
                if prices[fuelType] ~= nil then
                    prices[fuelType] = nil
                    saveConfig(PRICES_CONFIG, prices)
                    print("Removed price for '" .. fuelType .. "'. Press ENTER.")
                else
                    print("Fuel type '" .. fuelType .. "' not found. Press ENTER.")
                end
                io.read()
            end

        elseif choice == 3 then
            break
        end
    end
end

-- ---------------------------------------------------------------------------
-- View current config summary
-- ---------------------------------------------------------------------------

local function viewConfig()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Current Gas Station Config ===")
    separator()

    local tanks = loadTanks()
    print("Tanks (" .. #tanks .. "):")
    if #tanks == 0 then
        print("  (none)")
    else
        for _, tank in ipairs(tanks) do
            print(string.format(
                "  [%s]  %-14s  %-12s  %d L  net:%s",
                tank.id, tank.label, tank.fuelType, tank.maxVolume,
                tank.networkName or "?"
            ))
        end
    end

    separator()

    local prices = loadPrices()
    print("Prices:")
    local hasPrices = false
    for fuelType, price in pairs(prices) do
        print(string.format("  %-16s  %.2f / L", fuelType, price))
        hasPrices = true
    end
    if not hasPrices then
        print("  (none)")
    end

    separator()
    print("Press ENTER to return.")
    io.read()
end

-- ---------------------------------------------------------------------------
-- Auto-discover tanks on the wired network
-- ---------------------------------------------------------------------------

local TANK_PREFIX = "create:fluid_tank_"

local function discoverTanks()
    local tanks = loadTanks()

    -- Build a set of already-known network names for fast lookup
    local known = {}
    for _, tank in ipairs(tanks) do
        if tank.networkName then
            known[tank.networkName] = true
        end
    end

    local added = 0
    for _, name in ipairs(peripheral.getNames()) do
        if name:sub(1, #TANK_PREFIX) == TANK_PREFIX and not known[name] then
            -- Query fluid contents to pre-fill fuelType
            local fuelType = "unknown"
            local ok, tankData = pcall(peripheral.call, name, "tanks")
            if ok and type(tankData) == "table" and tankData[1] then
                local fluidName = tankData[1].name or "unknown"
                -- Strip the namespace prefix (e.g. "minecraft:") for readability
                fuelType = fluidName:match(":(.+)$") or fluidName
            end

            local newId = "tank_" .. tostring(#tanks + added + 1)
            table.insert(tanks, {
                id          = newId,
                label       = name,
                networkName = name,
                fuelType    = fuelType,
                maxVolume   = 0,
            })
            added = added + 1
            print("  Discovered: " .. name .. " (" .. fuelType .. ")")
        end
    end

    if added > 0 then
        saveConfig(TANKS_CONFIG, tanks)
        print(added .. " new tank(s) added. Set maxVolume in Tank Config.")
        sleep(2)
    end
end

-- ---------------------------------------------------------------------------
-- Startup / update check
-- ---------------------------------------------------------------------------

local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("Gas Station v" .. version)
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

    print("")
    print("Scanning for new tanks on the network...")
    discoverTanks()

    return true
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

local function main()
    if not init() then
        print("Initialization failed. Exiting.")
        return
    end

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Gas Station  v" .. version .. " ===")
        separator()

        local choice = menu.termSelect(
            {"Configure Tanks", "Configure Prices", "View Config", "Exit"},
            "Select option"
        )

        if choice == 1 then
            configureTanks()
        elseif choice == 2 then
            configurePrices()
        elseif choice == 3 then
            viewConfig()
        elseif choice == 4 then
            print("Goodbye!")
            break
        end
    end
end

-- Run
main()
