--- Subagent: spawn isolated sub-agents with fresh context
-- @module subagent
--
-- Two modes:
-- 1. Legacy: spawn(opts) with default CDP tools
-- 2. Defined: spawn_with_def(opts, agent_def) loads tools from agent definition
--
-- Sub-agents get a fresh messages[] array and limited tool set.
-- Only the final summary is returned to the parent context.

local util = require('agent.util')

local M = {}

local MAX_SUB_TURNS = 10

---------------------------------------------------------------------------
-- Extract text from message content blocks
---------------------------------------------------------------------------

local function extract_text(content)
    if type(content) == "string" then return content end
    if type(content) ~= "table" then return "" end
    local parts = {}
    for _, block in ipairs(content) do
        if type(block) == "text" then
            table.insert(parts, block)
        elseif type(block) == "table" and block.type == "text" then
            table.insert(parts, block.text)
        end
    end
    return table.concat(parts, "\n")
end

---------------------------------------------------------------------------
-- Tool builders: construct tool defs from tool names
---------------------------------------------------------------------------

local function build_tools(ai_mod, tool_names)
    local OBSERVE_JS = util.OBSERVE_JS

    local tool_map = {
        observe = ai_mod.tool({
            name = "observe",
            description = "Extract current page state: title, URL, visible text content, and interactive elements with CSS selectors",
            input_schema = ai_mod.schema({}, {}),
        }),
        click = ai_mod.tool({
            name = "click",
            description = "Click an element by CSS selector",
            input_schema = ai_mod.schema(
                { selector = ai_mod.string_prop("CSS selector of the element to click") },
                { "selector" }
            ),
        }),
        type = ai_mod.tool({
            name = "type",
            description = "Clear existing text and type into an input field",
            input_schema = ai_mod.schema(
                {
                    selector = ai_mod.string_prop("CSS selector of the input field"),
                    text = ai_mod.string_prop("Text to type"),
                },
                { "selector", "text" }
            ),
        }),
        check = ai_mod.tool({
            name = "check",
            description = "Check a checkbox by CSS selector",
            input_schema = ai_mod.schema(
                { selector = ai_mod.string_prop("CSS selector of the checkbox") },
                { "selector" }
            ),
        }),
        select = ai_mod.tool({
            name = "select",
            description = "Select an option in a dropdown by value",
            input_schema = ai_mod.schema(
                {
                    selector = ai_mod.string_prop("CSS selector of the select element"),
                    value = ai_mod.string_prop("Option value to select"),
                },
                { "selector", "value" }
            ),
        }),
        done = ai_mod.tool({
            name = "done",
            description = "Signal that the task is complete",
            input_schema = ai_mod.schema({}, {}),
        }),
    }

    -- BT tools (non-CDP)
    local bt_tools = {
        save_tree = ai_mod.tool({
            name = "save_tree",
            description = "Save a behavior tree JSON to the output project directory",
            input_schema = ai_mod.schema(
                {
                    name = ai_mod.string_prop("Tree directory name"),
                    json = ai_mod.string_prop("Complete behavior tree JSON string"),
                },
                { "name", "json" }
            ),
        }),
        save_script = ai_mod.tool({
            name = "save_script",
            description = "Save a custom Lua script to the output project's scripts directory",
            input_schema = ai_mod.schema(
                {
                    path = ai_mod.string_prop("Script path relative to scripts/"),
                    code = ai_mod.string_prop("Lua source code"),
                },
                { "path", "code" }
            ),
        }),
        list_scripts = ai_mod.tool({
            name = "list_scripts",
            description = "List available common scripts that can be referenced in behavior trees",
            input_schema = ai_mod.schema({}, {}),
        }),
    }

    -- Merge available tools
    for k, v in pairs(bt_tools) do tool_map[k] = v end

    local tools = {}
    for _, name in ipairs(tool_names) do
        if tool_map[name] then
            table.insert(tools, tool_map[name])
        end
    end
    -- Include done only if it's in the requested tools
    for _, name in ipairs(tool_names) do
        if name == "done" and tool_map.done then
            table.insert(tools, tool_map.done)
            break
        end
    end

    return tools
