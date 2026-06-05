--- OpenAI Chat Completions compatible API client
-- Works with OpenAI, Azure OpenAI, and any /v1/chat/completions compatible proxy
-- @module ai.openai

local json = require('json')
local utils = require('ai.utils')

local M = {}

---------------------------------------------------------------------------
-- Type definitions
---------------------------------------------------------------------------

---@class AI.OpenAI.ToolCall
---@field id string tool call id
---@field name string function name
---@field input table parsed arguments

---@class AI.OpenAI.ChatOpts
---@field messages table[] conversation messages (required)
---@field model? string override default model
---@field max_tokens? integer override default max_tokens
---@field temperature? number
---@field top_p? number
---@field stop? string|string[]
---@field tools? table[] function tool definitions
---@field tool_choice? string|table "auto"|"none"|{type="function",["function"]={name="..."}}
---@field response_format? table {type="json_object"} or {type="json_schema",...}
---@field n? integer number of completions
---@field presence_penalty? number
---@field frequency_penalty? number
---@field seed? integer

---@class AI.OpenAI.Response
---@field id string
---@field object string "chat.completion"
---@field choices {index:integer,message:{role:string,content:string?,tool_calls:table[]?},finish_reason:string}[]
---@field usage {prompt_tokens:integer,completion_tokens:integer,total_tokens:integer}

---------------------------------------------------------------------------
-- Client constructor
---------------------------------------------------------------------------

--- Create a new OpenAI-compatible API client
---@param config AI.ClientConfig
---@return table client
function M.new(config)
    assert(config and config.api_key, "api_key is required")

    local client = {
        api_key = config.api_key,
        base_url = config.base_url or "https://api.openai.com/v1",
        model = config.model or "gpt-4o",
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
        ["Authorization"] = "Bearer " .. self.api_key,
        ["Content-Type"] = "application/json",
    })
end

---------------------------------------------------------------------------
-- Core API call
---------------------------------------------------------------------------

--- Send a Chat Completions request
---@param opts AI.OpenAI.ChatOpts
---@return AI.OpenAI.Response|nil response
---@return string|nil error
function M:chat(opts)
    opts = opts or {}

    local body = {
        model = opts.model or self.model,
        messages = assert(opts.messages, "messages is required"),
    }

    if opts.max_tokens ~= nil then
        body.max_tokens = opts.max_tokens
    elseif self.max_tokens then
        body.max_tokens = self.max_tokens
    end
    if opts.temperature ~= nil then body.temperature = opts.temperature end
    if opts.top_p ~= nil then body.top_p = opts.top_p end
    if opts.stop ~= nil then body.stop = opts.stop end
    if opts.tools ~= nil then body.tools = opts.tools end
    if opts.tool_choice ~= nil then body.tool_choice = opts.tool_choice end
    if opts.response_format ~= nil then body.response_format = opts.response_format end
    if opts.n ~= nil then body.n = opts.n end
    if opts.presence_penalty ~= nil then body.presence_penalty = opts.presence_penalty end
    if opts.frequency_penalty ~= nil then body.frequency_penalty = opts.frequency_penalty end
    if opts.seed ~= nil then body.seed = opts.seed end

    local url = self.base_url:gsub("/+$", "") .. "/chat/completions"
    return utils.json_post(url, body, self:_headers())
end

---------------------------------------------------------------------------
-- Response helpers
---------------------------------------------------------------------------

--- Extract text from first choice
---@param resp AI.OpenAI.Response
---@return string text
function M:text_content(resp)
    if not resp or not resp.choices or #resp.choices == 0 then return "" end
    local msg = resp.choices[1].message
    return msg and msg.content or ""
end

--- Extract tool calls from first choice
---@param resp AI.OpenAI.Response
---@return AI.OpenAI.ToolCall[] calls
function M:tool_calls(resp)
    if not resp or not resp.choices or #resp.choices == 0 then return {} end
    local msg = resp.choices[1].message
    if not msg or not msg.tool_calls then return {} end

    local calls = {}
    for _, tc in ipairs(msg.tool_calls) do
        local input = {}
        local fn = tc["function"]
        if fn and fn.arguments then
            local ok, parsed = pcall(json.decode, fn.arguments)
            if ok then input = parsed end
        end
        table.insert(calls, {
            id = tc.id,
            name = fn and fn.name,
            input = input,
        })
    end
    return calls
end

--- Check if the response contains tool calls
---@param resp AI.OpenAI.Response
---@return boolean
function M:has_tool_calls(resp)
    if not resp or not resp.choices or #resp.choices == 0 then return false end
    return resp.choices[1].finish_reason == "tool_calls"
end

---------------------------------------------------------------------------
-- Tool result builders
---------------------------------------------------------------------------

--- Serialize a value for tool result content
local function serialize_content(content)
    if type(content) == "string" then
        return content
    elseif type(content) == "table" then
        return json.encode(content)
    end
    return tostring(content)
end

--- Build a tool result message (OpenAI format)
---@param tool_call_id string
---@param content any result content (stringified if not string)
---@return table message {role="tool", tool_call_id, content}
function M:tool_result(tool_call_id, content)
    return {
        role = "tool",
        tool_call_id = tool_call_id,
        content = serialize_content(content),
    }
end

--- Execute all tool calls and return an array of tool result messages
---@param resp AI.OpenAI.Response
---@param handler fun(call: AI.OpenAI.ToolCall): any
---@return table[] messages array of {role="tool", ...}
function M:execute_tools(resp, handler)
    local calls = self:tool_calls(resp)
    if #calls == 0 then return {} end

    local results = {}
    for _, call in ipairs(calls) do
        local ok, result = pcall(handler, call)
        if ok then
            table.insert(results, self:tool_result(call.id, result))
        else
            table.insert(results, self:tool_result(call.id, "error: " .. tostring(result)))
        end
    end
    return results
end

return M
