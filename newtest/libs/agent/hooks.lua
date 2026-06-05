--- Hook system: extensible event-driven architecture
-- @module hooks
--
-- Events:
--   PreToolUse(call)         — before tool execution, return string to block
--   PostToolUse(call, output) — after tool execution
--   Stop(messages)            — when loop exits, return string to force continue
--
-- Usage:
--   local hooks = require('hooks')
--   hooks.register("PreToolUse", function(call)
--       print("[hook] " .. call.name)
--       return nil  -- return string to block execution
--   end)

local M = {}

---------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------

local registry = {
    PreToolUse = {},
    PostToolUse = {},
    Stop = {},
}

--- Register a callback for an event
---@param event string "PreToolUse"|"PostToolUse"|"Stop"
---@param callback function(event-specific args) -> string|nil
function M.register(event, callback)
    if not registry[event] then
        error("unknown hook event: " .. event)
    end
    table.insert(registry[event], callback)
end

--- Remove all callbacks for an event
---@param event string
function M.clear(event)
    if event then
        registry[event] = {}
    else
        registry.PreToolUse = {}
        registry.PostToolUse = {}
        registry.Stop = {}
    end
end

--- Trigger all callbacks for an event
--- Returns first non-nil result (used by PreToolUse to block execution)
---@param event string
---@param ... any event-specific arguments
---@return string|nil block reason if any callback returns non-nil
function M.trigger(event, ...)
    local callbacks = registry[event]
    if not callbacks then return nil end
    for _, cb in ipairs(callbacks) do
        local result = cb(...)
        if result ~= nil then
            return result
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Default hooks
---------------------------------------------------------------------------

--- Log every tool call
local function log_hook(call)
    local args_preview = ""
    if call.input then
        local parts = {}
        for k, v in pairs(call.input) do
            table.insert(parts, k .. "=" .. tostring(v):sub(1, 40))
        end
        args_preview = table.concat(parts, ", ")
    end
    print("[hook] PreToolUse: " .. call.name .. "(" .. args_preview .. ")")
    return nil
end

--- Warn on large tool output
local function large_output_hook(call, output)
    if type(output) == "string" and #output > 50000 then
        print("[hook] PostToolUse: large output from " .. call.name .. " (" .. #output .. " chars)")
    end
    return nil
end

--- Print session summary when loop exits
local function summary_hook(messages)
    local tool_count = 0
    for _, msg in ipairs(messages) do
        if msg.role == "user" and type(msg.content) == "table" then
            for _, block in ipairs(msg.content) do
                if type(block) == "table" and block.type == "tool_result" then
                    tool_count = tool_count + 1
                end
            end
        end
    end
    print("[hook] Stop: session used " .. tool_count .. " tool calls across " .. #messages .. " messages")
    return nil
end

-- Register defaults
M.register("PreToolUse", log_hook)
M.register("PostToolUse", large_output_hook)
M.register("Stop", summary_hook)

return M
