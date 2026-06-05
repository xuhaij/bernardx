-- BT Script: Initialize CDP + AI, navigate, store in blackboard
local cdp = require('cdp')
local ai = require('ai')
local bb = require('blackboard')

local M = {}

function M:Enter(args)
    local playground_url = os.getenv("PLAYGROUND_URL") or "http://localhost:3000"
    local scenario_id = os.getenv("SCENARIO_ID") or "l1-click-button"
    self.url = args and args.url or (playground_url .. "/scenarios/" .. scenario_id)
    self.port = args and args.port or 9222
    self.need_ai = true
    if args and args.ai ~= nil then self.need_ai = args.ai end
end

function M:Tick()
    -- Create CDP client
    local client = cdp.new({ port = self.port })
    local targets, err = client:list_targets()
    if err then
        print("[init] CDP error: " .. tostring(err))
        return "failure"
    end

    local ok, err = client:connect()
    if not ok then
        print("[init] Connect error: " .. tostring(err))
        return "failure"
    end
    client:enable("Page")
    client:enable("Runtime")

    -- Navigate and wait for load
    print("[init] Navigating to " .. self.url)
    client:navigate(self.url)
    sleep(2000)

    -- Verify we're on the right page
    local title = client:title()
    print("[init] Page title: " .. tostring(title))
    if not title then
        print("[init] Waiting for page load...")
        sleep(1500)
    end

    -- Create AI client (optional — skipped for deterministic trees)
    if self.need_ai then
        local base_url = os.getenv("ANTHROPIC_BASE_URL") or "https://api.anthropic.com"
        local api_key = os.getenv("ANTHROPIC_AUTH_TOKEN")
        local model = os.getenv("ANTHROPIC_DEFAULT_SONNET_MODEL") or "claude-sonnet-4-20250514"

        if not api_key then
            print("[init] ERROR: ANTHROPIC_AUTH_TOKEN not set")
            return "failure"
        end

        local ai_client = ai.anthropic({
            api_key = api_key,
            base_url = base_url,
            model = model,
            max_tokens = 1024,
        })

        local ai_tools = {
            ai.tool({
                name = "click",
                description = "Click an element by CSS selector",
                input_schema = ai.schema(
                    { selector = ai.string_prop("CSS selector") },
                    { "selector" }
                ),
            }),
            ai.tool({
                name = "type",
                description = "Type text into an input field",
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
                description = "Check a checkbox by CSS selector",
                input_schema = ai.schema(
                    { selector = ai.string_prop("CSS selector of the checkbox") },
                    { "selector" }
                ),
            }),
            ai.tool({
                name = "done",
                description = "Task is complete",
                input_schema = ai.schema({}, {}),
            }),
        }

        bb.set("ai_client", ai_client)
        bb.set("ai_tools", ai_tools)
        bb.set("ai_module", ai)
    end

    -- Store everything in blackboard
    bb.set("cdp_client", client)

    -- Restore task from env (blackboard is cleared by bt.run)
    local env_task = os.getenv("TASK")
    if env_task then
        bb.set("task", env_task)
    end

    -- Store scenario ID for verify
    local env_scenario = os.getenv("SCENARIO_ID")
    if env_scenario then
        bb.set("scenario_id", env_scenario)
    end

    local env_playground = os.getenv("PLAYGROUND_URL")
    if env_playground then
        bb.set("playground_url", env_playground)
    end

    print("[init] CDP ready" .. (self.need_ai and " + AI" or " (deterministic)"))
    return "success"
end

function M:Exit() end

return M
