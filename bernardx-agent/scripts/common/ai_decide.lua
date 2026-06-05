-- BT Script: AI decides next action
-- Uses ai_client, ai_tools, ai_module from blackboard
local bb = require('blackboard')

local M = {}

function M:Enter(args)
    self.step = 0
    self.messages = {}
    local task = bb.get("task") or (args and args.task) or "Complete the task on this page"
    table.insert(self.messages, { role = "user", content = task })
end

function M:Tick()
    self.step = self.step + 1
    local page_info = bb.get("page_info") or "(no page info)"
    local ai_client = bb.get("ai_client")
    local ai_tools = bb.get("ai_tools")
    local ai_mod = bb.get("ai_module")

    if not ai_client then
        print("[ai_decide] ERROR: no AI client")
        return "failure"
    end

    -- Add observation
    local obs = "Step " .. self.step .. " - Page:\n" .. page_info
    table.insert(self.messages, { role = "user", content = obs })

    print("[ai_decide] Step " .. self.step .. ": asking AI...")

    local resp, err = ai_client:messages({
        system = "You are a browser automation agent. Analyze the page and decide the next action.\n"
            .. "Rules:\n"
            .. "- Call 'done' immediately when the task is completed (e.g. form submitted, search performed, checkbox checked).\n"
            .. "- Do NOT repeat actions that have already succeeded.\n"
            .. "- If the page shows a success/completion message, call 'done'.",
        messages = self.messages,
        tools = ai_tools,
        tool_choice = { type = "auto" },
    })

    if err then
        print("[ai_decide] ERROR: " .. tostring(err))
        return "failure"
    end

    table.insert(self.messages, { role = "assistant", content = resp.content })

    if ai_client:has_tool_calls(resp) then
        local calls = ai_client:tool_calls(resp)
        local call = calls[1]

        bb.set("ai_action", call.name)
        bb.set("ai_action_input", call.input)

        print("[ai_decide] " .. call.name .. " " .. (call.input.selector or call.input.text or ""))

        -- Add tool result to conversation
        local tool_msg = ai_client:tool_result_block(call.id, "queued")
        table.insert(self.messages, { role = "user", content = { tool_msg } })

        if call.name == "done" then
            bb.set("task_done", true)
        end
        return "success"
    end

    print("[ai_decide] No tool call, text: " .. (ai_client:text_content(resp):sub(1, 100) or ""))
    return "failure"
end

return M
