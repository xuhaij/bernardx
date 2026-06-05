local json = require "dkjson"
local class = require "class"

local M = {}

---@class OpenAIClient
local Client = class.new("OpenAIClient")

function Client:ctor(config)
  config = config or {}
  self.api_key = config.api_key or ""
  self.base_url = (config.base_url or "https://api.openai.com/v1"):gsub("/+$", "")
  self.model = config.model or "gpt-4o-mini"
  self.max_retries = config.max_retries or 3
  self._messages = {}
end

---internal: send request with retry
---@param path string
---@param body table
---@return boolean ok
---@return table data
function Client:request(path, body)
  local url = self.base_url .. path
  local payload = json.encode(body)

  local httpRequest = {
    url = url,
    headers = {
      ["Content-Type"] = "application/json",
      Authorization = "Bearer " .. self.api_key,
    },
    method = "POST",
    body = payload,
  }

  for attempt = 1, self.max_retries do
    local code, result = http.request(httpRequest)

    if code == 200 or code == 201 then
      local data = json.decode(result)
      if data then
        return true, data
      end
      return false, { error = { message = "invalid json response", raw = result } }
    end

    -- 4xx except 429 -> no retry
    if code >= 400 and code < 500 and code ~= 429 then
      local errData = json.decode(result) or {}
      return false, errData
    end

    -- 429 or 5xx -> retry with backoff
    if attempt < self.max_retries then
      local wait = math.min(2 ^ attempt, 8)
      sleep(wait * 1000)
    end
  end

  return false, { error = { message = "max retries exceeded", code = -1 } }
end

---chat completion (low level)
---@param opts table { model?, messages, tools?, tool_choice?, temperature?, max_tokens?, response_format? }
---@return boolean ok
---@return table response
function Client:chat(opts)
  opts = opts or {}
  local body = {
    model = opts.model or self.model,
    messages = opts.messages,
    temperature = opts.temperature,
    max_tokens = opts.max_tokens,
  }
  if opts.tools then
    body.tools = opts.tools
  end
  if opts.tool_choice then
    body.tool_choice = opts.tool_choice
  end
  if opts.response_format then
    body.response_format = opts.response_format
  end
  return self:request("/chat/completions", body)
end

---send messages, return content string (convenience)
---@param messages table[]
---@param opts table|nil
---@return string|nil content
function Client:complete(messages, opts)
  opts = opts or {}
  opts.messages = messages
  local ok, resp = self:chat(opts)
  if not ok then return nil end
  local choice = resp.choices and resp.choices[1]
  if not choice then return nil end
  return choice.message and choice.message.content
end

