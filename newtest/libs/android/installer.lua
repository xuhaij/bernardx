

local shell = require "android.shell"
local utils = require "utils"
local M = {}

local function getPackageVersion(packageName)
  local data = shell.exec("dumpsys package " .. packageName .. " | grep versionName=")
  local strList = utils.split(data,"=")
  if #strList < 2 then
    return nil
  end
  local version = string.gsub(strList[2],"%s+","")
  return version
end

local function packageToName(packageName)
  local map = {
    ["org.chromium.chrome"] = "chromium",
  }
  return map[packageName]
end

M.getPackageVersion = getPackageVersion

local function downloadApk(packageName,version,appName)
  local baseUrl = "http://yunji.zj.51wmsy.com:65519/"
  shell.exec("mkdir -p " .. WORKING_DIR .. "/download/")
  appName = appName or packageToName(packageName)
  assert(appName, "unknown app for package " .. packageName)
  local apkName = string.format("%s-%s.apk",appName, version)
  local targetPath = WORKING_DIR .. "/download/" .. apkName
  local code,body,msg = http.download {
    url = baseUrl .. apkName,
    filepath = targetPath,
    timeout = 20*60
  }
  return code == 200 and targetPath or nil,msg
end

M.downloadApk = downloadApk

---确保安装指定版本的app
---@param packageName string 包名
---@param expectedVersion string 期待的版本
---@param appName string? app 名
---@return boolean
local function ensurePackageVersion(packageName, expectedVersion,appName)
  local version = getPackageVersion(packageName)
  if version == expectedVersion then
    logi("package", packageName, " already at expected version:", expectedVersion)
    return true
  end
  if ENGINE_VERSION < 83 then
    logw("engine version too low to install app:", ENGINE_VERSION)
    return false
  end
  local apkPath,err = downloadApk(packageName, expectedVersion,appName)
  if not apkPath then
    logw("download apk failed: " .. tostring(err))
    return false
  end
  
  -- 确保下载的文件完全写入到系统中
  sleep(1000)
  local installOutput = shell.exec("pm install -r " .. apkPath)
  local result = string.find(installOutput, "Success") ~= nil
  if result then
    logi("pacakge installed", packageName, " version:", expectedVersion)
  end
  os.remove(apkPath)
  return result
end

M.ensurePackageVersion = ensurePackageVersion


return M