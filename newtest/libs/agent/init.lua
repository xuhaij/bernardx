--- Agent harness: tool-agnostic agent loop + CDP tool dispatch
-- @module harness
--
-- Core pattern (from learn-claude-code s01/s02):
--   while has_tool_calls:
--       response = AI(messages, tools)
--       execute tools -> append results
--
-- Usage:
--   local harness = require('harness')
--   local ai = require('ai')
--
--   local tools = harness.cdp_tools(ai)
--   local dispatch = harness.cdp_dispatch(client)
--   local messages = {{ role = "user", content = "Click the button" }}
--
--   harness.run(ai_client, messages, tools, dispatch, 20)

local recovery = require('agent.recovery')
local compact = require('agent.compact')
local hooks = require('agent.hooks')
local util = require('agent.util')

local M = {}

---------------------------------------------------------------------------
-- CDP tool definitions (Anthropic format)
---------------------------------------------------------------------------

function M.cdp_tools(ai)
    return {
        ai.tool({
            name = "observe",
            description = "Extract current page state: title, URL, visible text content, and interactive elements with CSS selectors",
            input_schema = ai.schema({}, {}),
        }),
        ai.tool({
            name = "click",
            description = "Click an element by CSS selector",
            input_schema = ai.schema(
                { selector = ai.string_prop("CSS selector of the element to click") },
                { "selector" }
            ),
        }),
        ai.tool({
            name = "type",
            description = "Clear existing text and type into an input field",
            input_schema = ai.schema(
                {
                    selector = ai.string_prop("CSS selector of the input field"),
                    text = ai.string_prop("Text to type"),
                },
                { "selector", "text" }
            ),
        }),
        ai.tool({
            name = "check",
            description = "Check a checkbox by CSS selector (no-op if already checked)",
            input_schema = ai.schema(
                { selector = ai.string_prop("CSS selector of the checkbox") },
                { "selector" }
            ),
        }),
        ai.tool({
            name = "select",
            description = "Select an option in a dropdown by value",
            input_schema = ai.schema(
                {
                    selector = ai.string_prop("CSS selector of the select element"),
                    value = ai.string_prop("Option value to select"),
                },
                { "selector", "value" }
            ),
        }),
        ai.tool({
            name = "navigate",
            description = "Navigate to a URL and wait for page load",
            input_schema = ai.schema(
                { url = ai.string_prop("URL to navigate to") },
                { "url" }
            ),
        }),
        ai.tool({
            name = "scroll",
            description = "Scroll the page by a relative amount",
            input_schema = ai.schema(
                {
                    x = ai.integer_prop("Horizontal scroll pixels (default 0)"),
                    y = ai.integer_prop("Vertical scroll pixels (default 300)"),
                },
                {}
            ),
        }),
        ai.tool({
            name = "wait",
            description = "Wait for a number of milliseconds (use when content may load asynchronously)",
            input_schema = ai.schema(
                { ms = ai.integer_prop("Milliseconds to wait") },
                { "ms" }
            ),
        }),
        ai.tool({
            name = "done",
            description = "Signal that the task is complete",
            input_schema = ai.schema({}, {}),
        }),
    }
end

---------------------------------------------------------------------------
-- BT tools (for explore mode — generate behavior tree projects)
---------------------------------------------------------------------------

function M.bt_tools(ai)
    return {
        ai.tool({
            name = "save_tree",
            description = "Save a behavior tree JSON to the output project directory. The tree must be a valid BT JSON with 'type' and 'name' fields.",
            input_schema = ai.schema(
                {
                    name = ai.string_prop("Tree directory name (e.g. 'l1_click_button')"),
                    json = ai.string_prop("Complete behavior tree JSON string"),
                },
                { "name", "json" }
            ),
        }),
        ai.tool({
            name = "save_script",
            description = "Save a custom Lua script to the output project's scripts directory",
            input_schema = ai.schema(
                {
                    path = ai.string_prop("Script path relative to scripts/ (e.g. 'custom/login.lua')"),
                    code = ai.string_prop("Lua source code"),
                },
                { "path", "code" }
            ),
        }),
        ai.tool({
            name = "list_scripts",
            description = "List available common scripts from the agent's scripts/common/ directory that can be referenced in behavior trees",
            input_schema = ai.schema({}, {}),
        }),
    }
end

---------------------------------------------------------------------------
-- Page observation JS (shared from util)
---------------------------------------------------------------------------

local OBSERVE_JS = util.OBSERVE_JS

---------------------------------------------------------------------------
-- CDP dispatch: tool name -> handler function
---------------------------------------------------------------------------

