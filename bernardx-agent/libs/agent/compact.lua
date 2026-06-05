--- Context compact: four-layer compaction pipeline
-- @module compact
--
-- Pipeline (cheap first, expensive last):
--   L3: tool_result_budget — persist large outputs to disk
--   L1: snip_compact      — trim middle messages when count > threshold
--   L2: micro_compact     — replace old tool_results with placeholders
--   L4: auto_compact      — LLM-powered full summary (1 API call)
--
-- Execution order matches Claude Code source: budget → snip → micro → auto.
-- Emergency: reactive_compact in recovery.lua (on API prompt_too_long error).

local json = require('json')
local util = require('agent.util')

local M = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local SNIP_THRESHOLD = 30
local SNIP_KEEP_HEAD = 3
local MICRO_KEEP_RECENT = 4
local PERSIST_THRESHOLD = 8000
local BUDGET_MAX_BYTES = 100000
local AUTO_COMPACT_THRESHOLD = 120000
local SUMMARY_MAX_TOKENS = 2000

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Estimate serialized size of messages
---@param messages table
---@return integer estimated bytes
local function estimate_size(messages)
    local size = 0
    for _, msg in ipairs(messages) do
        local content = msg.content
        if type(content) == "string" then
            size = size + #content
        elseif type(content) == "table" then
            local ok, encoded = pcall(json.encode, content)
            size = size + (ok and #encoded or 0)
        end
    end
    return size
end

--- Count tool_result blocks in messages
local function collect_tool_results(messages)
    local blocks = {}
    for mi, msg in ipairs(messages) do
        if msg.role == "user" and type(msg.content) == "table" then
            for bi, block in ipairs(msg.content) do
                if type(block) == "table" and block.type == "tool_result" then
                    table.insert(blocks, { mi = mi, bi = bi, block = block })
                end
            end
        end
    end
    return blocks
end

---------------------------------------------------------------------------
-- L1: snip_compact — trim middle messages
---------------------------------------------------------------------------

--- Trim middle messages when count exceeds threshold
--- Keeps head (first N) and tail (rest), inserts a placeholder in between
---@param messages table conversation messages
---@param max_messages? integer threshold (default 30)
---@return table messages (modified in place)
function M.snip_compact(messages, max_messages)
    max_messages = max_messages or SNIP_THRESHOLD
    if #messages <= max_messages then return messages end

    local tail_count = max_messages - SNIP_KEEP_HEAD
    local snipped = #messages - SNIP_KEEP_HEAD - tail_count

    -- Build new message list: head + placeholder + tail
    local result = {}
    for i = 1, SNIP_KEEP_HEAD do
        table.insert(result, messages[i])
    end
    table.insert(result, {
        role = "user",
        content = "[snipped " .. snipped .. " middle messages to save context space]",
    })
    for i = #messages - tail_count + 1, #messages do
        table.insert(result, messages[i])
    end

    -- Replace in place
    for i = 1, #messages do messages[i] = nil end
    for i, m in ipairs(result) do messages[i] = m end
    return messages
end

---------------------------------------------------------------------------
-- L2: micro_compact — replace old tool_result content with placeholders
---------------------------------------------------------------------------

--- Replace old tool_result content with placeholders, keeping recent ones intact
---@param messages table conversation messages
---@param keep_recent? integer number of recent tool_results to keep (default 4)
---@return table messages (modified in place)
function M.micro_compact(messages, keep_recent)
    keep_recent = keep_recent or MICRO_KEEP_RECENT
    local tool_results = collect_tool_results(messages)

    if #tool_results <= keep_recent then return messages end

    for i = 1, #tool_results - keep_recent do
        local entry = tool_results[i]
        local content = entry.block.content
        if type(content) == "string" and #content > 120 then
            entry.block.content = "[Earlier tool result compacted. Re-run tool if needed.]"
        end
    end

    return messages
end

---------------------------------------------------------------------------
-- L3: tool_result_budget — persist large outputs to disk
---------------------------------------------------------------------------

--- Persist large tool output to disk and replace with preview
---@param output_dir string directory for persisted outputs
---@param tool_use_id string tool call ID
---@param content string output content
---@return string content (possibly replaced with preview)
local function persist_large_output(output_dir, tool_use_id, content)
    if type(content) ~= "string" or #content <= PERSIST_THRESHOLD then
        return content
    end

    local dir = output_dir .. "/tool-results"
    util.mkdir_p(dir)
    local path = dir .. "/" .. (tool_use_id or "unknown") .. ".txt"

    local f = io.open(path, "w")
    if f then
        f:write(content)
        f:close()
    end

    local preview = content:sub(1, 2000)
    return "<persisted-output>\nFull output saved to: " .. path
        .. "\nPreview:\n" .. preview .. "\n</persisted-output>"
end

--- Persist large tool results in the last message to disk
---@param messages table conversation messages
---@param output_dir? string directory for persisted files (default "/tmp/bt_tool_results")
---@return table messages (modified in place)
function M.tool_result_budget(messages, output_dir)
    output_dir = output_dir or "/tmp/bt_tool_results"
    if #messages == 0 then return messages end

    local last = messages[#messages]
    if last.role ~= "user" or type(last.content) ~= "table" then
        return messages
    end

    -- Check total size of tool results in last message
    local blocks = {}
    local total = 0
    for i, block in ipairs(last.content) do
        if type(block) == "table" and block.type == "tool_result" then
            local content = block.content or ""
            if type(content) ~= "string" then
                local ok, encoded = pcall(json.encode, content)
                content = ok and encoded or tostring(content)
            end
            table.insert(blocks, { i = i, block = block, size = #content })
            total = total + #content
        end
    end

    if total <= BUDGET_MAX_BYTES then return messages end

    -- Sort by size, largest first, persist until under budget
    table.sort(blocks, function(a, b) return a.size > b.size end)

    for _, entry in ipairs(blocks) do
        if total <= BUDGET_MAX_BYTES then break end
        if entry.size <= PERSIST_THRESHOLD then goto continue end

        local content = entry.block.content
        if type(content) ~= "string" then
            local ok, encoded = pcall(json.encode, content)
            content = ok and encoded or tostring(content)
        end

        local new_content = persist_large_output(
            output_dir, entry.block.tool_use_id, content)
        local saved = entry.size - #new_content
        total = total - saved
        entry.block.content = new_content

        ::continue::
    end

    return messages
end

---------------------------------------------------------------------------
-- L4: auto_compact — LLM-powered full summary
---------------------------------------------------------------------------

--- Use LLM to summarize conversation history
---@param messages table conversation messages
---@param ai_client table Anthropic client
---@return string summary
function M.summarize(messages, ai_client)
    local conversation = {}
    for _, msg in ipairs(messages) do
        local content = msg.content
        if type(content) == "string" then
            table.insert(conversation, msg.role .. ": " .. content:sub(1, 2000))
        elseif type(content) == "table" then
            local parts = {}
            for _, block in ipairs(content) do
                if block.type == "text" then
                    table.insert(parts, block.text:sub(1, 500))
                elseif block.type == "tool_use" then
                    table.insert(parts, "[tool: " .. block.name .. "]")
                elseif block.type == "tool_result" then
                    local c = block.content or ""
                    if type(c) == "string" and #c > 300 then
                        c = c:sub(1, 300) .. "..."
                    end
                    table.insert(parts, "[result: " .. c .. "]")
                end
            end
            table.insert(conversation, msg.role .. ": " .. table.concat(parts, " | "))
        end
    end

    local history_text = table.concat(conversation, "\n")
    if #history_text > 60000 then
        history_text = history_text:sub(1, 60000) .. "\n[...truncated...]"
    end

    local prompt = "Summarize this browser-automation-agent conversation so work can continue.\n"
        .. "Preserve: 1. current goal 2. key findings/decisions 3. actions taken "
        .. "4. remaining work 5. page state. Be compact but concrete.\n\n"
        .. history_text

    local resp, err = ai_client:messages({
        messages = {{ role = "user", content = prompt }},
        max_tokens = SUMMARY_MAX_TOKENS,
    })

    if err or not resp then
        return "[Summary failed: " .. tostring(err) .. "]"
    end

    local parts = {}
    if resp.content then
        for _, block in ipairs(resp.content) do
            if block.type == "text" then
                table.insert(parts, block.text)
            end
        end
    end
    return #parts > 0 and table.concat(parts, "\n") or "(empty summary)"
end

--- Compact entire history into a summary message
---@param messages table conversation messages (replaced in place)
---@param ai_client table Anthropic client
---@return table messages (modified in place)
function M.auto_compact(messages, ai_client)
    local summary = M.summarize(messages, ai_client)
    print("[compact] Auto-compact: summarized " .. #messages .. " messages")

    local result = {
        { role = "user", content = "[Auto-compacted conversation]\n\n" .. summary },
    }

    for i = 1, #messages do messages[i] = nil end
    for i, m in ipairs(result) do messages[i] = m end
    return messages
end

---------------------------------------------------------------------------
-- Pipeline: run all layers (L3 → L1 → L2 → L4)
---------------------------------------------------------------------------

--- Run the full compaction pipeline on messages
---@param messages table conversation messages (modified in place)
---@param opts? table {output_dir, ai_client, max_messages, keep_recent}
function M.pipeline(messages, opts)
    opts = opts or {}

    -- L3: persist large outputs first (zero API cost)
    M.tool_result_budget(messages, opts.output_dir)

    -- L1: trim middle messages (zero API cost)
    M.snip_compact(messages, opts.max_messages)

    -- L2: replace old tool results (zero API cost)
    M.micro_compact(messages, opts.keep_recent)

    -- L4: if still over threshold, use LLM summary (1 API call)
    if opts.ai_client and estimate_size(messages) > (opts.threshold or AUTO_COMPACT_THRESHOLD) then
        print("[compact] Size over threshold, running auto-compact")
        M.auto_compact(messages, opts.ai_client)
    end
end

---------------------------------------------------------------------------
-- Constants export (for testing/configuration)
---------------------------------------------------------------------------

M.SNIP_THRESHOLD = SNIP_THRESHOLD
M.MICRO_KEEP_RECENT = MICRO_KEEP_RECENT
M.PERSIST_THRESHOLD = PERSIST_THRESHOLD
M.AUTO_COMPACT_THRESHOLD = AUTO_COMPACT_THRESHOLD

return M
