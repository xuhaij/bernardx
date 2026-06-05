--- Skill loader: scan, load, and save SKILL.md files
-- @module skills
--
-- Skills are markdown files in skills/<name>/SKILL.md with optional YAML frontmatter:
--   ---
--   name: my-skill
--   description: One-line description
--   ---
--   # Skill content here

local util = require('agent.util')

local M = {}

---------------------------------------------------------------------------
-- Scan skills directory
---------------------------------------------------------------------------

function M.scan(skills_dir)
    local registry = {}
    local files = util.find_files(skills_dir, "SKILL.md")

    for _, path in ipairs(files) do
        local f = io.open(path, "r")
        if f then
            local raw = f:read("*a")
            f:close()
            local meta, body = util.parse_frontmatter(raw)
            local dir = path:match("skills/([^/]+)/SKILL%.md$") or path:match("([^/]+)/SKILL%.md$")
            local name = meta.name or dir or "unknown"
            meta.name = name
            meta.content = raw
            meta.body = body
            registry[name] = meta
        end
    end
    return registry
end

---------------------------------------------------------------------------
-- List skills as one-line descriptions (for system prompt)
---------------------------------------------------------------------------

function M.catalog(registry)
    local lines = {}
    for _, s in pairs(registry) do
        table.insert(lines, "- " .. s.name .. ": " .. (s.description or "(no description)"))
    end
    if #lines == 0 then return "(no skills available)" end
    table.sort(lines)
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Load skill content by name
---------------------------------------------------------------------------

function M.load(registry, name)
    local s = registry[name]
    if not s then
        local available = {}
        for k, _ in pairs(registry) do table.insert(available, k) end
        return nil, "skill not found: " .. name .. ". Available: " .. table.concat(available, ", ")
    end
    return s.content
end

---------------------------------------------------------------------------
-- Save a new skill
---------------------------------------------------------------------------

function M.save(skills_dir, name, description, content)
    local dir = skills_dir .. "/" .. name
    util.mkdir_p(dir)
    local f = io.open(dir .. "/SKILL.md", "w")
    if not f then return nil, "cannot create " .. dir .. "/SKILL.md" end
    f:write("---\nname: " .. name .. "\ndescription: " .. description .. "\n---\n\n" .. content)
    f:close()
    return dir .. "/SKILL.md"
end

return M
