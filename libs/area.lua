-- Area Library
-- Shared area management for VaultGuard components.

local updater = require("libs.updater")
local cmd = require("libs.cmd")

local version = "0.0.1"

-- self update function
local function update()
    local url = "/libs/area.lua"
    local versionUrl = "/libs/area.ver"
    updater.update(version, url, versionUrl, "libs/area.lua")
end

-- Default configuration (can be overridden via Area.configure())
local config = {
    templates = {
        top = {
            label = "Top Cap",
            min = {x = 29999071, y = 304, z = 29999039},
            max = {x = 29999024, y = 319, z = 29998992}
        },
        bottom = {
            label = "Bottom Cap",
            min = {x = 29999071, y = 304, z = 29998991},
            max = {x = 29999024, y = 319, z = 29998944}
        },
        cross = {
            label = "Crossroads",
            min = {x = 29999023, y = 304, z = 29998039},
            max = {x = 29998976, y = 319, z = 29998992}
        }
    },
    availableTemplates = {"bottom", "cross"},
    area = {
        size = 3, -- always squared (in chunks)
        gap = 1,
        spawnOffset = {x = 0, y = 0, z = 0},
    },
    assignArea = {
        min = {x = -28800000, y = -64, z = -28800000},
        max = {x = 28800000, y = 319, z = 28800000}
    },
    areaStorageFolder = "data/areas/",
    areaPlayerMapFile = "data/areaPlayerMap.txt"
}

local Area = {
    loaded = false,
    id = nil,
    playerUuid = nil,
    slices = nil,
    playermap = nil,
    min = nil,
    max = nil,
    spawn = nil
}

-- Override default config values
-- @param overrides: table with keys matching config structure (merged shallowly per top-level key)
function Area.configure(overrides)
    if not overrides then return end
    for k, v in pairs(overrides) do
        config[k] = v
    end
end

-- Get the current config (read-only reference)
function Area.getConfig()
    return config
end

------------------------------------------------------------------------
-- Playermap persistence
------------------------------------------------------------------------

function Area.loadPlayermap()
    local dir = string.match(config.areaPlayerMapFile, "^(.*)/")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    local file = fs.open(config.areaPlayerMapFile, "r")
    if file then
        local content = file.readAll()
        file.close()
        Area.playermap = textutils.unserialize(content) or {}
    else
        Area.playermap = {}
    end
    return true
end

function Area.savePlayermap()
    local dir = string.match(config.areaPlayerMapFile, "^(.*)/")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    local data = textutils.serialize(Area.playermap or {})
    local file = fs.open(config.areaPlayerMapFile, "w")
    file.write(data)
    file.close()
    return true
end

------------------------------------------------------------------------
-- Coordinate calculation
------------------------------------------------------------------------

function Area.calculateCoordinates()
    local areaWidth = config.area.size * 16  -- chunks to blocks
    local gapWidth = config.area.gap * 16
    local totalWidth = areaWidth + gapWidth

    local assignWidthX = config.assignArea.max.x - config.assignArea.min.x + 1
    local columnsPerRow = math.floor(assignWidthX / totalWidth)

    local columnIndex = (Area.id - 1) % columnsPerRow
    local rowIndex = math.floor((Area.id - 1) / columnsPerRow)

    local x_start = config.assignArea.min.x + columnIndex * totalWidth
    local z_start = config.assignArea.min.z + rowIndex * totalWidth

    Area.min = {x = x_start, y = config.assignArea.min.y, z = z_start}
    Area.max = {x = x_start + areaWidth - 1, y = config.assignArea.max.y, z = z_start + areaWidth - 1}

    -- Spawn at center of topmost slice
    Area.spawn = {
        x = x_start + math.floor(areaWidth / 2) + config.area.spawnOffset.x,
        y = config.assignArea.max.y - 8 + config.area.spawnOffset.y,
        z = z_start + math.floor(areaWidth / 2) + config.area.spawnOffset.z
    }
end

------------------------------------------------------------------------
-- Load / Save / Unload
------------------------------------------------------------------------

function Area.loadData(data)
    Area.id = data.id
    Area.playerUuid = data.playerUuid
    Area.slices = data.slices
    Area.calculateCoordinates()
end

function Area.load(areaId)
    local filePath = config.areaStorageFolder .. areaId .. ".txt"

    if fs.exists(filePath) then
        local file = fs.open(filePath, "r")
        if file then
            local content = file.readAll()
            file.close()
            if content ~= "" then
                local data = textutils.unserialize(content) or {}
                Area.loadData(data)
                Area.loaded = true
                return true
            end
        end
    else
        -- File doesn't exist — create with defaults
        Area.id = areaId
        Area.playerUuid = nil
        Area.slices = {}
        Area.calculateCoordinates()

        local sliceCount = math.floor((Area.max.y - Area.min.y + 1) / 16)
        for i = 1, sliceCount do
            Area.slices[i] = {
                index = i,
                yMin = Area.min.y + (i - 1) * 16,
                yMax = Area.min.y + i * 16 - 1
            }
        end

        Area.loaded = true
        Area.save()
        return true
    end

    return false
end

function Area.save()
    if not fs.exists(config.areaStorageFolder) then
        fs.makeDir(config.areaStorageFolder)
    end
    local saveData = {
        id = Area.id,
        playerUuid = Area.playerUuid,
        slices = Area.slices
    }
    local content = textutils.serialize(saveData)
    local file = fs.open(config.areaStorageFolder .. Area.id .. ".txt", "w")
    file.write(content)
    file.close()
    return true
end

function Area.unload()
    Area.loaded = false
    Area.id = nil
    Area.playerUuid = nil
    Area.slices = nil
    Area.playermap = nil
    Area.min = nil
    Area.max = nil
    Area.spawn = nil
    return true
