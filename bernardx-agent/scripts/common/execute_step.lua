-- BT Script: Deterministic action executor
-- Reads action parameters from args, executes via CDP client. No AI.
--
-- Supported actions (passed via args):
--   { action: "click",    selector: "#btn" }
--   { action: "type",     selector: "#input", text: "hello" }
--   { action: "check",    selector: "#checkbox" }
--   { action: "select",   selector: "#dropdown", value: "opt" }
--   { action: "navigate", url: "http://..." }
--   { action: "wait",     ms: 500 }
--   { action: "evaluate", js: "..." }

local bb = require('blackboard')

local M = {}

function M:Enter(args)
    self.action   = args and args.action   or nil
    self.selector = args and args.selector or nil
    self.text     = args and args.text     or nil
    self.value    = args and args.value    or nil
    self.url      = args and args.url      or nil
    self.ms       = args and args.ms       or nil
    self.js       = args and args.js       or nil
end

function M:Tick()
    local client = bb.get("cdp_client")
    if not client then
        print("[step] ERROR: no CDP client")
        return "failure"
    end

    if not self.action then
        print("[step] ERROR: no action specified")
        return "failure"
    end

    if self.action == "click" then
        if not self.selector then return "failure" end
        client:evaluate(string.format(
            'document.querySelector(%q).focus()', self.selector))
        sleep(100)
        local ok, err = client:click(self.selector)
        if not ok then
            print("[step] click failed: " .. self.selector .. " — " .. tostring(err))
            return "failure"
        end
        sleep(500)

    elseif self.action == "type" then
        if not self.selector or not self.text then return "failure" end
        client:evaluate(string.format(
            'document.querySelector(%q).focus()', self.selector))
        sleep(100)
        client:evaluate(string.format(
            'var el=document.querySelector(%q);if(el)el.value=""', self.selector))
        client:type_text(self.text)
        sleep(300)

    elseif self.action == "check" then
        if not self.selector then return "failure" end
        client:evaluate(string.format(
            'var el=document.querySelector(%q);if(el&&!el.checked)el.click()',
            self.selector))
        sleep(500)

    elseif self.action == "select" then
        if not self.selector or not self.value then return "failure" end
        client:evaluate(string.format(
            'document.querySelector(%q).value=%q;document.querySelector(%q).dispatchEvent(new Event("change"))',
            self.selector, self.value, self.selector))
        sleep(300)

    elseif self.action == "navigate" then
        if not self.url then return "failure" end
        client:navigate(self.url)
        sleep(2000)

    elseif self.action == "wait" then
        sleep(self.ms or 500)

    elseif self.action == "evaluate" then
        if not self.js then return "failure" end
        client:evaluate(self.js)
        sleep(300)

    else
        print("[step] ERROR: unknown action '" .. tostring(self.action) .. "'")
        return "failure"
    end

    return "success"
end

function M:Exit() end

return M
