--- AI module - Anthropic + OpenAI compatible API wrappers
-- @module ai
--
-- Basic usage:
--   local ai = require('ai')
--
--   -- Anthropic
--   local client = ai.anthropic({ api_key = "sk-ant-...", model = "claude-sonnet-4-20250514" })
--   local resp = client:messages({ messages = {{role="user", content="hi"}} })
--   print(client:text_content(resp))
--
--   -- OpenAI compatible
--   local client = ai.openai({ api_key = "sk-...", base_url = "https://api.openai.com/v1" })
--   local resp = client:chat({ messages = {{role="user", content="hi"}} })
--   print(client:text_content(resp))
--
-- Tool use (Anthropic):
--   local client = ai.anthropic({ api_key = "sk-ant-..." })
--
--   -- Define tools
--   local my_tools = {
--     ai.tool({
--       name = "get_weather",
--       description = "Get current weather for a location",
--       input_schema = ai.schema(
--         {
--           location = ai.string_prop("City name"),
--           unit = ai.string_prop("Temperature unit", {"celsius", "fahrenheit"}),
--         },
--         { "location" }
--       ),
--     }),
--   }
--
--   local messages = {
--     { role = "user", content = "What's the weather in Tokyo?" },
--   }
--
--   -- First call: model decides to use a tool
--   local resp = client:messages({ messages = messages, tools = my_tools })
--
--   if client:has_tool_calls(resp) then
--     -- Add assistant response to conversation
--     table.insert(messages, { role = "assistant", content = resp.content })
--
--     -- Execute tools and add results
--     local tool_msg = client:execute_tools(resp, function(call)
--       if call.name == "get_weather" then
--         return "25°C, sunny"  -- your actual logic here
--       end
--       return "unknown tool"
--     end)
--     table.insert(messages, tool_msg)
--
--     -- Second call: model generates final answer with tool results
--     resp = client:messages({ messages = messages, tools = my_tools })
--   end
--
--   print(client:text_content(resp))
--
-- Tool use (OpenAI):
--   local client = ai.openai({ api_key = "sk-..." })
--
--   local my_tools = {
--     ai.tool_openai({
--       name = "get_weather",
--       description = "Get current weather for a location",
--       parameters = ai.schema(
--         { location = ai.string_prop("City name") },
--         { "location" }
--       ),
--     }),
--   }
--
--   local messages = {
--     { role = "user", content = "What's the weather in Tokyo?" },
--   }
--
--   local resp = client:chat({ messages = messages, tools = my_tools })
--
--   if client:has_tool_calls(resp) then
--     local assistant_msg = resp.choices[1].message
--     table.insert(messages, assistant_msg)
--
--     local results = client:execute_tools(resp, function(call)
--       if call.name == "get_weather" then
--         return "25°C, sunny"
--       end
--       return "unknown tool"
--     end)
--     for _, r in ipairs(results) do
--       table.insert(messages, r)
--     end
--
--     resp = client:chat({ messages = messages, tools = my_tools })
--   end
--
--   print(client:text_content(resp))
--
-- Vision:
--   -- Anthropic
--   local resp = client:messages({
--     messages = {{
--       role = "user",
--       content = ai.image_content("Describe this image", "https://example.com/photo.jpg"),
--     }},
--   })
--
--   -- Anthropic with base64
--   local resp = client:messages({
--     messages = {{
--       role = "user",
--       content = ai.image_content("What is this?", ai.base64_source("image/png", b64_data)),
--     }},
--   })
--
--   -- OpenAI
--   local resp = client:chat({
--     messages = {{
--       role = "user",
--       content = ai.openai_image_content("Describe this", "https://example.com/photo.jpg"),
--     }},
--   })

local anthropic_mod = require('ai.anthropic')
local openai_mod = require('ai.openai')
local tools = require('ai.tools')
local utils = require('ai.utils')

local M = {}

---------------------------------------------------------------------------
-- Type definitions
---------------------------------------------------------------------------

---@class AI.ClientConfig
---@field api_key string
---@field base_url? string
---@field model? string
---@field max_tokens? integer default 4096
---@field default_headers? table<string, string>

---------------------------------------------------------------------------
-- Client factories
---------------------------------------------------------------------------

--- Create an Anthropic Messages API client
---@param config AI.ClientConfig
---@return table client
function M.anthropic(config)
    return anthropic_mod.new(config)
end

--- Create an OpenAI Chat Completions compatible client
---@param config AI.ClientConfig
---@return table client
function M.openai(config)
    return openai_mod.new(config)
end

---------------------------------------------------------------------------
-- Re-export: tool definition helpers
---------------------------------------------------------------------------

M.tool = tools.define                -- Anthropic format
M.tool_openai = tools.define_openai  -- OpenAI format
M.schema = tools.schema
M.string_prop = tools.string_prop
M.number_prop = tools.number_prop
M.integer_prop = tools.integer_prop
M.boolean_prop = tools.boolean_prop
M.array_prop = tools.array_prop
M.object_prop = tools.object_prop

---------------------------------------------------------------------------
-- Re-export: vision helpers
---------------------------------------------------------------------------

M.image_content = utils.image_content                  -- Anthropic format
M.base64_source = utils.base64_source                  -- base64 source builder
M.openai_image_content = utils.openai_image_content    -- OpenAI format

return M
