-- DOM extraction helper: get interactive elements as structured text
-- Returns a concise text representation of the page UI for AI consumption
local json = require('json')

local M = {}

--- Extract page DOM info as structured text for AI
---@param client table CDP client
---@return string|nil text  structured page description
function M.extract_page_info(client)
    local js = [[
    (function() {
        var result = {
            title: document.title,
            url: window.location.href,
            elements: []
        };

        // Get all interactive elements
        var interactives = document.querySelectorAll(
            'button, input, select, textarea, a[href], [role="button"], [role="link"], [role="tab"], [onclick]'
        );

        interactives.forEach(function(el) {
            var entry = {
                tag: el.tagName.toLowerCase(),
                selector: '',
                text: (el.textContent || '').trim().substring(0, 100),
                type: el.type || '',
                placeholder: el.placeholder || '',
                value: el.value || '',
                disabled: el.disabled || false,
                visible: el.offsetParent !== null
            };

            // Build a simple selector
            if (el.id) {
                entry.selector = '#' + el.id;
            } else if (el.name) {
                entry.selector = el.tagName.toLowerCase() + '[name="' + el.name + '"]';
            } else {
                // Try to build a path
                var parts = [];
                var cur = el;
                for (var i = 0; i < 3 && cur && cur !== document.body; i++) {
                    var part = cur.tagName.toLowerCase();
                    if (cur.id) { part += '#' + cur.id; break; }
                    var siblings = cur.parentElement ? cur.parentElement.children : [];
                    var idx = 0;
                    for (var j = 0; j < siblings.length; j++) {
                        if (siblings[j] === cur) { idx = j + 1; break; }
                    }
                    part += ':nth-child(' + idx + ')';
                    parts.unshift(part);
                    cur = cur.parentElement;
                }
                entry.selector = parts.join(' > ');
            }

            if (entry.visible) {
                result.elements.push(entry);
            }
        });

        // Get visible text content (limited to key areas)
        var textNodes = document.querySelectorAll('h1, h2, h3, p, label, legend, .card, [role="heading"]');
        result.texts = [];
        textNodes.forEach(function(el) {
            var t = (el.textContent || '').trim();
            if (t && t.length > 0 && t.length < 200) {
                result.texts.push(t);
            }
        });

        return JSON.stringify(result);
    })()
    ]]

    local resp = client:evaluate(js)
    if not resp or not resp.result or not resp.result.result
        or not resp.result.result.value then
        return nil, "Failed to extract DOM info"
    end

    local raw = resp.result.result.value
    local ok, data = pcall(json.decode, raw)
    if not ok then
        return nil, "JSON parse error: " .. tostring(data)
    end

    -- Format as readable text for AI
    local lines = {}
    table.insert(lines, "Page: " .. tostring(data.title))
    table.insert(lines, "URL: " .. tostring(data.url))
    table.insert(lines, "")

    if data.texts and #data.texts > 0 then
        table.insert(lines, "Page content:")
        for _, t in ipairs(data.texts) do
            table.insert(lines, "  " .. t)
        end
        table.insert(lines, "")
    end

    table.insert(lines, "Interactive elements:")
    for i, el in ipairs(data.elements) do
        local parts = { i .. "." }
        table.insert(parts, el.tag)
        if el.type and el.type ~= '' then table.insert(parts, "[" .. el.type .. "]") end
        if el.text and el.text ~= '' then table.insert(parts, '"' .. el.text .. '"') end
        if el.placeholder and el.placeholder ~= '' then table.insert(parts, 'placeholder="' .. el.placeholder .. '"') end
        if el.value and el.value ~= '' and el.tag ~= 'button' then table.insert(parts, 'value="' .. el.value .. '"') end
        if el.disabled then table.insert(parts, '(disabled)') end
        table.insert(parts, '-> ' .. el.selector)
        table.insert(lines, "  " .. table.concat(parts, " "))
    end

    return table.concat(lines, "\n"), data
end

return M
