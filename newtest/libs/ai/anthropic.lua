--- Anthropic Messages API client
-- @module ai.anthropic

local json = require('json')
local utils = require('ai.utils')

local M = {}

local ANTHROPIC_VERSION = "2023-06-01"

---------------------------------------------------------------------------
-- Type definitions
---------------------------------------------------------------------------

---@class AI.Anthropic.ToolCall
---@field id string tool_use block id
---@field name string tool name
---@field input table parsed input arguments

---@class AI.Anthropic.MessagesOpts
---@field messages table[] conversation messages (required)
---@field system? string|table system prompt string or content blocks
---@field model? string override default model
---@field max_tokens? integer override default max_tokens
---@field temperature? number
---@field top_p? number
---@field stop_sequences? string[]
---@field tools? table[] tool definitions
---@field tool_choice? string|table "auto"|"any"|{type="tool",name="..."}|{type="none"}
---@field metadata? table {user_id="..."}

---@class AI.Anthropic.Response
---@field id string message id
---@field type string "message"
---@field role string "assistant"
---@field content table[] content blocks [{type,text?,"tool_use"?,...}]
---@field model string model used
---@field stop_reason string "end_turn"|"tool_use"|"stop_sequence"|"max_tokens"
---@field stop_sequence string|nil
---@field usage {input_tokens:integer,output_tokens:integer}

---------------------------------------------------------------------------
-- Client constructor
---------------------------------------------------------------------------

--- Create a new Anthropic API client
---@param config AI.ClientConfig
---@return table client
function M.new(config)
    assert(config and config.api_key, "api_key is required")

    local client = {
        api_key = config.api_key,
        base_url = config.base_url or "https://api.anthropic.com",
        model = config.model or "claude-sonnet-4-20250514",
        max_tokens = config.max_tokens or 4096,
        default_headers = config.default_headers or {},
    }

    setmetatable(client, { __index = M })
    return client
end

---------------------------------------------------------------------------
-- Internal
---------------------------------------------------------------------------

function M:_headers()
    return utils.merge(self.default_headers, {
        ["x-api-key"] = self.api_key,
        ["anthropic-version"] = ANTHROPIC_VERSION,
        ["content-type"] = "application/json",
    })
end

---------------------------------------------------------------------------
-- Core API call
---------------------------------------------------------------------------

--- Send a Messages API request
---@param opts AI.Anthropic.MessagesOpts
---@return AI.Anthropic.Response|nil response
---@return string|nil error
function M:messages(opts)
    opts = opts or {}

    local body = {
        model = opts.model or self.model,
        max_tokens = opts.max_tokens or self.max_tokens,
        messages = assert(opts.messages, "messages is required"),
    }

    if opts.system ~= nil then body.system = opts.system end
    if opts.temperature ~= nil then body.temperature = opts.temperature end
    if opts.top_p ~= nil then body.top_p = opts.top_p end
    if opts.stop_sequences ~= nil then body.stop_sequences = opts.stop_sequences end
    if opts.tools ~= nil then body.tools = opts.tools end
    if opts.tool_choice ~= nil then body.tool_choice = opts.tool_choice end
    if opts.metadata ~= nil then body.metadata = opts.metadata end

    local url = self.base_url:gsub("/+$", "") .. "/v1/messages"
    return utils.json_post(url, body, self:_headers())
end

---------------------------------------------------------------------------
-- Response helpers
---------------------------------------------------------------------------

--- Extract all text content from a response
---@param resp AI.Anthropic.Response
---@return string text joined text content
function M:text_content(resp)
    if not resp or not resp.content then return "" end
    local parts = {}
    for _, block in ipairs(resp.content) do
        if block.type == "text" then
            table.insert(parts, block.text)
        end
    end
    return table.concat(parts, "\n")
end

--- Extract tool_use blocks from response
---@param resp AI.Anthropic.Response
---@return AI.Anthropic.ToolCall[] calls
function M:tool_calls(resp)
    if not resp or not resp.content then return {} end
    local calls = {}
    for _, block in ipairs(resp.content) do
        if block.type == "tool_use" then
            table.insert(calls, {
                id = block.id,
                name = block.name,
                input = block.input,
            })
        end
    end
    return calls
end

--- Check if the response contains tool calls
---@param resp AI.Anthropic.Response
---@return boolean
function M:has_tool_calls(resp)
    return resp and resp.stop_reason == "tool_use"
end

---------------------------------------------------------------------------
-- Tool result builders
---------------------------------------------------------------------------

--- Serialize a value for tool result content
---@param content any
---@return string
local function serialize_content(content)
    if type(content) == "string" then
        return content
    elseif type(content) == "table" then
        return json.encode(content)
    end
    return tostring(content)
end

--- Build a single tool_result content block
---@param tool_use_id string the tool_use block id
---@param content any result content (stringified if not string)
---@param is_error boolean? mark as error
---@return table content_block {type="tool_result", tool_use_id, content, is_error?}
function M:tool_result_block(tool_use_id, content, is_error)
    local block = {
        type = "tool_result",
        tool_use_id = tool_use_id,
        content = serialize_content(content),
    }
    if is_error then
        block.is_error = true
    end
    return block
end

--- Execute all tool calls and return a single user message with all results
---@param resp AI.Anthropic.Response
---@param handler fun(call: AI.Anthropic.ToolCall): any return result for each call
---@return table|nil message {role="user", content={...tool_results}} or nil if no tool calls
function M:execute_tools(resp, handler)
    local calls = self:tool_calls(resp)
    if #calls == 0 then return nil end

    local results = {}
    for _, call in ipairs(calls) do
        local ok, result = pcall(handler, call)
        if ok then
            table.insert(results, self:tool_result_block(call.id, result, false))
        else
            table.insert(results, self:tool_result_block(call.id, "error: " .. tostring(result), true))
        end
    end

    return {
        role = "user",
        content = results,
    }
end

return M
