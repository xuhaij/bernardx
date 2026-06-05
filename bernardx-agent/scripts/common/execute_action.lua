-- BT Script: Execute AI-decided action via CDP
local bb = require('blackboard')

local M = {}

function M:Enter(args) end

function M:Tick()
    local action = bb.get("ai_action")
    local input = bb.get("ai_action_input")
    local client = bb.get("cdp_client")

    if not action or not client then
        print("[execute] ERROR: no action=" .. tostring(action) .. " client=" .. tostring(client ~= nil))
        return "failure"
    end

    if action == "click" then
        print("[execute] focus + click " .. tostring(input.selector))
        client:evaluate(string.format('document.querySelector(%q).focus()', input.selector))
        sleep(100)
        local resp = client:click(input.selector)
        print("[execute] click resp: " .. tostring(resp ~= nil))
        sleep(500)
        return "success"

    elseif action == "type" then
        print("[execute] focus + type '" .. tostring(input.text) .. "' -> " .. tostring(input.selector))
        client:evaluate(string.format('document.querySelector(%q).focus()', input.selector))
        sleep(100)
        client:type_text(input.text)
        sleep(300)
        return "success"

    elseif action == "done" then
        print("[execute] done")
        return "success"

    elseif action == "check" then
        print("[execute] check " .. tostring(input.selector))
        client:evaluate(string.format(
            'var el = document.querySelector(%q); if (el && !el.checked) el.click()',
            input.selector
        ))
        sleep(500)
        return "success"
    end

    print("[execute] Unknown: " .. tostring(action))
    return "failure"
end

return M