end

---------------------------------------------------------------------------
-- Dispatch builders: construct dispatch table from tool names
---------------------------------------------------------------------------

local function build_dispatch(tool_names, cdp_client, bt_opts)
    local OBSERVE_JS = util.OBSERVE_JS

    local dispatch_map = {}

    -- CDP dispatch
    if cdp_client then
        dispatch_map.observe = function()
            local resp = cdp_client:evaluate(OBSERVE_JS)
            if not resp or not resp.result or not resp.result.result
                or not resp.result.result.value then
                return "ERROR: failed to extract page state"
            end
            return resp.result.result.value
        end
        dispatch_map.click = function(input)
            cdp_client:evaluate(string.format(
                'document.querySelector(%q).focus()', input.selector))
            sleep(100)
            cdp_client:click(input.selector)
            sleep(500)
            return "clicked " .. input.selector
        end
        dispatch_map.type = function(input)
            cdp_client:evaluate(string.format(
                'document.querySelector(%q).focus()', input.selector))
            sleep(100)
            cdp_client:evaluate(string.format(
                'var el=document.querySelector(%q);el.value=""', input.selector))
            cdp_client:type_text(input.text)
            sleep(300)
            return "typed '" .. input.text .. "' into " .. input.selector
        end
        dispatch_map.check = function(input)
            cdp_client:evaluate(string.format(
                'var el=document.querySelector(%q);if(el&&!el.checked)el.click()',
                input.selector))
            sleep(500)
            return "checked " .. input.selector
        end
        dispatch_map.select = function(input)
            cdp_client:evaluate(string.format(
                'document.querySelector(%q).value=%q;document.querySelector(%q).dispatchEvent(new Event("change"))',
                input.selector, input.value, input.selector))
            sleep(300)
            return "selected '" .. input.value .. "' in " .. input.selector
        end
    end

    -- BT dispatch
    if bt_opts then
        dispatch_map.save_tree = function(input)
            if not util.is_safe_path(input.name) then
                return "error: invalid tree name"
            end
            local tree_dir = bt_opts.output_dir .. "/trees/" .. input.name
            util.mkdir_p(tree_dir)
            local f = io.open(tree_dir .. "/root.json", "w")
            if not f then return "error: cannot create file" end
            f:write(input.json)
            f:close()
            return "saved tree to trees/" .. input.name .. "/root.json"
        end
        dispatch_map.save_script = function(input)
            if not util.is_safe_path(input.path) then
                return "error: invalid script path"
            end
            local dir = bt_opts.output_dir .. "/scripts"
            util.mkdir_p(dir)
            local full_path = dir .. "/" .. input.path
            util.mkdir_p(full_path:match("(.*[/])") or dir)
            local f = io.open(full_path, "w")
            if not f then return "error: cannot create file" end
            f:write(input.code)
            f:close()
            return "saved script to scripts/" .. input.path
        end
        dispatch_map.list_scripts = function()
            local files = util.listdir(bt_opts.agent_path .. "/scripts/common", "*.lua")
            if #files == 0 then return "(no scripts found)" end
            local lines = {}
            for _, filepath in ipairs(files) do
                local name = filepath:match("([^/]+)%.lua$")
                if name then
                    table.insert(lines, "  - scripts/common/" .. name .. ".lua")
                end
            end
            return #lines > 0 and ("Available scripts:\n" .. table.concat(lines, "\n")) or "(no scripts found)"
        end
    end

    -- Always map done
    dispatch_map.done = function() return "task_done" end

    -- Build final dispatch from tool names
    local dispatch = {}
    for _, name in ipairs(tool_names) do
        if dispatch_map[name] then dispatch[name] = dispatch_map[name] end
    end
    dispatch.done = dispatch_map.done

    return dispatch
end

