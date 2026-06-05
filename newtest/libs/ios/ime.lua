local M = {}

local api = require "ios.api_net"

local function imePort()
---@diagnostic disable-next-line: undefined-global
  return IME_PORT
end

local function sendInputCommand(value)
  local status,response = api.post(imePort(),"text",value)
  return status == 200 and response == "success"
end

function M.input(text)
  return sendInputCommand(text)
end

function M.ensureMyInputMethod()
  return true
end

function M.simInput(text)
  local cs = {}
  for c in string.gmatch(text,utf8.charpattern) do
    table.insert(cs,c)
  end
  for i,c in ipairs(cs) do
    sendInputCommand(c)
    ca.randomSleep(340,530)
  end
  return true
end

function M.delete()
  local status,response = api.get(imePort(),"delete")
  return status == 200 and response == "success"
end

function M.dismiss()
  local status,response = api.post(imePort(),"dismiss")
  return status == 200 and response == "success"
end

function M.enable()
  for i=1,3 do
    local status,response = http.request {
      url = string.format("http://localhost:%d/enable", imePort()),
      method = "GET"
    }
    if status == 200 then
      return response == "true"
    end
  end
  return false
end


return M