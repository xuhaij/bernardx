
local M = {}

---@return string
local function shell(cmd)
  local handle = io.popen(cmd, "r")
  assert(handle, "shell: " .. cmd)
  local result = handle:read("a")
  handle:close()
  return result
end

---@return string
local function shellX(cmd)
  local result = shell("su --mount-master -c '" .. cmd .. "'")
  return result
end

M.exec = shell
M.execX = shellX

function M.stopApp(packageName)
  local result = shell("am force-stop " .. packageName)
  return true
end

function M.startActivity(packageName, activityName,other)
  other = other or ""
  -- 添加 -f 0x20000000 参数，是为了避免同类activity重复出现
  return shell("am start -n " .. packageName .. "/" .. activityName .. " -f 0x20000000  " .. other):find("Starting:",1,true) > 0
end

function M.startApp(packageName)
  local result = shell("monkey -p " .. packageName .. " -c android.intent.category.LAUNCHER 1")
  logd(result)
  return true
end


function M.removeDirOrFile(path)
  local result = shell("rm -rf " .. path)
  return true
end

function M.grantPermission(packageName,permission)
  local result = shell("pm grant " .. packageName .. " " .. permission)
  logd(result)
  return true
end

function M.packageNameList()
  local result = shell("pm list packages")
  local packages = {}
  for line in result:gmatch("[^\r\n]+") do
    local pkg = line:match("^package:(.+)$")
    if pkg then
      table.insert(packages,pkg)
    end
  end
  return packages
end



return M