function M.cdp_dispatch(client)
    return {
        observe = function()
            local resp = client:evaluate(OBSERVE_JS)
            if not resp or not resp.result or not resp.result.result
                or not resp.result.result.value then
                return "ERROR: failed to extract page state"
            end
            return resp.result.result.value
        end,

        click = function(input)
            client:evaluate(string.format(
                'document.querySelector(%q).focus()', input.selector))
            sleep(100)
            client:click(input.selector)
            sleep(500)
            return "clicked " .. input.selector
        end,

        type = function(input)
            client:evaluate(string.format(
                'document.querySelector(%q).focus()', input.selector))
            sleep(100)
            -- Clear existing text first
            client:evaluate(string.format(
                'var el=document.querySelector(%q);el.value=""', input.selector))
            client:type_text(input.text)
            sleep(300)
            return "typed '" .. input.text .. "' into " .. input.selector
        end,

        check = function(input)
            client:evaluate(string.format(
                'var el=document.querySelector(%q);if(el&&!el.checked)el.click()',
                input.selector))
            sleep(500)
            return "checked " .. input.selector
        end,

        select = function(input)
            client:evaluate(string.format(
                'document.querySelector(%q).value=%q;document.querySelector(%q).dispatchEvent(new Event("change"))',
                input.selector, input.value, input.selector))
            sleep(300)
            return "selected '" .. input.value .. "' in " .. input.selector
        end,

        navigate = function(input)
            client:navigate(input.url)
            sleep(2000)
            return "navigated to " .. input.url
        end,

        scroll = function(input)
            local x = input.x or 0
            local y = input.y or 300
            client:evaluate(string.format('window.scrollBy(%d,%d)', x, y))
            sleep(300)
            return "scrolled by " .. x .. "," .. y
        end,

        wait = function(input)
            sleep(input.ms)
            return "waited " .. input.ms .. "ms"
        end,

        done = function()
            return "task_done"
        end,
    }
end

---------------------------------------------------------------------------
-- BT dispatch: tool name -> handler (requires output_dir)
---------------------------------------------------------------------------

function M.bt_dispatch(output_dir, agent_path)
    return {
        save_tree = function(input)
            if not util.is_safe_path(input.name) then
                return "error: invalid tree name (path traversal rejected)"
            end
            local tree_dir = output_dir .. "/trees/" .. input.name
            util.mkdir_p(tree_dir)
            local f = io.open(tree_dir .. "/root.json", "w")
            if not f then return "error: cannot create " .. tree_dir .. "/root.json" end
            f:write(input.json)
            f:close()
            return "saved tree to trees/" .. input.name .. "/root.json"
        end,

        save_script = function(input)
            if not util.is_safe_path(input.path) then
                return "error: invalid script path (path traversal rejected)"
            end
            local dir = output_dir .. "/scripts"
            util.mkdir_p(dir)
            local full_path = dir .. "/" .. input.path
            util.mkdir_p(full_path:match("(.*[/])") or dir)
            local f = io.open(full_path, "w")
            if not f then return "error: cannot create " .. full_path end
            f:write(input.code)
            f:close()
            return "saved script to scripts/" .. input.path
        end,

        list_scripts = function()
            local files = util.listdir(agent_path .. "/scripts/common", "*.lua")
            if #files == 0 then return "(no scripts found)" end
            local lines = {}
            for _, filepath in ipairs(files) do
                local name = filepath:match("([^/]+)%.lua$")
                if name then
                    table.insert(lines, "  - scripts/common/" .. name .. ".lua")
                end
            end
            if #lines == 0 then return "(no scripts found)" end
            return "Available scripts:\n" .. table.concat(lines, "\n")
        end,
    }
end

---------------------------------------------------------------------------
-- Skill tools (load on demand + save new skills)
---------------------------------------------------------------------------

function M.skill_tools(ai)
    return {
        ai.tool({
            name = "load_skill",
            description = "Load a skill's full content by name. Use this to get detailed knowledge before generating behavior trees or writing automation scripts.",
            input_schema = ai.schema(
                { name = ai.string_prop("Skill name to load") },
                { "name" }
            ),
        }),
        ai.tool({
            name = "compact",
            description = "Summarize earlier conversation to free context space. Use when the conversation is getting long or you're losing track of earlier details.",
            input_schema = ai.schema({}, {}),
        }),
        ai.tool({
            name = "task",
            description = "Launch a sub-agent to handle a subtask. Optionally specify an agent name to use a specialized sub-agent. Returns the final conclusion.",
            input_schema = ai.schema(
                {
                    description = ai.string_prop("Description of the subtask for the sub-agent"),
                    agent = ai.string_prop("Optional: name of a specialized sub-agent to use (e.g. 'tree-generator', 'selector-finder')"),
                },
                { "description" }
            ),
        }),
        ai.tool({
            name = "remember",
            description = "Save a memory for future sessions. Use to store user preferences, project facts, or important findings.",
            input_schema = ai.schema(
                {
                    name = ai.string_prop("Short kebab-case identifier (e.g. 'user-pref-dark-mode')"),
                    type = ai.string_prop("Memory type: user, feedback, project, or reference"),
                    description = ai.string_prop("One-line summary for quick lookup"),
                    content = ai.string_prop("Full memory content in markdown"),
                },
                { "name", "type", "description", "content" }
            ),
        }),
    }
end

---------------------------------------------------------------------------
-- Skill dispatch
---------------------------------------------------------------------------

