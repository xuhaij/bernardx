local M = {}
local json = require("dkjson")
local rawRequest = http.request


local function request (opts)
  local reqBody = opts.body
  local headers = opts.headers or {}
  if type(reqBody) == "table" then
    reqBody = json.encode(reqBody)
  end
  if reqBody then
    headers["Content-Type"] = "application/json"
  end
  local timeout = opts.timeout or 60
  local request_info = {
    method = opts.method or "GET",
    url = opts.url,
    multipart = opts.multipart,
    headers = headers,
    body = reqBody,
    timeout = timeout,
  }
  local startTime = GetTimeOfDayMs()
  while true do
    local status,body = rawRequest(request_info)
    if status ~= 0 and status ~= -1 then
      return status,body
    else
      print(status,body)
      if GetTimeOfDayMs() - startTime > timeout * 1000 then
        return nil,body
      end
      sleep(5000)
    end
  end
end



function M.get(port,path,params)
  local url = string.format("http://localhost:%d/%s",port,path)
  if params then
    local query = {}
    for k,v in pairs(params) do
      table.insert(query,string.format("%s=%s",k,v))
    end
    url = url .. "?" .. table.concat(query,"&")
  end
  local status,response = request {
    url = url,
    method = "GET",
  }
  return status,response
end

function M.post(port,path,body)
  local url = string.format("http://localhost:%d/%s",port,path)
  if type(body) == "table" then
    body = json.encode(body)
  end
  local status,response = request {
    url = url,
    method = "POST",
    body = body,
  }
  return status,response
end

function M.request(port,path,req)
  local url = string.format("http://localhost:%d/%s",port,path)
  req.url = url
  local status,response = request(req)
  return status,response
end

function M.delete(port,path)
  local url = string.format("http://localhost:%d/%s",port,path)
  local status,response = request {
    url = url,
    method = "DELETE",
  }
  return status,response
end


return M