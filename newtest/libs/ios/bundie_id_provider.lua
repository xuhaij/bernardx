local M = {}

local cache_ = {}
local system = require "ios.system"

function M.get(label)
  local id = cache_[label]
  if id then
    return id
  end
  local apps = system.appList()

  for _, app in ipairs(apps) do
    if app.name == label then
      cache_[label] = app.bundleId
      return app.bundleId
    end
  end
  return nil
end


return M 