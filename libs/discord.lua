-- Discord Webhook Library
-- Provides functionality to send messages to Discord via webhooks

local updater = require("libs.updater")

-- Version of the Discord library
local version = "0.0.1"

-- self update function
local function update()
    local url = "/libs/discord.lua"
    local versionUrl = "/libs/discord.ver"
    updater.update(version, url, versionUrl, "libs/discord.lua")
end

--- Sends a message to a Discord webhook
-- @param webhookUrl (string) The Discord webhook URL
-- @param message (string or table) The message content or a table with message options
-- @return (boolean) Success status
-- @return (string) Response or error message
local function send(webhookUrl, message)
    if not webhookUrl or type(webhookUrl) ~= "string" then
        return false, "Invalid webhook URL"
    end

    local payload = {}

    if type(message) == "string" then
        payload.content = message
    elseif type(message) == "table" then
        payload = message
    else
        return false, "Message must be a string or table"
    end

    -- Encode payload as JSON
    local jsonPayload = textutils.serialiseJSON(payload)
    if not jsonPayload then
        return false, "Failed to encode message as JSON"
    end

    -- Send HTTP POST request
    local ok, response = pcall(http.post, webhookUrl, jsonPayload, {
        ["Content-Type"] = "application/json"
    })

    if not ok then
        return false, "HTTP request failed: " .. tostring(response)
    end

    if response then
        local responseText = response.readAll()
        response.close()

        -- Discord returns 204 No Content on success
        if response.getResponseCode() == 204 or response.getResponseCode() == 200 then
            return true, "Message sent successfully"
        else
            return false, "Discord returned code " .. response.getResponseCode() .. ": " .. responseText
        end
    end

    return false, "No response from Discord"
end

--- Sends a simple text message to a Discord webhook
-- @param webhookUrl (string) The Discord webhook URL
-- @param content (string) The message content
-- @return (boolean) Success status
-- @return (string) Response or error message
local function sendMessage(webhookUrl, content)
    return send(webhookUrl, {
        content = content
    })
end

--- Sends an embed message to a Discord webhook
-- @param webhookUrl (string) The Discord webhook URL
-- @param embed (table) The embed object (title, description, color, fields, etc.)
-- @return (boolean) Success status
-- @return (string) Response or error message
local function sendEmbed(webhookUrl, embed)
    if not embed or type(embed) ~= "table" then
        return false, "Embed must be a table"
    end

    return send(webhookUrl, {
        embeds = { embed }
    })
end

--- Sends a message with both content and embed
-- @param webhookUrl (string) The Discord webhook URL
-- @param content (string) The message content
-- @param embed (table) The embed object
-- @return (boolean) Success status
-- @return (string) Response or error message
local function sendRich(webhookUrl, content, embed)
    if not embed or type(embed) ~= "table" then
        return false, "Embed must be a table"
    end

    return send(webhookUrl, {
        content = content,
        embeds = { embed }
    })
end

--- Embed Builder class for constructing Discord embeds with method chaining
-- @return (table) A new embed builder instance
local function EmbedBuilder()
    local embed = {
        fields = {}
    }

    local builder = {}

    --- Sets the embed title
    -- @param title (string) The embed title
    -- @return (table) Self for method chaining
    function builder:setTitle(title)
        embed.title = title
        return self
    end

    --- Sets the embed description
    -- @param description (string) The embed description
    -- @return (table) Self for method chaining
    function builder:setDescription(description)
        embed.description = description
        return self
    end

    --- Sets the embed color (as decimal or hex)
    -- @param color (number) The color as decimal (e.g., 0xFF5733 or 16734515)
    -- @return (table) Self for method chaining
    function builder:setColor(color)
        embed.color = color
        return self
    end

    --- Sets the embed URL
    -- @param url (string) The embed URL
    -- @return (table) Self for method chaining
    function builder:setUrl(url)
        embed.url = url
        return self
    end

    --- Sets the embed timestamp
    -- @param timestamp (number) Unix timestamp (defaults to current time)
    -- @return (table) Self for method chaining
    function builder:setTimestamp(timestamp)
        embed.timestamp = timestamp or os.time()
        return self
    end

    --- Sets the author of the embed
    -- @param name (string) Author name
    -- @param url (string, optional) Author URL
    -- @param iconUrl (string, optional) Author icon URL
    -- @return (table) Self for method chaining
    function builder:setAuthor(name, url, iconUrl)
        embed.author = {
            name = name,
            url = url,
            icon_url = iconUrl
        }
        return self
    end

    --- Sets the footer of the embed
    -- @param text (string) Footer text
    -- @param iconUrl (string, optional) Footer icon URL
    -- @return (table) Self for method chaining
    function builder:setFooter(text, iconUrl)
        embed.footer = {
            text = text,
            icon_url = iconUrl
        }
        return self
    end

    --- Sets the thumbnail image
    -- @param url (string) Image URL
    -- @param width (number, optional) Image width
    -- @param height (number, optional) Image height
    -- @return (table) Self for method chaining
    function builder:setThumbnail(url, width, height)
        embed.thumbnail = {
            url = url,
            width = width,
            height = height
        }
        return self
    end

    --- Sets the large image
    -- @param url (string) Image URL
    -- @param width (number, optional) Image width
    -- @param height (number, optional) Image height
    -- @return (table) Self for method chaining
    function builder:setImage(url, width, height)
        embed.image = {
            url = url,
            width = width,
            height = height
        }
        return self
    end

    --- Adds a field to the embed
    -- @param name (string) Field name
    -- @param value (string) Field value
    -- @param inline (boolean, optional) Whether the field is inline
    -- @return (table) Self for method chaining
    function builder:addField(name, value, inline)
        table.insert(embed.fields, {
            name = name,
            value = value,
            inline = inline or false
        })
        return self
    end

    --- Builds and returns the embed object
    -- @return (table) The completed embed object
    function builder:build()
        -- Clean up empty tables
        if embed.author and not embed.author.name then
            embed.author = nil
        end
        if embed.footer and not embed.footer.text then
            embed.footer = nil
        end
        if embed.thumbnail and not embed.thumbnail.url then
            embed.thumbnail = nil
        end
        if embed.image and not embed.image.url then
            embed.image = nil
        end
        if #embed.fields == 0 then
            embed.fields = nil
        end

        return embed
    end

    return builder
end

--- Creates an embed builder with initial title and description
-- @param title (string) The embed title
-- @param description (string, optional) The embed description
-- @return (table) A new embed builder instance
local function createEmbed(title, description)
    local builder = EmbedBuilder()
    if title then
        builder:setTitle(title)
    end
    if description then
        builder:setDescription(description)
    end
    return builder
end

return {
    version = version,
    update = update,
    send = send,
    sendMessage = sendMessage,
    sendEmbed = sendEmbed,
    sendRich = sendRich,
    EmbedBuilder = EmbedBuilder,
    createEmbed = createEmbed
}
