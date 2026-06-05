--- Agent registry: load sub-agent definitions from a directory
-- @module agent.agents
--
-- Each agent is a .md file with YAML frontmatter:
--   ---
--   name: tree-generator
--   description: Generates deterministic behavior trees
--   tools: [observe, save_tree, list_scripts]
--   max_turns: 5
--   ---
--   <system prompt body>
--
-- Usage:
--   local agents = require('agent.agents')
--   local registry = agents.scan("/path/to/agents")
--   local def = agents.get(registry, "tree-generator")
--   local catalog = agents.catalog(registry)

local M = {}

---------------------------------------------------------------------------
-- Parse YAML-like frontmatter from markdown
---------------------------------------------------------------------------

local function parse_frontmatter(content)
    local fm_str = content:match("^%-%-%-\n(.-)\n%-%-%-\n")
    if not fm_str then return {}, content end

    local meta = {}
    local body = content:gsub("^%-%-%-\n.-\n%-%-%-\n", "")

    -- Simple parser for: key: value, key: [a, b, c]
    for line in fm_str:gmatch("[^\n]+") do
        local key, val = line:match("^(%w[%w_]-):%s*(.+)$")
        if key and val then
            val = val:match("^%s*(.-)%s*$")
            -- Array: [a, b, c]
            if val:match("^%[") then
                local arr = {}
                local inner = val:match("^%[(.+)%]$")
                if inner then
                    for item in inner:gmatch("([^,]+)") do
                        item = item:match("^%s*(.-)%s*$")
                        if item ~= "" then table.insert(arr, item) end
                    end
                end
                meta[key] = arr
            else
                -- Strip quotes
                val = val:match('^"?(.-)"?$') or val
                -- Convert booleans
                if val == "true" then val = true
                elseif val == "false" then val = false
                end
                meta[key] = val
            end
        end
    end

    return meta, body
end

---------------------------------------------------------------------------
-- Scan directory for agent definitions
---------------------------------------------------------------------------

--- Scan a directory for .md agent definitions
---@param dir string path to agents directory
---@return table registry { name = { name, description, tools, max_turns, prompt, file } }
function M.scan(dir)
    local registry = {}
    local lfs = require("lfs")

    for file in lfs.dir(dir) do
        if file:match("%.md$") then
            local path = dir .. "/" .. file
            local f = io.open(path, "r")
            if f then
                local content = f:read("*a")
                f:close()

                local meta, body = parse_frontmatter(content)
                local name = meta.name or file:gsub("%.md$", "")

                registry[name] = {
                    name = name,
                    description = meta.description or "",
                    tools = meta.tools or {},
                    max_turns = tonumber(meta.max_turns) or 5,
                    prompt = body,
                    file = file,
                }
            end
        end
    end

    return registry
end

---------------------------------------------------------------------------
-- Get agent by name
---------------------------------------------------------------------------

---@param registry table from scan()
---@param name string agent name
---@return table|nil definition
function M.get(registry, name)
    return registry[name]
end

---------------------------------------------------------------------------
-- Build catalog text for main prompt
---------------------------------------------------------------------------

---@param registry table from scan()
---@return string catalog text listing available agents
function M.catalog(registry)
    local lines = {}
    for name, def in pairs(registry) do
        local tools_str = #def.tools > 0 and (" (tools: " .. table.concat(def.tools, ", ") .. ")") or ""
        table.insert(lines, "- " .. name .. ": " .. def.description .. tools_str)
    end
    table.sort(lines)
    return #lines > 0 and table.concat(lines, "\n") or "(no sub-agents defined)"
end

---------------------------------------------------------------------------
-- List agent names
---------------------------------------------------------------------------

---@param registry table from scan()
---@return table names list of agent names
function M.names(registry)
    local names = {}
    for name, _ in pairs(registry) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

return M
