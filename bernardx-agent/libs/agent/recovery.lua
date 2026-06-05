--- Error recovery: retry, backoff, model fallback, token escalation, reactive compact
-- @module recovery
--
-- Patterns from learn-claude-code s11:
--   Path 1: Output truncated (max_tokens) → escalate tokens → continuation prompt
--   Path 2: Context overflow (prompt_too_long) → reactive compact → retry
--   Path 3: Transient failures (429/529/network) → exponential backoff → fallback model

local M = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local DEFAULT_MAX_RETRIES = 5
local BASE_DELAY_MS = 500
local MAX_DELAY_MS = 32000
local ESCALATED_MAX_TOKENS = 8192
local MAX_CONTINUATIONS = 3
local MAX_CONSECUTIVE_OVERLOADED = 3
local COMPACT_KEEP_TAIL = 5

---------------------------------------------------------------------------
-- Recovery state
---------------------------------------------------------------------------

--- Create a new recovery state tracker
---@param opts? table optional config
---@return table state
function M.new_state(opts)
    opts = opts or {}
    return {
        has_escalated = false,
        continuation_count = 0,
        consecutive_overloaded = 0,
        has_attempted_compact = false,
        current_model = opts.model,
        fallback_model = opts.fallback_model,
    }
end

---------------------------------------------------------------------------
-- Exponential backoff with jitter
---------------------------------------------------------------------------

--- Calculate retry delay in milliseconds
---@param attempt integer 0-based attempt number
---@param retry_after? number server-suggested delay in seconds
---@return number delay in milliseconds
function M.retry_delay(attempt, retry_after)
    if retry_after and retry_after > 0 then
        return retry_after * 1000
    end
    local base = math.min(BASE_DELAY_MS * (2 ^ attempt), MAX_DELAY_MS)
    local jitter = math.random() * base * 0.25
    return base + jitter
end

---------------------------------------------------------------------------
-- Error classification
---------------------------------------------------------------------------

--- Check if an error is transient (retryable)
---@param err string error message
---@return boolean
function M.is_transient_error(err)
    if not err then return false end
    -- HTTP 429 (rate limit) or 529 (overloaded)
    if err:match("api error %(429%)") or err:match("api error %(529%)") then
        return true
    end
    -- Network-level errors
    if err:match("http error:") or err:match("empty response") or err:match("connection") then
        return true
    end
    return false
end

--- Check if an error indicates context overflow
---@param err string error message
---@return boolean
function M.is_context_overflow(err)
    if not err then return false end
    return err:match("prompt_too_long") or err:match("too many tokens") or err:match("context.window") or false
end

--- Extract retry-after from error if available
---@param err string error message
---@return number|nil seconds
function M.extract_retry_after(err)
    if not err then return nil end
    local secs = err:match("retry.-(%d+%.?%d*)%s*s")
    if secs then return tonumber(secs) end
    local ms = err:match("retry.-(%d+)%s*ms")
    if ms then return tonumber(ms) / 1000 end
    return nil
end

---------------------------------------------------------------------------
-- Reactive compact (emergency fallback — no API call)
-- Used only when compact module is not available.
-- The harness.run() uses compact.auto_compact (LLM summary) instead.
---------------------------------------------------------------------------

--- Emergency compact: keep only recent messages (no API call)
---@param messages table conversation messages
---@param keep? integer number of recent messages to keep (default 5)
---@return table compacted messages
function M.reactive_compact(messages, keep)
    keep = keep or COMPACT_KEEP_TAIL
    if #messages <= keep then return messages end

    local trimmed = #messages - keep
    local summary_note = {
        role = "user",
        content = "[Context compacted: " .. trimmed .. " earlier messages removed. Continue the task.]",
    }
    local tail = {}
    for i = #messages - keep + 1, #messages do
        table.insert(tail, messages[i])
    end
    return { summary_note, table.unpack(tail) }
end

