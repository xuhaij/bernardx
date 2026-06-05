-- Test AI module: DOM info -> AI decision -> CDP action
local cdp = require('cdp')
local ai = require('ai')
local json = require('json')
local dom = require('dom_helper')

-- Read AI config from environment
local base_url = os.getenv("ANTHROPIC_BASE_URL") or "https://api.anthropic.com"
local api_key = os.getenv("ANTHROPIC_AUTH_TOKEN")
local model = os.getenv("ANTHROPIC_DEFAULT_SONNET_MODEL") or "claude-sonnet-4-20250514"

if not api_key then
    print("[FAIL] ANTHROPIC_AUTH_TOKEN not set")
    return
end

print("[test] AI config: base_url=" .. base_url .. " model=" .. model)

-- Create AI client
local client_ai = ai.anthropic({
    api_key = api_key,
    base_url = base_url,
    model = model,
    max_tokens = 1024,
})

-- Define tools for the AI
local tools = {
    ai.tool({
        name = "click",
        description = "Click an element on the page by its selector",
        input_schema = ai.schema(
            { selector = ai.string_prop("CSS selector of the element to click") },
            { "selector" }
        ),
    }),
    ai.tool({
        name = "type",
        description = "Type text into an input field. The field must be focused first or provide its selector.",
        input_schema = ai.schema(
            {
                selector = ai.string_prop("CSS selector of the input field"),
                text = ai.string_prop("Text to type"),
            },
            { "selector", "text" }
        ),
    }),
    ai.tool({
        name = "done",
        description = "Mark the task as completed",
        input_schema = ai.schema({}, {}),
    }),
}

-- Connect to Chrome
print("[test] Connecting to Chrome...")
local client_cdp = cdp.new({ port = 9222 })
local targets, err = client_cdp:list_targets()
if err then
    print("[FAIL] " .. tostring(err))
    return
end

local ok, err = client_cdp:connect()
if not ok then
    print("[FAIL] " .. tostring(err))
    return
end
client_cdp:enable("Page")

-- Navigate to test page
print("[test] Navigating to http://localhost:3000 ...")
client_cdp:navigate("http://localhost:3000")
sleep(1500)

-- Define the task
local task = 'On this page, type "Bernard" into the name input field and click the Submit button.'

print("[test] Task: " .. task)
print("")

-- Agent loop: observe -> decide -> act -> repeat
local messages = {
    { role = "user", content = task },
}

local max_steps = 5
for step = 1, max_steps do
    print("=== Step " .. step .. " ===")

    -- Extract DOM info
    local page_text, page_data = dom.extract_page_info(client_cdp)
    if not page_text then
        print("[FAIL] Could not extract DOM info")
        break
    end
    print("[observe] Page info:\n" .. page_text)
    print("")

    -- Ask AI for next action
    local user_msg = "Current page state:\n\n" .. page_text
    table.insert(messages, { role = "user", content = user_msg })

    print("[think] Asking AI for next action...")
    local resp, err = client_ai:messages({
        system = "You are a browser automation agent. Analyze the page state and decide the next action to complete the task. Use the provided tools to interact with the page. When the task is complete, call 'done'.",
        messages = messages,
        tools = tools,
        tool_choice = { type = "auto" },
    })

    if err then
        print("[FAIL] AI error: " .. tostring(err))
        break
    end

    -- Add assistant response to conversation
    table.insert(messages, { role = "assistant", content = resp.content })

    -- Check if AI wants to use tools
    if client_ai:has_tool_calls(resp) then
        local calls = client_ai:tool_calls(resp)
        print("[decide] AI wants to use tool: " .. calls[1].name)

        -- Execute tool calls
        local tool_results = {}
        for _, call in ipairs(calls) do
            print("[act] Executing: " .. call.name .. " " .. json.encode(call.input))

            local result_text = ""
            if call.name == "click" then
                client_cdp:evaluate(
                    string.format('document.querySelector(%q).focus()', call.input.selector)
                )
                sleep(100)
                client_cdp:click(call.input.selector)
                sleep(500)
                result_text = "Clicked " .. call.input.selector

            elseif call.name == "type" then
                -- Focus the element first
                client_cdp:evaluate(
                    string.format('document.querySelector(%q).focus()', call.input.selector)
                )
                sleep(100)
                client_cdp:type_text(call.input.text)
                sleep(300)
                result_text = "Typed '" .. call.input.text .. "' into " .. call.input.selector

            elseif call.name == "done" then
                result_text = "Task marked as done"
                print("[done] AI says task is complete!")
            end

            table.insert(tool_results, client_ai:tool_result_block(call.id, result_text))
        end

        -- Add tool results to conversation
        table.insert(messages, { role = "user", content = tool_results })

        -- Check if done
        for _, call in ipairs(calls) do
            if call.name == "done" then
                -- Verify the result
                print("\n=== Verification ===")
                local result_resp = client_cdp:evaluate(
                    'document.getElementById("result").textContent'
                )
                local result_text = result_resp and result_resp.result
                    and result_resp.result.result and result_resp.result.result.value
                print("[verify] Result text: " .. tostring(result_text))

                local title = client_cdp:title()
                print("[verify] Page title: " .. tostring(title))

                if result_text and string.find(result_text, "Hello, Bernard") then
                    print("\n[PASS] AI successfully completed the task!")
                else
                    print("\n[FAIL] Task not completed correctly")
                end

                client_cdp:close()
                return
            end
        end
    else
        -- AI returned text only
        local text = client_ai:text_content(resp)
        print("[text] AI: " .. text)
        break
    end

    sleep(500)
end

client_cdp:close()
print("\n[DONE] AI test loop finished")
