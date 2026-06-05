
local M = {}
local utils = require "utils"
local net = require "net"
local shell = require "shell"


local function toVersionString(versionCode)
  versionCode = versionCode + 100
  local major = math.floor(versionCode / 100)
  local minor = math.floor(versionCode % 100 / 10)
  local patch = versionCode % 10
  return string.format("%d.%d.%d", major, minor, patch)
end

function M.ensureEngineVersion(versionCode)
  if ENGINE_VERSION <= 57 then
    logw("当前脚本不支持自动升级脚本引擎，最低支持引擎版本为1.5.7")
    return false
  end
  if ENGINE_VERSION >= versionCode then
    logi("当前脚本引擎版本为" .. toVersionString(ENGINE_VERSION) .. "，已满足要求")
    return true
  end
  if ENGINE_VERSION <92 then
    shell.exec("settings put global package_verifier_user_consent -1")
  end
  shell.startApp("com.maiku.runoffer.worker")
  local targetVersionString = toVersionString(versionCode)
  local targetUrl = string.format("http://download.jb.51wmsy.com/bernard/bernard-%s.apk", targetVersionString)
  SUI.toast("正在升级引擎版本到 " .. targetVersionString .. "，请稍后...")
  print(Guardian.upgradeEngine(targetUrl,"com.maiku.runoffer.worker","com.maiku.runoffer.worker.MainActivity"))
  sleep(20*60*1000)
  error("引擎版本升级失败，请手动升级")
end

---@return boolean
function M.stopTask(taskId)
  taskId = taskId or TASK_ID
  if not taskId then
    return false
  end
  local url = "http://api.jb.51wmsy.com/api/task/stop"
  local params = {
    id = taskId
  }
  local response = net.commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.success
end

function M.stopWorker(workerId)
  workerId = workerId or WORKER_ID
  if not workerId then
    return false
  end
  local url = "http://api.jb.51wmsy.com/api/worker/stop"
  local params = {
    id = workerId
  }
  local response = net.commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.success
end

---@param errorMsg string 简短错误消息
---@param deviceName string|nil 设备名称，默认为 DEVICE_NAME
---@param taskName string|nil 任务名称，写入 notes 字段
---@param fullErrorMsg string|nil 完整错误堆栈
function M.uploadError(errorMsg, deviceName, taskName, fullErrorMsg)
  -- 版本号必须大于39，才能调上传api，小于就不上传了
  if ENGINE_VERSION > 39 then
    local screenshotFilePath = WORKING_DIR .. "/screenshot.jpg"
    Display:update()
    Display:save(screenshotFilePath, 0, 0, -1, -1, 1, 100)
    ca.commonSleep()

    local uiNodes = Nd.dumpNodeInfo()

    local formData = {
      device_name  = deviceName or DEVICE_NAME,
      error_message = errorMsg,
    }
    if fullErrorMsg then
      formData.full_error_message = fullErrorMsg
    end
    if uiNodes then
      formData.ui_nodes = uiNodes
    end

    taskName = taskName or TASK_ID
    if taskName then
      formData.task_name = taskName
    end

    local status, response = http.request{
      url    = "http://416jiasu.emuer.top:5006/api/error-collect/api/reports",
      method = "POST",
      files  = { screenshotFilePath },
      data   = formData,
    }
    print(status,response)
    if status ~= 201 then
      logw("upload error failed, status, response", status, response)
    end
    return true
  end
  return true
end


return M