end

------------------------------------------------------------------------
-- Assignment
------------------------------------------------------------------------

function Area.getFirstUnassignedAreaId()
    local counter = 1
    while true do
        local path = config.areaStorageFolder .. counter .. ".txt"
        if not fs.exists(path) then
            return counter
        end
        counter = counter + 1
    end
    return false
end

function Area.getAreaIdByPlayerUuid(playerUuid)
    Area.loadPlayermap()
    if Area.playermap[playerUuid] ~= nil then
        return Area.playermap[playerUuid]
    end
    return nil
end

function Area.assign(playerUuid)
    Area.playerUuid = playerUuid
    local sliceCount = math.floor((Area.max.y - Area.min.y + 1) / 16)
    Area.slices = {}
    for i = 1, sliceCount do
        Area.slices[i] = {
            index = i,
            yMin = Area.min.y + (i - 1) * 16,
            yMax = Area.min.y + i * 16 - 1
        }
    end
    Area.loadPlayermap()
    Area.playermap[playerUuid] = Area.id
    Area.savePlayermap()
    return true
end

function Area.unassign()
    Area.playerUuid = nil
    return true
end

------------------------------------------------------------------------
-- Slice helpers
------------------------------------------------------------------------

-- Get a slice index counting from the top (1 = topmost, 2 = second from top, etc.)
function Area.getSliceFromTop(fromTop)
    if not Area.slices or #Area.slices == 0 then return nil end
    local index = #Area.slices - fromTop + 1
    if index < 1 or index > #Area.slices then return nil end
    return index
end

------------------------------------------------------------------------
-- Template cloning
------------------------------------------------------------------------

-- Clone a template into a specific slice
-- @param sliceIndex: integer (1 = bottom, highest = top)
-- @param templateKey: string key in config.templates
-- @return success boolean
function Area.cloneTemplateToSlice(sliceIndex, templateKey)
    local template = config.templates[templateKey]
    if not template then
        print("Unknown template: " .. tostring(templateKey))
        return false
    end
    local slice = Area.slices[sliceIndex]
    if not slice then
        print("Invalid slice index: " .. tostring(sliceIndex))
        return false
    end
    local targetPos = {x = Area.min.x, y = slice.yMin, z = Area.min.z}
    local success = cmd.clone(template.min, template.max, targetPos)
    if not success then
        print("Clone of '" .. templateKey .. "' to slice " .. sliceIndex .. " (Y " .. slice.yMin .. "-" .. slice.yMax .. ") failed.")
    else
        print("Cloned '" .. templateKey .. "' to slice " .. sliceIndex .. " (Y " .. slice.yMin .. "-" .. slice.yMax .. ").")
    end
    return success
end

-- Move the contents of a slice one slot down (clone to the slice below)
-- @param sliceIndex: the slice to move (1-based, must be > 1)
-- @return success boolean
function Area.moveSliceDown(sliceIndex)
    if sliceIndex <= 1 then
        print("Cannot move the bottom slice further down.")
        return false
    end
    local srcSlice = Area.slices[sliceIndex]
    local dstSlice = Area.slices[sliceIndex - 1]
    if not srcSlice or not dstSlice then
        print("Invalid slice indices for move.")
        return false
    end
    local srcMin = {x = Area.min.x, y = srcSlice.yMin, z = Area.min.z}
    local srcMax = {x = Area.max.x, y = srcSlice.yMax, z = Area.max.z}
    local dstPos = {x = Area.min.x, y = dstSlice.yMin, z = Area.min.z}
    local success = cmd.clone(srcMin, srcMax, dstPos)
    if not success then
        print("Failed to move slice " .. sliceIndex .. " down.")
    end
    return success
end

-- Shift slices down from a target position and insert a template there.
-- @param fromTopIndex: which slot from the top to place the template (2 = below top cap)
-- @param templateKey: key in config.templates
-- @return success boolean
function Area.shiftDownAndInsert(fromTopIndex, templateKey)
    local targetSlice = Area.getSliceFromTop(fromTopIndex)
    if not targetSlice then
        print("Invalid target slice (from top " .. fromTopIndex .. ").")
        return false
    end
    if targetSlice <= 1 then
        print("No room to shift down. Area is full.")
        return false
    end

    -- Shift from bottom up to avoid overwriting
    for i = 2, targetSlice do
        local success = Area.moveSliceDown(i)
        if not success then
            print("Shift failed at slice " .. i)
            return false
        end
    end

    -- Clone the template into the freed slot
    local success = Area.cloneTemplateToSlice(targetSlice, templateKey)
    if not success then
        print("Failed to clone template into freed slot.")
        return false
    end
    return true
end

return {
    version = version,
    update = update,
    configure = Area.configure,
    getConfig = Area.getConfig,
    -- Playermap
    loadPlayermap = Area.loadPlayermap,
    savePlayermap = Area.savePlayermap,
    -- Coordinates
    calculateCoordinates = Area.calculateCoordinates,
    -- Load / Save
    loadData = Area.loadData,
    load = Area.load,
    save = Area.save,
    unload = Area.unload,
    -- Assignment
    getFirstUnassignedAreaId = Area.getFirstUnassignedAreaId,
    getAreaIdByPlayerUuid = Area.getAreaIdByPlayerUuid,
    assign = Area.assign,
    unassign = Area.unassign,
    -- Slices
    getSliceFromTop = Area.getSliceFromTop,
    -- Templates
    cloneTemplateToSlice = Area.cloneTemplateToSlice,
    moveSliceDown = Area.moveSliceDown,
    shiftDownAndInsert = Area.shiftDownAndInsert,
    -- Direct state access (for reading id, min, max, spawn, slices, etc.)
    _state = Area
}
