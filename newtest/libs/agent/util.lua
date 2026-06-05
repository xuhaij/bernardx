--- Shared utilities for agent modules
-- @module agent.util

local lfs = require("lfs")

local M = {}

---------------------------------------------------------------------------
-- Path safety
---------------------------------------------------------------------------

--- Reject paths containing traversal or shell-unsafe characters
---@param path string
---@return boolean safe
function M.is_safe_path(path)
    if not path or path == "" then return false end
    if path:find("%.%.") then return false end
    return true
end

--- Sanitize a name into a safe filename slug
---@param name string
---@return string slug
function M.slugify(name)
    return name:gsub("[^%w%-]", "-")
        :gsub("-+", "-")
        :gsub("^%-", "")
        :gsub("%-$", "")
        :gsub("^%.", "")
        :gsub("%.$", "")
end

---------------------------------------------------------------------------
-- Filesystem (using lfs — C++17 filesystem via fs_library)
---------------------------------------------------------------------------

--- Create directory and all parents
---@param path string
function M.mkdir_p(path)
    path = path:gsub("\\", "/"):gsub("/+$", "")
    if path == "" then return end

    if lfs.attributes(path, "mode") == "directory" then return end

    local segments = {}
    for seg in path:gmatch("[^/]+") do
        table.insert(segments, seg)
    end

    local current = ""
    for i, seg in ipairs(segments) do
        if i == 1 and path:sub(1, 1) == "/" then
            current = "/" .. seg
        else
            current = current .. "/" .. seg
        end
        if lfs.attributes(current, "mode") ~= "directory" then
            lfs.mkdir(current)
        end
    end
end

--- List files matching a pattern in a directory
---@param dir string directory path
---@param pattern string glob pattern (e.g. "*.lua")
---@return string[] file paths
function M.listdir(dir, pattern)
    local results = {}
    local mode = lfs.attributes(dir, "mode")
    if mode ~= "directory" then return results end

    local prefix = pattern:match("^%*") and "" or "^"
    local suffix = pattern:match("%*$") and "" or "$"
    local lua_pattern = prefix .. pattern:gsub("%.", "%%."):gsub("%*", ".*") .. suffix

    for name in lfs.dir(dir) do
        if name ~= "." and name ~= ".." and name:match(lua_pattern) then
            table.insert(results, dir .. "/" .. name)
        end
    end
    return results
end

--- Find files recursively by name pattern
---@param dir string directory path
---@param name_pattern string filename pattern (e.g. "SKILL.md")
---@return string[] file paths
function M.find_files(dir, name_pattern)
    local results = {}
    local mode = lfs.attributes(dir, "mode")
    if mode ~= "directory" then return results end

    local prefix = name_pattern:match("^%*") and "" or "^"
    local suffix = name_pattern:match("%*$") and "" or "$"
    local lua_pattern = prefix .. name_pattern:gsub("%.", "%%."):gsub("%*", ".*") .. suffix

    local function walk(d)
        for name in lfs.dir(d) do
            if name ~= "." and name ~= ".." then
                local full = d .. "/" .. name
                local attr = lfs.attributes(full, "mode")
                if attr == "directory" then
                    walk(full)
                elseif attr == "file" and name:match(lua_pattern) then
                    table.insert(results, full)
                end
            end
        end
    end

    walk(dir)
    return results
end

---------------------------------------------------------------------------
-- YAML frontmatter parser (shared between skills.lua and memory.lua)
---------------------------------------------------------------------------

--- Parse simple YAML frontmatter from text
---@param text string raw content with optional --- delimiters
---@return table meta key-value pairs
---@return string body content after frontmatter
function M.parse_frontmatter(text)
    if not text:find("^---") then return {}, text end
    local _, end_pos = text:find("---", 4)
    if not end_pos then return {}, text end
    local fm = text:sub(4, end_pos - 1)
    local body = text:sub(end_pos + 1):gsub("^%s+", "")
    local meta = {}
    for line in fm:gmatch("[^\n]+") do
        local k, v = line:match("^(%w+):%s*(.+)$")
        if k and v then
            v = v:gsub('^"(.*)"$', "%1")
                :gsub("^'(.*)'$", "%1")
                :gsub("^|%s*", "")
                :gsub("%s*$", "")
            meta[k] = v
        end
    end
    return meta, body
end

---------------------------------------------------------------------------
-- OBSERVE_JS (shared between init.lua and subagent.lua)
---------------------------------------------------------------------------

M.OBSERVE_JS = [[
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

return M
