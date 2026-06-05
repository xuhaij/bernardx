-- BT Script: Observe page state via CDP
-- Uses cdp_client from blackboard (set by main.lua)
local bb = require('blackboard')

local M = {}

function M:Enter(args) end

function M:Tick()
    local client = bb.get("cdp_client")
    if not client then
        print("[observe] ERROR: no CDP client")
        return "failure"
    end

    -- JS returns pre-formatted text (no json dependency needed)
    local js = [[
    (function() {
        var lines = [];
        lines.push("Page: " + document.title);
        lines.push("URL: " + window.location.href);
        var texts = document.querySelectorAll('h1, h2, h3, p, label, [role="heading"]');
        var contentParts = [];
        texts.forEach(function(el) {
            var t = (el.textContent || '').trim();
            if (t && t.length > 0 && t.length < 200) contentParts.push(t);
        });
        if (contentParts.length > 0) {
            lines.push("Content:");
            contentParts.forEach(function(t) { lines.push("  " + t); });
        }
        lines.push("Elements:");
        var els = document.querySelectorAll('button, input, select, textarea, a[href], [role="button"]');
        var idx = 0;
        els.forEach(function(el) {
            if (el.offsetParent === null) return;
            idx++;
            var d = idx + ". " + el.tagName.toLowerCase();
            if (el.type) d += "[" + el.type + "]";
            if (el.textContent && el.textContent.trim()) d += ' "' + el.textContent.trim().substring(0, 80) + '"';
            if (el.placeholder) d += ' ph="' + el.placeholder + '"';
            if (el.value && el.tagName !== 'BUTTON') d += ' val="' + el.value + '"';
            var sel = el.id ? '#' + el.id : (el.name ? el.tagName.toLowerCase() + '[name="' + el.name + '"]' : '');
            if (sel) d += " -> " + sel;
            lines.push("  " + d);
        });
        return lines.join("\n");
    })()
    ]]

    local resp = client:evaluate(js)
    if not resp or not resp.result or not resp.result.result
        or not resp.result.result.value then
        print("[observe] ERROR: failed to extract DOM")
        return "failure"
    end

    local page_text = resp.result.result.value
    bb.set("page_info", page_text)
    print("[observe] " .. (string.match(page_text, "Page: ([^\n]+)") or "?"))
    return "success"
end

return M
