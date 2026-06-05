-- BernardX Agent Entry Point
-- Modes:
--   run     — Execute a behavior tree from a project
--   explore — AI-driven agent loop to complete a task on a web page
local bt = require('bt')
local bb = require('blackboard')
local cdp = require('cdp')
local ai = require('ai')
local harness = require('agent')
local skills = require('agent.skills')
local prompt = require('agent.prompt')
local memory = require('agent.memory')
local agents = require('agent.agents')

---------------------------------------------------------------------------
-- Configuration (all via environment variables, no hardcoded scenarios)
---------------------------------------------------------------------------

local mode = os.getenv("MODE") or "run"
local agent_path = os.getenv("AGENT_PATH") or "/workspaces/example/bernardx-agent"

-- Run mode
local project_path = os.getenv("PROJECT_PATH")
local tree_dir = os.getenv("TREE_DIR")
local task = os.getenv("TASK")

-- Explore mode
local target_url = os.getenv("TARGET_URL")
local output_dir = os.getenv("OUTPUT_DIR") or "/tmp/bt_project"

-- Shared
local playground_url = os.getenv("PLAYGROUND_URL")
local cdp_port = tonumber(os.getenv("CDP_PORT")) or 9222
local max_steps = tonumber(os.getenv("MAX_STEPS")) or 20

---------------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------------

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil, "file not found: " .. path end
    local content = f:read("*a")
    f:close()
    return content
end

---------------------------------------------------------------------------
-- Run mode: execute a behavior tree from a project
---------------------------------------------------------------------------

local function run_mode()
    if not project_path or not tree_dir then
        print("[main] ERROR: run mode requires PROJECT_PATH and TREE_DIR")
        os.exit(1)
    end

    if task then bb.set("task", task) end
    if playground_url then bb.set("playground_url", playground_url) end
    bt.set_project_path(agent_path)

    print("[main] Mode: run")
    print("[main] Project: " .. project_path)
    print("[main] Tree: " .. tree_dir)
    if task then print("[main] Task: " .. task) end

    local tree_path = project_path .. "/trees/" .. tree_dir
    local status = bt.run(tree_path)

    print("\n[main] Tree finished with status: " .. tostring(status))

    local done = bb.get("task_done")
    if done then
        print("[main] RESULT: PASSED")
    else
        print("[main] RESULT: FAILED")
    end
end

---------------------------------------------------------------------------
-- Explore mode: AI-driven agent loop with BT project generation
---------------------------------------------------------------------------

local function merge_tables(t1, t2)
    local result = {}
    for _, v in ipairs(t1) do table.insert(result, v) end
    for _, v in ipairs(t2) do table.insert(result, v) end
    return result
end

local function merge_dispatch(d1, d2)
    local result = {}
    for k, v in pairs(d1) do result[k] = v end
    for k, v in pairs(d2) do result[k] = v end
    return result
end

