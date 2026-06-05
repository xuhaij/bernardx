--- Shared utilities for AI module
-- HTTP/JSON helpers, image content builders

local json = require('json')
local http = require('http')

local M = {}

---------------------------------------------------------------------------
-- Type definitions
---------------------------------------------------------------------------

---@class AI.Image.Base64Source
---@field type string "base64"
---@field media_type string e.g. "image/png"
---@field data string base64-encoded data

---@class AI.Image.UrlSource
---@field type string "url"
---@field url string

---@class AI.Image.ContentBlock
---@field type string "text"|"image"
---@field text? string
---@field source? AI.Image.Base64Source|AI.Image.UrlSource

---@class AI.OpenAI.ImageContentBlock
---@field type string "text"|"image_url"
---@field text? string
---@field image_url? {url: string}

---------------------------------------------------------------------------
-- HTTP
---------------------------------------------------------------------------

--- Send HTTP POST with JSON body, return parsed response
---@param url string
---@param body table request body (will be JSON-encoded)
---@param headers table<string, string> request headers
---@return table|nil response  parsed JSON on success
---@return string|nil error    error message on failure
function M.json_post(url, body, headers)
    local json_body = json.encode(body)
    local hdrs = M.merge({ ["Content-Type"] = "application/json" }, headers or {})

    local status, resp_body, err = http.post(url, json_body, "json", hdrs)

    if err then
        return nil, "http error: " .. err
    end

    if not resp_body then
        return nil, "empty response body (status " .. tostring(status) .. ")"
    end

    local ok, parsed = pcall(json.decode, resp_body)
    if not ok then
        return nil, "json decode error: " .. tostring(parsed) .. "\nraw: " .. resp_body
    end

    if status >= 400 then
        local msg = "api error (" .. status .. ")"
        if type(parsed) == "table" and parsed.error then
            if type(parsed.error) == "table" then
                msg = msg .. ": " .. (parsed.error.message or json.encode(parsed.error))
            else
                msg = msg .. ": " .. tostring(parsed.error)
            end
        else
            msg = msg .. ": " .. resp_body
        end
        return nil, msg
    end

    return parsed
end

---------------------------------------------------------------------------
-- Table helpers
---------------------------------------------------------------------------

--- Shallow merge two tables
function M.merge(a, b)
    local result = {}
    for k, v in pairs(a or {}) do result[k] = v end
    for k, v in pairs(b or {}) do result[k] = v end
    return result
end

---------------------------------------------------------------------------
-- Image helpers
---------------------------------------------------------------------------

--- Build Anthropic-format image content blocks
---@param text? string optional text before the image
---@param source string|AI.Image.Base64Source URL string or base64 source table
---@return AI.Image.ContentBlock[] content blocks
function M.image_content(text, source)
    local content = {}
    if text then
        table.insert(content, { type = "text", text = text })
    end
    if type(source) == "string" then
        table.insert(content, {
            type = "image",
            source = { type = "url", url = source },
        })
    elseif type(source) == "table" then
        table.insert(content, { type = "image", source = source })
    end
    return content
end

--- Build a base64 image source (for Anthropic format)
---@param media_type string e.g. "image/png"
---@param data string base64-encoded data
---@return AI.Image.Base64Source
function M.base64_source(media_type, data)
    return {
        type = "base64",
        media_type = media_type,
        data = data,
    }
end

--- Build OpenAI-format image content blocks
---@param text? string optional text
---@param source string|table URL string or {url="data:image/..."} table
---@return AI.OpenAI.ImageContentBlock[] content blocks
function M.openai_image_content(text, source)
    local content = {}
    if text then
        table.insert(content, { type = "text", text = text })
    end
    if type(source) == "string" then
        table.insert(content, {
            type = "image_url",
            image_url = { url = source },
        })
    elseif type(source) == "table" then
        table.insert(content, {
            type = "image_url",
            image_url = source,
        })
    end
    return content
end

return M