---send a user message, auto-manage history
---@param content string
---@param opts table|nil
---@return string|nil reply
---@return table|nil tool_calls
---@return table|nil error
function Client:send(content, opts)
  self._messages[#self._messages + 1] = { role = "user", content = content }

  local chatOpts = { messages = self._messages }
  if opts then
    for k, v in pairs(opts) do chatOpts[k] = v end
  end

  local ok, resp = self:chat(chatOpts)
  if not ok then
    self._messages[#self._messages] = nil
    return nil, nil, resp
  end

  local choice = resp.choices and resp.choices[1]
  if not choice then return nil end

  local msg = choice.message
  self._messages[#self._messages + 1] = msg

  if msg.tool_calls and #msg.tool_calls > 0 then
    return msg.content, msg.tool_calls
  end
  return msg.content
end

---submit tool result and continue conversation
---@param tool_call_id string
---@param result string
---@param opts table|nil
---@return string|nil reply
---@return table|nil tool_calls
function Client:submitToolResult(tool_call_id, result, opts)
  self._messages[#self._messages + 1] = {
    role = "tool",
    tool_call_id = tool_call_id,
    content = result,
  }

  local chatOpts = { messages = self._messages }
  if opts then
    for k, v in pairs(opts) do chatOpts[k] = v end
  end

  local ok, resp = self:chat(chatOpts)
  if not ok then return nil end

  local choice = resp.choices and resp.choices[1]
  if not choice then return nil end

  local msg = choice.message
  self._messages[#self._messages + 1] = msg

  if msg.tool_calls and #msg.tool_calls > 0 then
    return msg.content, msg.tool_calls
  end
  return msg.content
end

---send message + auto-execute tools via ToolProvider
---@param content string
---@param provider ToolProvider
---@param opts table|nil
---@return string|nil final_reply
function Client:sendWithTools(content, provider, opts)
  opts = opts or {}
  opts.tools = provider:schemas()

  local reply, toolCalls = self:send(content, opts)
  local maxRounds = 10

  while toolCalls and #toolCalls > 0 and maxRounds > 0 do
    maxRounds = maxRounds - 1
    for _, tc in ipairs(toolCalls) do
      local fn = tc["function"]
      local args = json.decode(fn.arguments) or {}
      local result = provider:execute(fn.name, args)
      local toolReply, nextCalls = self:submitToolResult(tc.id, result, opts)
      reply = toolReply
      toolCalls = nextCalls
    end
  end

  return reply
end

---set system prompt
---@param prompt string
function Client:setSystemPrompt(prompt)
  if self._messages[1] and self._messages[1].role == "system" then
    self._messages[1].content = prompt
  else
    table.insert(self._messages, 1, { role = "system", content = prompt })
  end
end

---@return table messages
function Client:history()
  return self._messages
end

---clear history, keep system prompt
function Client:clear()
  if self._messages[1] and self._messages[1].role == "system" then
    self._messages = { self._messages[1] }
  else
    self._messages = {}
  end
end

M.Client = Client

---@class ToolProvider
---@field _tools table[] tool schemas for api
---@field _handlers table<string, function> name -> handler(args) -> result
local ToolProvider = class.new("ToolProvider")

function ToolProvider:ctor()
  self._tools = {}
  self._handlers = {}
end

---register a tool
---@param name string tool name
---@param description string tool description for LLM
---@param params table json-schema of parameters
---@param handler function(args:table):string
---@return ToolProvider self
function ToolProvider:tool(name, description, params, handler)
  assert(not self._handlers[name])
  self._tools[#self._tools + 1] = {
    type = "function",
    ["function"] = {
      name = name,
      description = description,
      parameters = params,
    },
  }
  self._handlers[name] = handler
  return self
end

---get tool schemas for API request
---@return table[]
function ToolProvider:schemas()
  return self._tools
end

---execute a tool by name
---@param name string
---@param args table
---@return string result
function ToolProvider:execute(name, args)
  local handler = self._handlers[name]
  if not handler then
    return json.encode({ error = "unknown tool: " .. name })
  end
  local ok, result = pcall(handler, args)
  if not ok then
    return json.encode({ error = tostring(result) })
  end
  return tostring(result)
end

M.ToolProvider = ToolProvider

---@class CompositeToolProvider : ToolProvider
---@field _providers ToolProvider[]
local CompositeToolProvider = class.new("CompositeToolProvider", ToolProvider)

function CompositeToolProvider:ctor()
  ToolProvider.ctor(self)
  self._providers = {}
end

---add a ToolProvider, returns self for chaining
---@param provider ToolProvider
---@return CompositeToolProvider self
function CompositeToolProvider:add(provider)
  self._providers[#self._providers + 1] = provider
  return self
end

---collect all schemas from child providers
---@return table[]
function CompositeToolProvider:schemas()
  local result = {}
  for _, p in ipairs(self._providers) do
    local schemas = p:schemas()
    for _, s in ipairs(schemas) do
      result[#result + 1] = s
    end
  end
  return result
end

---dispatch execute to the provider that owns the tool
---@param name string
---@param args table
---@return string result
function CompositeToolProvider:execute(name, args)
  for _, p in ipairs(self._providers) do
    local handler = p._handlers and p._handlers[name]
    if handler then
      local ok, result = pcall(handler, args)
      if not ok then
        return json.encode({ error = tostring(result) })
      end
      return tostring(result)
    end
  end
  return json.encode({ error = "unknown tool: " .. name })
end

M.CompositeToolProvider = CompositeToolProvider

return M
