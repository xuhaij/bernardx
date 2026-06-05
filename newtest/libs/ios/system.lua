local M = {}

local wda = require "ios.wda"
local api_net = require "ios.api_net"
local json = require "dkjson"

local controllerPort<const> = 7999

---@type WDASession
local _wdaSession = nil

local function _tap(x,y)
  return _wdaSession:tap(x,y)
end

local function _swipe(paths)
  return _wdaSession:swipe(paths)
end


function M.swipe(paths)
  return _swipe(paths)
end

local _Display = {}

function _Display:getSize()
  local size = _wdaSession:getWindowSize()
  return size.width,size.height
end

local _By = {}

function _By.classChain(chain)
  return wda.newUIFilter(_wdaSession,wda.FilterType.kClassChain,chain)
end

function _By.xpath(xpath)
  return wda.newUIFilter(_wdaSession,wda.FilterType.kXpath,xpath)
end

function _By.id(id)
  return wda.newUIFilter(_wdaSession,wda.FilterType.kId,id)
end

function _By.res(id)
  return wda.newUIFilter(_wdaSession,wda.FilterType.kId,id)
end

function _By.clz(className)
  return wda.newUIFilter(_wdaSession,wda.FilterType.kClassName,className)
end

function _By.predicate(predicate)
  return wda.newUIFilter(_wdaSession,wda.FilterType.kPredicateString,predicate)
end


local inited = false

---@param config WDASessionConfig?
function M.ensureInit(config)
  if inited then
    return true
  end
  inited = true
  _wdaSession = wda.newSession(config)
  tap = _tap
  Display = _Display
  By = _By
  return true
end

function M.openApp(bundleId)
  return _wdaSession:openApp(bundleId)
end

function M.closeApp(bundleId)
  return _wdaSession:closeApp(bundleId)
end

function M.activeAppInfo()
  return _wdaSession:activeAppInfo()
end

function M.sendKeys(keys)
  return _wdaSession:sendKeys(keys)
end

function M.getDeviceId()
  return UDID
end

function M.getPackageName()
  local appInfo = _wdaSession:activeAppInfo()
  if appInfo then
    return appInfo.bundleId
  end
  return nil
end

---获取当前手机的语言和区域设置
---@return string? lang, string? locale
function M.getLang()
  assert(UDID,"UDID is nil")
  local status,response = api_net.get(
    controllerPort,
    string.format("lang/%s",UDID)
  )
  if status ~= 200 then
    return nil,nil
  end
  local data = json.decode(response)
  assert(data,"decode lang response failed")
  return data.lang,data.locale
end

function M.appList()
  assert(UDID,"UDID is nil")
  local status,response = api_net.get(
    controllerPort,
    string.format("api/apps/%s",UDID)
  )
  if status ~= 200 then
    return nil
  end
  local data = json.decode(response)
  return data
end

---设置当前手机的语言和区域设置
---@param lang string 语言代码，如 "en-US", "zh-Hans"
---@param locale string 区域代码，如 "en_US", "zh_CN"
---@return boolean success
function M.setLang(lang,locale)
  assert(UDID,"UDID is nil")
  local status,response = api_net.post(
    controllerPort,
    string.format("lang/%s",UDID),
    {
      lang = lang,
      locale = locale,
    }
  )
  if status ~= 200 then
    return false
  end
  local data = json.decode(response)
  assert(data,"decode set lang response failed")
  return data.success
end

function M.keyboardDismiss()
  return _wdaSession:keyboardDismiss()
end

function M.wda()
  return _wdaSession
end

function M.pushFileToHamsterDir(localPath,devicePath)
  assert(UDID,"UDID is nil")
  local status,response = api_net.post(
    controllerPort,
    string.format("fsync/%s",UDID),
    {
      action = "push",
      bundleId = "com.maiku.app.Hamster",
      localPath = localPath,
      devicePath = devicePath,
    }
  )
  if status ~= 200 then
    return false
  end
  local data = json.decode(response)
  assert(data,"decode push file response failed")
  return data.success
end

M.unlock = wda.unlock
M.isLocked = wda.isLocked
M.lock = wda.lock

return M