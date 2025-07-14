-- VaultGuard Main Server Script

local version = "0.0.2"

-- Self Update function
-- This function checks for updates to the main server script and updates it if a new version is available.
-- @return int 0 if the update was successful, 1 if no update was needed, or -1 if there was an error.
local function updateSelf()
    local selfUpdateUrl = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main/main.lua"
    local selfVersionUrl = "https://raw.githubusercontent.com/Rustypredator/cc-vault-guard/refs/heads/main/main.ver"
    local response = http.get(selfVersionUrl)
    if response then
        local latestVersion = response.readAll()
        response.close()
        if latestVersion ~= version then
            local updateResponse = http.get(selfUpdateUrl)
            if updateResponse then
                local file = fs.open("startup.lua", "w")
                file.write(updateResponse.readAll())
                file.close()
                return 0  -- Update successful
            else
                return -1  -- Error downloading the update
            end
        else
            return 1
        end
    else
        return -1  -- Error checking for updates
    end
end

local function init()
    print(" -> Initializing VaultGuard Main Server Script " .. version .. "...")
    -- do some checks:
    if not http then
        print("Error: HTTP API is not enabled.")
        print("  -> Updates will not work")
        print("  -> Please enable it in the settings.")
        -- do not break, just warn
        for i = 1, 5 do
            print(".")
            sleep(1)
        end
    else
        print(" -> HTTP API")
        print(" -> Checking for updates...")
        local updateResult = updateSelf()
        if updateResult == 0 then
            print(" -> UPDATE SUCCESSFUL")
            print(" -> REBOOTING")
            sleep(2)
            os.reboot()  -- Reboot to apply the update
        elseif updateResult == 1 then
            print(" -> UP TO DATE")
        elseif updateResult == -1 then
            print(" -> UPDATE FAILED")
            sleep(2)
        end
    end
    return true
end

local function main()
    if not init() then
        print("Initialization failed. Exiting...")
        return
    end

    -- Main server logic goes here
    -- For example, starting the server, handling requests, etc.
end

-- Run the main function
main()