-- Network Protocol Library
-- Generic Rednet request/response helpers.
-- Each program creates its own configured instance via netprotocol.create(config).

local updater = require("libs.updater")

local version = "0.0.2"

-- self update function
local function update()
    local url = "/libs/netprotocol.lua"
    local versionUrl = "/libs/netprotocol.ver"
    updater.update(version, url, versionUrl, "libs/netprotocol.lua")
end

------------------------------------------------------------------------
-- Modem helpers (shared, not instance-specific)
------------------------------------------------------------------------

--- Find and open the first available modem for Rednet.
-- @return string|nil  the peripheral side/name that was opened, or nil
local function openModem()
    -- Try sides first (direct attachment)
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            rednet.open(side)
            return side
        end
    end
    -- Try networked peripherals (wired modems via cables)
    local modem = peripheral.find("modem")
    if modem then
        local name = peripheral.getName(modem)
        rednet.open(name)
        return name
    end
    return nil
end

------------------------------------------------------------------------
-- Factory
------------------------------------------------------------------------

--- Create a configured protocol instance.
-- @param cfg table  { protocol = string, hostname = string, timeout = number (optional, default 5) }
-- @return table     instance with all bound networking methods
local function create(cfg)
    assert(cfg and cfg.protocol, "netprotocol.create: 'protocol' is required")
    assert(cfg.hostname,         "netprotocol.create: 'hostname' is required")

    local proto    = cfg.protocol
    local hostname = cfg.hostname
    local timeout  = cfg.timeout or 5

    local instance = {}

    -- Expose config for convenience
    instance.protocol = proto
    instance.hostname = hostname
    instance.timeout  = timeout

    ----------------------------------------------------------------
    -- Message builders
    ----------------------------------------------------------------

    function instance.buildRequest(action, data)
        return {
            type   = "request",
            action = action,
            data   = data or {},
        }
    end

    function instance.buildResponse(action, data)
        return {
            type    = "response",
            action  = action,
            success = true,
            data    = data or {},
        }
    end

    function instance.buildError(action, errorMsg)
        return {
            type    = "response",
            action  = action,
            success = false,
            error   = errorMsg or "Unknown error",
        }
    end

    ----------------------------------------------------------------
    -- Client helpers
    ----------------------------------------------------------------

    --- Discover the server on the network.
    -- @return number|nil  the Rednet ID of the server, or nil
    function instance.findServer()
        return rednet.lookup(proto, hostname)
    end

    --- Send a request and wait for the response.
    -- @param serverId  number   Rednet ID of the server
    -- @param action    string   action identifier
    -- @param data      table    request payload
    -- @return table|nil  the response table, or nil on timeout
    function instance.sendRequest(serverId, action, data)
        local request = instance.buildRequest(action, data)
        rednet.send(serverId, request, proto)

        local senderId, response = rednet.receive(proto, timeout)
        if senderId == serverId and type(response) == "table" then
            return response
        end
        return nil
    end

    ----------------------------------------------------------------
    -- Server helpers
    ----------------------------------------------------------------

    --- Register this computer as the protocol host.
    function instance.host()
        rednet.host(proto, hostname)
    end

    --- Block until an incoming request arrives.
    -- @param waitTimeout  number|nil  optional override (nil = wait forever)
    -- @return number|nil, table|nil  senderId and request, or nil, nil
    function instance.receiveRequest(waitTimeout)
        local senderId, message = rednet.receive(proto, waitTimeout)
        if senderId and type(message) == "table" and message.type == "request" then
            return senderId, message
        end
        return nil, nil
    end

    --- Send a response back to a specific client.
    -- @param clientId  number  Rednet ID of the client
    -- @param response  table   response built with buildResponse / buildError
    function instance.sendResponse(clientId, response)
        rednet.send(clientId, response, proto)
    end

    return instance
end

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

return {
    version   = version,
    update    = update,
    openModem = openModem,
    create    = create,
}
