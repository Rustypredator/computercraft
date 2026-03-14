-- Lootbox Finder Utility

-- prevent terminating the script:
os.pullEvent = os.pullEventRaw

-- updater
local updater = require("libs.updater")
updater.updateSelf()
updater.updateLib("cmd")
updater.updateLib("discord")

-- require the libraries
local cmd = require("libs.cmd")
local discord = require("libs.discord")

local version = "0.0.1"

-- Configuration
local config = {
    -- Block IDs to scan for (add more as needed)
    targetBlocks = {
        "regenerating_loot_blocks:regen_loot_block"
    },
    -- Discord webhook URL (set this to your webhook)
    webhookUrl = "https://discord.com/api/webhooks/1482485833113276590/HGFalK-bCQ16G9PWbS9QrQzhBJ_cQ3Ly4wGmISfRoPL6mx46OsRqIlErCFSBZHSRdCwv",
    -- Scan radius in blocks (set higher for larger search areas)
    maxRadius = 5000,
    -- Y coordinates to scan (adjust based on your world)
    minY = 0,
    maxY = 256,
    -- Scan interval in seconds (to avoid lag)
    scanInterval = 0.1,
}

--- Self Update function
local function updateSelf()
    local updateUrl = "/components/utils/lootbox_finder/main.lua"
    local versionUrl = "/components/utils/lootbox_finder/main.ver"
    return updater.update(version, updateUrl, versionUrl, "startup.lua")
end

--- Initialize the script
local function init()
    term.clear()
    term.setCursorPos(1, 1)
    print("Lootbox Finder Utility v" .. version)
    print("")
    
    -- Check if HTTP API is enabled
    if not http then
        print("Error: HTTP API is not enabled.")
        print("  -> Discord notifications will not work")
        return false
    end
    
    -- Check if Discord webhook is configured
    if config.webhookUrl == "" then
        print("Error: Discord webhook URL not configured in main.lua")
        print("  -> Please set config.webhookUrl to your webhook URL")
        return false
    end
    
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

--- Check if a block ID matches the target blocks
local function isTargetBlock(blockId)
    for _, target in ipairs(config.targetBlocks) do
        if blockId == target then
            return true
        end
    end
    return false
end

--- Test if a block exists at the given position
-- Uses /testforblock command to check block type
local function testBlock(pos)
    local success, output = commands.exec(
        string.format("testforblock %d %d %d", pos.x, pos.y, pos.z)
    )
    -- Parse the output to get block type
    if success and output and #output > 0 then
        local outputStr = table.concat(output, "\n")
        -- Output format varies, try to extract block name
        local blockId = outputStr:match("Found (%S+)")
        if not blockId then
            blockId = outputStr:match("(%S+)")
        end
        return blockId
    end
    return nil
end

--- Format block data as an embed for Discord
local function formatBlockEmbed(pos, blockId, nbtData)
    local embed = discord.createEmbed(
        "Lootbox Found!",
        "A target block has been detected"
    )
    
    embed:setColor(0xFFD700)  -- Gold color
    embed:setAuthor("Lootbox Finder")
    
    -- Add position field
    embed:addField("Position", 
        string.format("X: %d, Y: %d, Z: %d", pos.x, pos.y, pos.z),
        false)
    
    -- Add block type
    embed:addField("Block Type", 
        blockId or "Unknown",
        true)
    
    -- Add NBT data if available
    if nbtData and #nbtData > 0 then
        local nbtStr = table.concat(nbtData, "\n")
        -- Truncate if too long
        if #nbtStr > 1024 then
            nbtStr = nbtStr:sub(1, 1020) .. "..."
        end
        embed:addField("NBT Data", 
            "```\n" .. nbtStr .. "\n```",
            false)
    end
    
    embed:setTimestamp()
    return embed:build()
end

--- Send block discovery to Discord
local function reportLootbox(pos, blockId, nbtData)
    if not config.webhookUrl or config.webhookUrl == "" then
        print("Warning: Discord webhook not configured, skipping report")
        return
    end
    
    local embed = formatBlockEmbed(pos, blockId, nbtData)
    local success, message = discord.sendEmbed(config.webhookUrl, embed)
    
    if success then
        print("✓ Reported lootbox at " .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. " to Discord")
    else
        print("✗ Failed to report lootbox: " .. message)
    end
end

--- Generate scan positions in expanding square spiral from spawn
-- Returns a generator function that yields positions
local function scanPositionGenerator()
    local x, z = 0, 0
    local step = 1
    local dirIndex = 1
    local stepCount = 0
    local stepsInDirection = 1
    local directionChanges = 0
    
    local directions = {
        {dx = 1, dz = 0},   -- East
        {dx = 0, dz = 1},   -- South
        {dx = -1, dz = 0},  -- West
        {dx = 0, dz = -1},  -- North
    }
    
    return function()
        if step > config.maxRadius then
            return nil  -- Scan complete
        end
        
        local dir = directions[dirIndex]
        local pos = {x = x, z = z}
        
        -- Move for the next iteration
        x = x + dir.dx
        z = z + dir.dz
        stepCount = stepCount + 1
        
        -- Check if we need to change direction
        if stepCount >= stepsInDirection then
            stepCount = 0
            dirIndex = dirIndex + 1
            if dirIndex > 4 then
                dirIndex = 1
            end
            directionChanges = directionChanges + 1
            
            -- Every 2 direction changes, increase step size
            if directionChanges % 2 == 0 then
                stepsInDirection = stepsInDirection + 1
                step = step + 1
            end
        end
        
        return pos
    end
end

--- Main scanning loop
local function scanWorld()
    print("Starting world scan...")
    print("Target blocks: " .. table.concat(config.targetBlocks, ", "))
    print("")
    
    local scanGen = scanPositionGenerator()
    local blocksFound = 0
    local positionsScanned = 0
    
    while true do
        local xzPos = scanGen()
        if not xzPos then
            break
        end
        
        positionsScanned = positionsScanned + 1
        
        -- Scan from minY to maxY
        for y = config.minY, config.maxY do
            local pos = {x = xzPos.x, y = y, z = xzPos.z}
            
            -- Test the block at this position
            local blockId = testBlock(pos)
            
            if blockId and isTargetBlock(blockId) then
                print("\n❗ Found target block: " .. blockId .. " at " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
                
                -- Get NBT data from the block
                local success, nbtData = cmd.dataGetBlock(pos)
                
                if success then
                    print("  ✓ Retrieved NBT data")
                    blocksFound = blocksFound + 1
                else
                    print("  ✗ Failed to retrieve NBT data")
                    nbtData = nil
                end
                
                -- Report to Discord
                reportLootbox(pos, blockId, nbtData)
            end
            
            -- Prevent lag with a small sleep
            if y % 10 == 0 then
                sleep(config.scanInterval)
            end
        end
        
        -- Progress feedback every 100 x,z positions
        if positionsScanned % 100 == 0 then
            print("Scanned " .. positionsScanned .. " chunks, found " .. blocksFound .. " lootboxes...")
        end
    end
    
    print("\n========================================")
    print("Scan complete!")
    print("Total chunks scanned: " .. positionsScanned)
    print("Total lootboxes found: " .. blocksFound)
    print("========================================")
end

--- Main function
local function main()
    if not init() then
        print("Initialization failed. Exiting.")
        return
    end
    
    print("Ready to start scanning.")
    print("Press ENTER to begin, or Ctrl+C to exit.")
    io.read()
    
    scanWorld()
    
    print("\nPress ENTER to exit.")
    io.read()
end

-- Run the main function
main()
