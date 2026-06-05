
local M = {}

local net = require "net"
local json = require "dkjson"

local kApiBaseUrl<const> = "http://api.jb.51wmsy.com/api/"

function M.percentLock(linkCode,percent,timeout,deviceName)
  local url = kApiBaseUrl .. "percent/lock"
  deviceName = deviceName or DEVICE_NAME
  local params = {
    tag = linkCode,
    user_name = deviceName,
    percentage = percent,
    timeout = timeout
  }
  local response = net.commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.ok,tonumber(data.special_completed) or 0
end

function M.completedOnce(linkCode,deviceName)
  local url = kApiBaseUrl .. "percent/completed"
  local params = {
    tag = linkCode,
    user_name = deviceName
  }
  local response = net.commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.ok
end

--- send email to someone
--- @param to string recipient email address
--- @param subject string email subject
--- @param body string email body
--- @return boolean success whether email sent successfully
function M.sendEmail(to,subject,body)
  local url = kApiBaseUrl .. "notification/email"
  local body = {
    to = to,
    subject = subject,
    body = body
  }
  local response = net.commonEnsureRequest(url,nil,"POST",json.encode(body))
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.success
end


return M