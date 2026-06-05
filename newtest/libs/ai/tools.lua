--- Tool definition helpers for both Anthropic and OpenAI formats
-- @module ai.tools

local M = {}

---------------------------------------------------------------------------
-- Type definitions
---------------------------------------------------------------------------

---@class AI.Tool.Spec
---@field name string tool/function name
---@field description? string
---@field input_schema? table JSON Schema (Anthropic)
---@field parameters? table JSON Schema (OpenAI)

---@class AI.Tool.Def  Anthropic tool definition
---@field name string
---@field description string
---@field input_schema table

---@class AI.Tool.OpenAIDef  OpenAI tool definition
---@field type string "function"
---@field ["function"] {name:string, description:string, parameters:table}

---------------------------------------------------------------------------
-- Anthropic format tool definition
---------------------------------------------------------------------------

--- Define a tool in Anthropic format
---@param spec AI.Tool.Spec
---@return AI.Tool.Def
function M.define(spec)
    assert(spec and spec.name, "tool name is required")
    return {
        name = spec.name,
        description = spec.description or "",
        input_schema = spec.input_schema or { type = "object", properties = {} },
    }
end

---------------------------------------------------------------------------
-- OpenAI format tool definition
---------------------------------------------------------------------------

--- Define a function tool in OpenAI format
---@param spec AI.Tool.Spec
---@return AI.Tool.OpenAIDef
function M.define_openai(spec)
    assert(spec and spec.name, "function name is required")
    return {
        type = "function",
        ["function"] = {
            name = spec.name,
            description = spec.description or "",
            parameters = spec.parameters or { type = "object", properties = {} },
        },
    }
end

---------------------------------------------------------------------------
-- Schema builders
---------------------------------------------------------------------------

--- Build a JSON Schema object
---@param properties table field definitions
---@param required? string[] required field names
---@return table schema
function M.schema(properties, required)
    local s = {
        type = "object",
        properties = properties or {},
    }
    if required then s.required = required end
    return s
end

--- String property
function M.string_prop(description, enum)
    local p = { type = "string", description = description or "" }
    if enum then p.enum = enum end
    return p
end

--- Number property
function M.number_prop(description)
    return { type = "number", description = description or "" }
end

--- Integer property
function M.integer_prop(description)
    return { type = "integer", description = description or "" }
end

--- Boolean property
function M.boolean_prop(description)
    return { type = "boolean", description = description or "" }
end

--- Array property
---@param description string
---@param items table? item schema
---@return table
function M.array_prop(description, items)
    return { type = "array", description = description or "", items = items or {} }
end

--- Object property (nested)
---@param description string
---@param properties table?
---@param required string[]?
---@return table
function M.object_prop(description, properties, required)
    local p = { type = "object", description = description or "", properties = properties or {} }
    if required then p.required = required end
    return p
end

return M