---------------------------------------------------------------------------
-- Run the sub-agent loop
---------------------------------------------------------------------------

local function run_loop(ai_client, system, messages, tools, dispatch, max_turns)
    for turn = 1, max_turns do
        local resp, err = ai_client:messages({
            system = system,
            messages = messages,
            tools = tools,
            tool_choice = { type = "auto" },
        })

        if err then
            print("[subagent] Error at turn " .. turn .. ": " .. err)
            break
        end

        table.insert(messages, { role = "assistant", content = resp.content })

        if not ai_client:has_tool_calls(resp) then
            break
        end

        local results = {}
        for _, call in ipairs(ai_client:tool_calls(resp)) do
            print("[subagent] Turn " .. turn .. ": " .. call.name)

            local handler = dispatch[call.name]
            local output
            if handler then
                local ok, result = pcall(handler, call.input)
                output = ok and result or ("error: " .. tostring(result))
            else
                output = "unknown tool: " .. call.name
            end

            if output == "task_done" then
                table.insert(results, ai_client:tool_result_block(call.id, "Subtask completed."))
                table.insert(messages, { role = "user", content = results })
                goto done
            end

            table.insert(results, ai_client:tool_result_block(call.id, output))
        end

        table.insert(messages, { role = "user", content = results })
    end

    ::done::

    -- Extract final text
    if #messages == 0 then
        return "Subagent stopped without producing output."
    end
    local result = extract_text(messages[#messages].content)
    if result == "" then
        for i = #messages, 1, -1 do
            if messages[i].role == "assistant" then
                result = extract_text(messages[i].content)
                if result ~= "" then break end
            end
        end
    end
    if result == "" then
        result = "Subagent stopped after " .. max_turns .. " turns."
    end
    return result
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Spawn a sub-agent using an agent definition
---@param opts table { ai_client, ai, client, output_dir?, agent_path?, task }
---@param agent_def table from agents.scan() — { name, tools, max_turns, prompt }
---@return string result summary
function M.spawn_with_def(opts, agent_def)
    local ai_client = opts.ai_client
    local ai_mod = opts.ai

    print("[subagent] Spawning '" .. agent_def.name .. "' for: " .. (opts.task or ""):sub(1, 80))

    local tool_names = agent_def.tools or { "observe", "done" }
    local include_done = not agent_def.no_done

    if include_done then
        local has_done = false
        for _, n in ipairs(tool_names) do
            if n == "done" then has_done = true; break end
        end
        if not has_done then table.insert(tool_names, "done") end
    end

    local tools = build_tools(ai_mod, tool_names)
    local dispatch = build_dispatch(tool_names, opts.client, (opts.output_dir and opts.agent_path) and {
        output_dir = opts.output_dir,
        agent_path = opts.agent_path,
    } or nil)

    local system = agent_def.prompt
    local messages = {{ role = "user", content = opts.task or "No task specified" }}

    local result = run_loop(ai_client, system, messages, tools, dispatch, agent_def.max_turns or 5)
    print("[subagent] '" .. agent_def.name .. "' done")
    return result
end

--- Legacy: spawn a sub-agent with default CDP tools
---@param opts table { ai_client, ai, client, task }
---@return string summary
function M.spawn(opts)
    local ai_client = opts.ai_client
    local ai_mod = opts.ai
    local cdp_client = opts.client

    print("[subagent] Spawned for: " .. opts.task:sub(1, 80))

    local tool_names = { "observe", "click", "type", "done" }
    local tools = build_tools(ai_mod, tool_names)
    local dispatch = build_dispatch(tool_names, cdp_client, nil)

    local sub_system = "You are a browser automation sub-agent. Complete the specific task you were given, "
        .. "then call done. Provide a concise summary of what you did."

    local messages = {{ role = "user", content = opts.task }}
    local result = run_loop(ai_client, sub_system, messages, tools, dispatch, MAX_SUB_TURNS)
    print("[subagent] Done")
    return result
end

return M
