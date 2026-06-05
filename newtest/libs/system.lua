local M = {}

local delegate

if IOS then
  delegate = require "ios.system"
else
  delegate = require "android.system"
end

function M.ensureInit(params)
  return delegate.ensureInit(params)
end

function M.openApp(bundleIdOrPkgName)
  return delegate.openApp(bundleIdOrPkgName)
end

function M.closeApp(bundleIdOrPkgName)
  return delegate.closeApp(bundleIdOrPkgName)
end

---获取当前app的包名
---@return string? packageName
function M.getPackageName()
  return delegate.getPackageName()
end

function M.swipe(paths)
  return delegate.swipe(paths)
end


---获取当前设备的唯一标识符
---@return string deviceId
function M.getDeviceId()
  return delegate.getDeviceId()
end





return M 