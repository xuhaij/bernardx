--- System prompt assembly: section-based prompt builder with caching
-- @module prompt
--
-- Usage:
--   local prompt = require('prompt')
--
--   prompt.section("identity", "You are a browser automation agent.")
--   prompt.section("tools", "Available tools: observe, click, type, done.")
--   prompt.section("skills", "Skills: ...")
--
--   local system = prompt.assemble({ skills = true, memory = false })

local json = require('json')

local M = {}

---------------------------------------------------------------------------
-- Section registry
---------------------------------------------------------------------------

local sections = {}

--- Register or update a prompt section
---@param name string section key
---@param content string section text
function M.section(name, content)
    sections[name] = content
end

--- Remove a prompt section
---@param name string section key
function M.remove(name)
    sections[name] = nil
end

---------------------------------------------------------------------------
-- Assembly
---------------------------------------------------------------------------

--- Section order (stable ordering for API prompt caching)
local SECTION_ORDER = {
    "identity",
    "tools",
    "workspace",
    "skills",
    "instructions",
    "memory",
}

--- Assemble system prompt from enabled sections
---@param enabled table? section_name → bool (nil = enabled)
---@return string system_prompt
function M.assemble(enabled)
    local parts = {}
    local added = {}

    -- Build ordered list from SECTION_ORDER
    for _, name in ipairs(SECTION_ORDER) do
        if sections[name] and (not enabled or enabled[name] ~= false) then
            table.insert(parts, sections[name])
            added[name] = true
        end
    end

    -- Add any extra sections not in SECTION_ORDER
    if enabled then
        for name, is_enabled in pairs(enabled) do
            if is_enabled and sections[name] and not added[name] then
                table.insert(parts, sections[name])
            end
        end
    end

    return table.concat(parts, "\n\n")
end

---------------------------------------------------------------------------
-- Cache
---------------------------------------------------------------------------

local _last_key = nil
local _last_prompt = nil

--- Get system prompt with caching — reassemble only when context changes
---@param enabled table? section_name → bool
---@return string system_prompt
function M.get(enabled)
    local key = json.encode(enabled or {})
    if key == _last_key and _last_prompt then
        return _last_prompt
    end
    _last_key = key
    _last_prompt = M.assemble(enabled)
    return _last_prompt
end

--- Invalidate cache (call after section updates)
function M.invalidate()
    _last_key = nil
    _last_prompt = nil
end

return M
