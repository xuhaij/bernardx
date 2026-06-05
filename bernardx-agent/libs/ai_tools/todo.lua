local json = require "dkjson"
local openai = require "openai"

local M = {}

---@class TodoTool : ToolProvider
local TodoTool = class.new("TodoTool", openai.ToolProvider)

function TodoTool:ctor()
  openai.ToolProvider.ctor(self)

  self._todos = {}
  self._next_id = 1

  self:tool("todo_add", "Add a new todo item", {
    type = "object",
    properties = {
      title = { type = "string", description = "Todo title" },
      description = { type = "string", description = "Optional detail" },
    },
    required = { "title" },
  }, function(args)
    return self:add(args)
  end)

  self:tool("todo_list", "List all todo items, optionally filter by status", {
    type = "object",
    properties = {
      status = { type = "string", enum = { "pending", "done" }, description = "Filter by status, omit for all" },
    },
  }, function(args)
    return self:list(args.status)
  end)

  self:tool("todo_done", "Mark a todo as done by its id", {
    type = "object",
    properties = {
      id = { type = "integer", description = "Todo id" },
    },
    required = { "id" },
  }, function(args)
    return self:done(args.id)
  end)

  self:tool("todo_remove", "Delete a todo item by its id", {
    type = "object",
    properties = {
      id = { type = "integer", description = "Todo id" },
    },
    required = { "id" },
  }, function(args)
    return self:remove(args.id)
  end)

  self:tool("todo_clear", "Remove all done todos", nil, function(_)
    return self:clear()
  end)
end

---@param args table { title, description? }
---@return string
function TodoTool:add(args)
  local item = {
    id = self._next_id,
    title = args.title,
    description = args.description,
    status = "pending",
  }
  self._todos[self._next_id] = item
  self._next_id = self._next_id + 1
  return json.encode({ success = true, todo = item })
end

---@param status string|nil
---@return string
function TodoTool:list(status)
  local result = {}
  for _, item in pairs(self._todos) do
    if not status or item.status == status then
      result[#result + 1] = item
    end
  end
  return json.encode({ success = true, todos = result })
end

---@param id integer
---@return string
function TodoTool:done(id)
  local item = self._todos[id]
  if not item then
    return json.encode({ success = false, error = "not found" })
  end
  item.status = "done"
  return json.encode({ success = true, todo = item })
end

---@param id integer
---@return string
function TodoTool:remove(id)
  local item = self._todos[id]
  if not item then
    return json.encode({ success = false, error = "not found" })
  end
  self._todos[id] = nil
  return json.encode({ success = true })
end

---@return string
function TodoTool:clear()
  local count = 0
  for id, item in pairs(self._todos) do
    if item.status == "done" then
      self._todos[id] = nil
      count = count + 1
    end
  end
  return json.encode({ success = true, cleared = count })
end

---@return table[] all todo items (raw)
function TodoTool:todos()
  return self._todos
end

M.TodoTool = TodoTool

return M