local function explore_mode()
    if not target_url then
        print("[main] ERROR: explore mode requires TARGET_URL")
        os.exit(1)
    end
    if not task then task = "Explore and complete the task on this page" end

    local base_url = os.getenv("ANTHROPIC_BASE_URL") or "https://api.anthropic.com"
    local api_key = os.getenv("ANTHROPIC_AUTH_TOKEN")
    local model = os.getenv("ANTHROPIC_DEFAULT_SONNET_MODEL") or "claude-sonnet-4-20250514"
    local fallback_model = os.getenv("ANTHROPIC_FALLBACK_MODEL")

    if not api_key then
        print("[main] ERROR: ANTHROPIC_AUTH_TOKEN not set")
        os.exit(1)
    end

    print("[main] Mode: explore")
    print("[main] Target: " .. target_url)
    print("[main] Task: " .. task)
    print("[main] Output: " .. output_dir)

    -- 1. Initialize CDP
    print("[main] Connecting to Chrome on port " .. cdp_port)
    local client = cdp.new({ port = cdp_port })
    local targets, err = client:list_targets()
    if err then
        print("[main] ERROR: CDP connection failed: " .. tostring(err))
        os.exit(1)
    end

    local ok, err = client:connect()
    if not ok then
        print("[main] ERROR: " .. tostring(err))
        os.exit(1)
    end
    client:enable("Page")
    client:enable("Runtime")

    print("[main] Navigating to " .. target_url)
    client:navigate(target_url)
    sleep(2000)

    -- 2. Initialize AI client
    local ai_client = ai.anthropic({
        api_key = api_key,
        base_url = base_url,
        model = model,
        max_tokens = 1024,
    })

    -- 3. Load skills, memory, and sub-agents
    local skills_dir = agent_path .. "/skills"
    local skill_registry = skills.scan(skills_dir)
    local skill_catalog = skills.catalog(skill_registry)
    print("[main] Skills: " .. skill_catalog)

    local agents_dir = agent_path .. "/agents"
    local agent_registry = agents.scan(agents_dir)
    local agent_catalog = agents.catalog(agent_registry)
    local agent_names = agents.names(agent_registry)
    print("[main] Sub-agents: " .. table.concat(agent_names, ", "))

    local memory_dir = output_dir .. "/.memory"
    local memory_registry = memory.scan(memory_dir)
    local memory_index = memory.index_text(memory_dir, memory_registry)
    if memory_index ~= "" then
        print("[main] Memory: " .. memory_index)
    end

    -- 4. Build tools and dispatch (CDP + Skills — no BT tools for main agent)
    local cdp_t = harness.cdp_tools(ai)
    local sk_t = harness.skill_tools(ai)
    local all_tools = merge_tables(cdp_t, sk_t)

    local cdp_d = harness.cdp_dispatch(client)
    local sk_d = harness.skill_dispatch(skill_registry, skills_dir, {
        ai_client = ai_client,
        ai = ai,
        client = client,
        memory_dir = memory_dir,
        output_dir = output_dir,
        agent_path = agent_path,
    }, agent_registry)
    local all_dispatch = merge_dispatch(cdp_d, sk_d)

    -- 5. Build system prompt with sections
    prompt.section("identity",
        "You are a browser automation agent. Use observe to understand the page, "
        .. "then interact with click/type/check/select.")
    prompt.section("instructions",
        "Complete the task on the page, then delegate tree generation to a sub-agent.\n\n"
        .. "Phase 1 — Complete the task:\n"
        .. "1. observe the page to find elements and their CSS selectors\n"
        .. "2. Interact using click/type/check/select to complete the task\n"
        .. "3. If the task specifies exact text (e.g. 'wireless headphones'), you MUST type that exact text\n\n"
        .. "Phase 2 — Delegate tree generation:\n"
        .. "After completing the task, call the task tool with agent='tree-generator' and a description of:\n"
        .. "- The task goal\n"
        .. "- EVERY action you took with EXACT selectors and text values\n"
        .. "The tree-generator sub-agent will observe the page and generate the deterministic tree.\n\n"
        .. "Call done when finished.")
    if #agent_names > 0 then
        prompt.section("agents",
            "Available sub-agents (use with task tool, e.g. task(agent='tree-generator', description='...')):\n"
            .. agent_catalog)
    end
    prompt.section("skills",
        "Available skills (use load_skill to get full content):\n" .. skill_catalog)
    if memory_index ~= "" then
        prompt.section("memory", "Stored memories (use remember to save new ones):\n" .. memory_index)
    end
    local system = prompt.assemble()

    local messages = {{ role = "user", content = task }}

    print("[main] Starting agent loop (max " .. max_steps .. " steps)")
    local _, done = harness.run(ai_client, messages, system, all_tools, all_dispatch, max_steps, {
        fallback_model = fallback_model,
    })

    -- 5. Cleanup
    client:close()

    print("\n[main] Agent loop finished")
    if done then
        print("[main] RESULT: PASSED")
    else
        print("[main] RESULT: FAILED")
    end
    print("[main] Output: " .. output_dir)
end

---------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------

print("[main] BernardX Agent starting...")
print("[main] Mode: " .. mode)

if mode == "run" then
    run_mode()
elseif mode == "explore" then
    explore_mode()
else
    print("[main] ERROR: unknown mode '" .. mode .. "'")
    os.exit(1)
end