function M.skill_dispatch(skill_registry, skills_dir, subagent_opts, agent_registry)
    local subagent = require('agent.subagent')
    local memory = require('agent.memory')
    return {
        load_skill = function(input)
            local content, err = require('agent.skills').load(skill_registry, input.name)
            if not content then return err end
            return content
        end,
        task = function(input)
            local opts = {}
            for k, v in pairs(subagent_opts or {}) do opts[k] = v end

            -- If an agent name is specified and found, use defined sub-agent
            if input.agent and agent_registry and agent_registry[input.agent] then
                opts.task = input.description
                return subagent.spawn_with_def(opts, agent_registry[input.agent])
            end

            -- Fallback: legacy sub-agent
            opts.task = input.description
            return subagent.spawn(opts)
        end,
        remember = function(input)
            local memory_dir = subagent_opts and subagent_opts.memory_dir
            if not memory_dir then return "error: memory not configured" end
            return memory.save(memory_dir, input.name, input.type, input.description, input.content)
        end,
    }
end

---------------------------------------------------------------------------
-- Agent loop
---------------------------------------------------------------------------

--- Run the agent loop until AI stops calling tools or max_steps reached
---@param ai_client table Anthropic client
---@param messages table conversation messages (mutated in place)
---@param system string system prompt
---@param tools table AI tool definitions
---@param dispatch table tool name -> handler function
---@param max_steps integer max iterations
---@param recovery_opts? table optional config {fallback_model, max_retries, output_dir}
---@return table messages final conversation
---@return boolean done whether task was marked done
function M.run(ai_client, messages, system, tools, dispatch, max_steps, recovery_opts)
    local task_done = false
    recovery_opts = recovery_opts or {}
    local state = recovery.new_state({
        model = ai_client.model,
        fallback_model = recovery_opts.fallback_model,
    })
    local compact_opts = {
        output_dir = recovery_opts.output_dir,
        ai_client = ai_client,
    }

    for step = 1, max_steps do
        local max_tokens = state.has_escalated and recovery.ESCALATED_MAX_TOKENS or ai_client.max_tokens

        -- Proactive compaction: L3 → L1 → L2 → (L4 if needed)
        compact.pipeline(messages, compact_opts)

        local resp, err = recovery.with_retry(function(override)
            return ai_client:messages({
                system = system,
                messages = messages,
                tools = tools,
                tool_choice = { type = "auto" },
                max_tokens = max_tokens,
                model = override.model,
            })
        end, state, {
            max_retries = recovery_opts.max_retries,
            on_retry = function(attempt, delay, reason)
                print("[harness] Step " .. step .. ": retry " .. attempt .. " (" .. reason .. ")")
            end,
        })

        -- Path 2: context overflow → LLM compact and retry this step
        if err == "NEEDS_COMPACT" then
            print("[harness] Step " .. step .. ": reactive compact")
            compact.auto_compact(messages, ai_client)
            step = step - 1
            goto continue
        end

        if err then
            print("[harness] AI error at step " .. step .. ": " .. tostring(err))
            break
        end

        -- Path 1: max_tokens truncation → escalate or continuation
        local needs_cont, cont_prompt = recovery.handle_truncation(resp, state)
        if needs_cont then
            if cont_prompt then
                table.insert(messages, { role = "assistant", content = resp.content })
                table.insert(messages, { role = "user", content = cont_prompt })
            end
            step = step - 1
            goto continue
        end

        table.insert(messages, { role = "assistant", content = resp.content })

        -- Execute tool calls
        local results = {}
        local triggered_compact = false
        local calls = ai_client:tool_calls(resp)
        if not calls then break end
        for _, call in ipairs(calls) do
            -- PreToolUse hook (can block execution)
            local blocked = hooks.trigger("PreToolUse", call)
            if blocked then
                table.insert(results, ai_client:tool_result_block(call.id, blocked, true))
                goto next_call
            end

            -- Handle compact tool specially
            if call.name == "compact" then
                compact.auto_compact(messages, ai_client)
                table.insert(results, ai_client:tool_result_block(call.id,
                    "[Compacted. Conversation history has been summarized.]"))
                triggered_compact = true
                goto next_call
            end

            do
                local handler = dispatch[call.name]
                local output
                if handler then
                    local ok, result = pcall(handler, call.input)
                    if ok then
                        output = result
                    else
                        output = "error: " .. tostring(result)
                    end
                else
                    output = "unknown tool: " .. call.name
                end

                -- PostToolUse hook
                hooks.trigger("PostToolUse", call, output)

                if output == "task_done" then
                    task_done = true
                end

                table.insert(results, ai_client:tool_result_block(call.id, output))
            end

            ::next_call::
        end

        table.insert(messages, { role = "user", content = results })

        -- After compact, end current turn so next step starts with clean context
        if triggered_compact then
            goto continue
        end

        -- Stop hook (when AI is not calling tools)
        if not ai_client:has_tool_calls(resp) then
            local force = hooks.trigger("Stop", messages)
            if force then
                table.insert(messages, { role = "user", content = force })
                goto continue
            end
            break
        end

        ::continue::
    end

    return messages, task_done
end

---------------------------------------------------------------------------
-- Expose hooks for external registration
---------------------------------------------------------------------------

M.hooks = hooks

return M
