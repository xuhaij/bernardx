--- Memory system: persistent cross-session knowledge
-- @module agent.memory
--
-- Storage:
--   memory_dir/
--     MEMORY.md       ← index (one line per memory)
--     user-profile.md ← individual memory files (Markdown + YAML frontmatter)

local util = require('agent.util')

local M = {}

---------------------------------------------------------------------------
-- Scan all memory files
---------------------------------------------------------------------------

--- Scan memory directory and return registry
---@param memory_dir string path to memory directory
---@return table registry {name -> {name, description, type, body, filename, path}}
function M.scan(memory_dir)
    util.mkdir_p(memory_dir)
    local registry = {}
    local files = util.find_files(memory_dir, "*.md")

    for _, path in ipairs(files) do
        -- Skip index file
        if not path:match("MEMORY%.md$") then
            local f = io.open(path, "r")
            if f then
                local raw = f:read("*a")
                f:close()
                local meta, body = util.parse_frontmatter(raw)
                local filename = path:match("([^/]+)%.md$")
                local name = meta.name or filename or "unknown"
                registry[name] = {
                    name = name,
                    description = meta.description or "",
                    type = meta.type or "user",
                    body = body,
                    filename = filename .. ".md",
                    path = path,
                }
            end
        end
    end
    return registry
end

---------------------------------------------------------------------------
-- Index (for system prompt injection)
---------------------------------------------------------------------------

--- Read or rebuild MEMORY.md index
---@param memory_dir string path to memory directory
---@param registry? table pre-scanned registry (will scan if nil)
---@return string index_text one line per memory, or empty string
function M.index_text(memory_dir, registry)
    registry = registry or M.scan(memory_dir)
    local lines = {}
    for _, m in pairs(registry) do
        local desc = m.description
        if desc == "" then desc = m.body:sub(1, 80):gsub("\n", " ") end
        table.insert(lines, "- " .. m.name .. ": " .. desc)
    end
    table.sort(lines)
    local text = table.concat(lines, "\n")
    if text == "" then return "" end

    -- Write index file
    local f = io.open(memory_dir .. "/MEMORY.md", "w")
    if f then
        f:write(text .. "\n")
        f:close()
    end

    return text
end

---------------------------------------------------------------------------
-- Load full content
---------------------------------------------------------------------------

--- Load a memory's full content by name
---@param registry table from scan()
---@param name string memory name
---@return string|nil content
---@return string|nil error
function M.load(registry, name)
    local m = registry[name]
    if not m then
        local available = {}
        for k, _ in pairs(registry) do table.insert(available, k) end
        return nil, "memory not found: " .. name .. ". Available: " .. table.concat(available, ", ")
    end
    local f = io.open(m.path, "r")
    if not f then return nil, "cannot read: " .. m.path end
    local content = f:read("*a")
    f:close()
    return content
end

---------------------------------------------------------------------------
-- Save new memory
---------------------------------------------------------------------------

--- Save a new memory file and rebuild index
---@param memory_dir string path to memory directory
---@param name string short kebab-case identifier
---@param mem_type string "user"|"feedback"|"project"|"reference"
---@param description string one-line summary
---@param body string full markdown content
---@return string status message
function M.save(memory_dir, name, mem_type, description, body)
    util.mkdir_p(memory_dir)
    local slug = util.slugify(name)
    if slug == "" then slug = "memory" end
    local filename = slug .. ".md"
    local path = memory_dir .. "/" .. filename

    local f = io.open(path, "w")
    if not f then return "error: cannot create " .. path end
    f:write("---\nname: " .. name .. "\ndescription: " .. description
        .. "\ntype: " .. mem_type .. "\n---\n\n" .. body .. "\n")
    f:close()

    return "saved memory: " .. name
end

return M