---------------------------------------------------------------------------
-- with_retry: wrap an API call with full error recovery
---------------------------------------------------------------------------

--- Execute fn with retry, backoff, model fallback, and recovery
---@param fn function the API call (receives {model=..., max_tokens=...} override)
---@param state table recovery state from new_state()
---@param config? table {max_retries=..., on_retry=...}
---@return table|nil response
---@return string|nil error
function M.with_retry(fn, state, config)
    config = config or {}
    local max_retries = config.max_retries or DEFAULT_MAX_RETRIES
    local on_retry = config.on_retry -- optional callback(step, delay, reason)

    for attempt = 1, max_retries do
        local resp, err = fn({
            model = state.current_model,
        })

        -- Success
        if resp then
            state.consecutive_overloaded = 0
            return resp, nil
        end

        -- Path 2: Context overflow → reactive compact
        if M.is_context_overflow(err) then
            if not state.has_attempted_compact then
                print("[recovery] Context overflow, attempting reactive compact")
                state.has_attempted_compact = true
                -- Signal caller to compact and retry
                return nil, "NEEDS_COMPACT"
            end
            -- Already compacted, give up
            return nil, "context overflow after compact: " .. (err or "")
        end

        -- Path 3: Transient errors → backoff + fallback
        if M.is_transient_error(err) then
            if err:match("api error %(529%)") then
                state.consecutive_overloaded = state.consecutive_overloaded + 1
            end

            -- Model fallback after consecutive overloaded errors
            if state.consecutive_overloaded >= MAX_CONSECUTIVE_OVERLOADED
                and state.fallback_model
                and state.current_model ~= state.fallback_model then
                print("[recovery] Switching to fallback model: " .. state.fallback_model)
                state.current_model = state.fallback_model
                state.consecutive_overloaded = 0
            end

            local delay = M.retry_delay(attempt - 1, M.extract_retry_after(err))
            local reason = err:match("api error %((%d%d%d)%)") or "transient"
            if on_retry then on_retry(attempt, delay, reason) end
            print("[recovery] Retry " .. attempt .. "/" .. max_retries
                .. " after " .. math.floor(delay) .. "ms (" .. reason .. ")")
            sleep(math.floor(delay))
        else
            -- Non-transient error, don't retry
            return nil, err
        end
    end

    return nil, "max retries exceeded"
end

---------------------------------------------------------------------------
-- Handle max_tokens truncation
---------------------------------------------------------------------------

--- Check if response was truncated and build continuation if needed
---@param resp table AI response
---@param state table recovery state
---@return boolean needs_continuation
---@return string|nil continuation_prompt
function M.handle_truncation(resp, state)
    if not resp or resp.stop_reason ~= "max_tokens" then
        return false
    end

    -- First: escalate max_tokens
    if not state.has_escalated then
        state.has_escalated = true
        print("[recovery] Escalating max_tokens to " .. ESCALATED_MAX_TOKENS)
        return true, nil -- nil = just retry with higher limit
    end

    -- Then: continuation prompts
    if state.continuation_count < MAX_CONTINUATIONS then
        state.continuation_count = state.continuation_count + 1
        print("[recovery] Sending continuation prompt (" .. state.continuation_count .. "/" .. MAX_CONTINUATIONS .. ")")
        return true, "Output was cut off. Resume directly — no recap. Continue from where you left off."
    end

    -- Give up
    print("[recovery] Max continuations (" .. MAX_CONTINUATIONS .. ") exceeded, proceeding with truncated output")
    return false
end

---------------------------------------------------------------------------
-- Constants export (for testing/configuration)
---------------------------------------------------------------------------

M.ESCALATED_MAX_TOKENS = ESCALATED_MAX_TOKENS
M.MAX_CONTINUATIONS = MAX_CONTINUATIONS
M.COMPACT_KEEP_TAIL = COMPACT_KEEP_TAIL

return M
