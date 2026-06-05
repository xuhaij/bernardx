local net = require "net"
local utils = require "utils"
local shell = require "android.shell"
local ca = require "common_action"
local cdp_wrapper = require "android.cdp_wrapper"


local M = {}

local packageName <const> = "org.chromium.chrome"
local activityName <const> = "org.chromium.chrome.browser.ChromeTabbedActivity"
local configureDir <const> = "/data/data/org.chromium.chrome/app_chrome/"
local configurePath <const> = configureDir .. "user.fingerprint.json"

local function ensureWritedFingerprint(configure)
  shell.exec("mkdir -p " .. configureDir)
  shell.exec("chmod 777 " .. configureDir)
  local result = utils.writeFile(configurePath, configure)
  if result then
    shell.exec("chmod 644 " .. configurePath)
  end
  return result
end

local function isInChrome()
  return System.getPackageName() == packageName
end

local function isOpenRight()
  local loginButton = By.res("org.chromium.chrome:id/account_picker_continue_as_button")
  local negativeButton = By.res("org.chromium.chrome:id/negative_button")
  local userButton = By.res("org.chromium.chrome:id/optional_toolbar_button")
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local timeout = ca.randomTime(3000, 3500)
  while nowTime - startTime < timeout do
    if not isInChrome() then
      return false
    end
    if loginButton:find() then
      return false
    end
    if userButton:find() then
      return true
    end
    if negativeButton:find() then
      return true
    end
    ca.tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

local function toChromiumMain()
  local negativeButton = By.res("org.chromium.chrome:id/negative_button")
  local userButton = By.res("org.chromium.chrome:id/optional_toolbar_button")
  local node = ca.waitForNode(negativeButton, ca.actionTimeout())
  if not node then
    logd("don't find negativeButton")
    return userButton:find() ~= nil
  end
  if ca.ensureClickToVanish(negativeButton,negativeButton,ca.commonActionTimeout(),2) ~= 0 then
      logd("click negativeButton failed or negativeButton not vanish")
    return false
  end
  return ca.waitForNode(userButton, ca.actionTimeout()) ~= nil
end

M.toChromiumMain = toChromiumMain

function M.readConfigure()
  local content = utils.readFile(configurePath)
  if content then
    return content
  end
  return nil
end

local function ensureOpenAndHasConfigure(params)
  if isInChrome() then
    return true
  end
  local configure
  if params then
    configure = net.getChromiumConfigure(params)
    if not configure then
      logw("getChromiumConfigure failed")
      return false
    end
  end

  for i = 1, 3 do
    if configure and not ensureWritedFingerprint(configure) then
      logw("ensureWritedFingerprint failed")
      goto continue
    end
    shell.startActivity(packageName, activityName)
    if not ca.waitFor(isInChrome) then
      logw("isInChrome failed")
      goto continue
    end
    if not isOpenRight() then
      goto continue
    end
    if toChromiumMain() then
      logd("toChromiumMain success")
      return true
    end
    ::continue::
    shell.stopApp(packageName)
    ca.commonSleep()
  end
  return false
end

---@return boolean
function M.ensureInit(params)
  for i = 1, 3 do
    if ensureOpenAndHasConfigure(params) then
      logd("ensureOpen success")
      return cdp_wrapper.ensureInit()
          and cdp_wrapper.switchToFirstPage()
    end
    shell.stopApp(packageName)
    ca.commonSleep()
  end
  return false
end

function M.reset()
  shell.stopApp(packageName)
  local result = shell.exec("pm clear org.chromium.chrome")
  return string.find(result, "Success") ~= nil
end

function M.navigateTo(url)
  return cdp_wrapper.navigateTo(url)
end

function M.tabCount()
  local targets = cdp_wrapper.targets()
  if not targets then
    return 0
  end
  local count = 0
  for _, target in ipairs(targets) do
    if target.type == "page" then
      count = count + 1
    end
  end
  return count
end

function M.closeTab(id)
  return cdp_wrapper.closePage(id)
end

function M.reloadTab()
  return cdp_wrapper.reloadPage()
end

function M.tabInfo()
  local result = {}
  local targets = cdp_wrapper.targets()
  if targets then
    for _, target in ipairs(targets) do
      if target.type == "page" then
        table.insert(result, {
          id = target.targetId,
          title = target.title,
          url = target.url
        })
      end
    end
  end
  return result
end

function M.switchToTab(id)
  return cdp_wrapper.attachTarget(id)
end

function M.captureSnapshot(params)
  return cdp_wrapper.captureSnapshot()
end

function M.cssSelectorFinder(selector)
  return cdp_wrapper.cssSelectorFinder(selector)
end

function M.cssSelectorFinderX(selector)
  return cdp_wrapper.cssSelectorFinderX(selector)
end

function M.shadowRootFinder(...)
  return cdp_wrapper.shadowRootFinder(...)
end

function M.getOuterHTML()
  return cdp_wrapper.getOuterHTML(nil, true)
end

function M.getAccessibilityTree()
  return cdp_wrapper.getFullAXTree()
end

---@return TabInfo
function M.currentTabInfo()
  return cdp_wrapper.currentTabInfo()
end

---------------------------------------------------------------------------
-- Worker 支持
---------------------------------------------------------------------------

function M.listServiceWorkers()
  return cdp_wrapper.serviceWorkerTargets()
end

function M.listAllWorkers()
  return cdp_wrapper.workerTargets()
end

function M.enableServiceWorker()
  return cdp_wrapper.enableServiceWorker()
end

function M.startWorker(scopeURL)
  return cdp_wrapper.startWorker(scopeURL)
end

function M.stopWorker(versionId)
  return cdp_wrapper.stopWorker(versionId)
end

function M.unregisterServiceWorker(scopeURL)
  return cdp_wrapper.unregisterServiceWorker(scopeURL)
end

function M.updateRegistration(scopeURL)
  return cdp_wrapper.updateRegistration(scopeURL)
end

function M.deliverPushMessage(origin, registrationId, data)
  return cdp_wrapper.deliverPushMessage(origin, registrationId, data)
end

function M.dispatchSyncEvent(origin, registrationId, tag, lastChance)
  return cdp_wrapper.dispatchSyncEvent(origin, registrationId, tag, lastChance)
end

function M.dispatchPeriodicSyncEvent(origin, registrationId, tag)
  return cdp_wrapper.dispatchPeriodicSyncEvent(origin, registrationId, tag)
end

function M.attachToWorker(targetId)
  return cdp_wrapper.attachToWorker(targetId)
end

function M.inspectWorker(versionId)
  return cdp_wrapper.inspectWorker(versionId)
end

function M.close()
  return shell.stopApp(packageName)
end

function M.navigateToHistoryEntry(id)
  return cdp_wrapper.navigateToHistoryEntry(id)
end

function M.getNavigationHistory()
  return cdp_wrapper.getNavigationHistory()
end

function M.ensureSwitchToPageWithUrlStartsWith(url, timeout, activatePage)
  return cdp_wrapper.ensureSwitchToPageWithUrlStartsWith(url, timeout, activatePage)
end

return M
