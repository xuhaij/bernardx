
local shell = require "android.shell"

local M = {}

function M.ensureInit(params)
  return Nd.connect(3)
end

function M.openApp(bundleIdOrPkgName)
  return shell.startApp(bundleIdOrPkgName)
end

function M.closeApp(bundleIdOrPkgName)
  return shell.stopApp(bundleIdOrPkgName)
end

function M.swipe(paths)
  local pt = pointer()
  for _,v in ipairs(paths) do
    pt.x = v[1]
    pt.y = v[2]
    pt.pressure = math.random(35,50)
    pt:sync()
    sleep(math.random(17,23))
  end
  pt:up()
  return true
end

function M.getDeviceId()
  return string.match(shell.exec("settings get secure android_id"),"%g+")
end

function M.getPackageName()
  return System.getPackageName()
end



return M 