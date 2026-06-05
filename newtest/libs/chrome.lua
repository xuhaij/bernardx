
local ca = require "common_action"

local delegate

if IOS then
  delegate = require "ios.chrome"
else
  delegate = require "android.chrome"
end


function delegate.switchToTabByTitle(title)
  local tabs = delegate.tabInfo()
  for _,tab in ipairs(tabs) do
    if tab.title == title then
      return delegate.switchToTab(tab.id)
    end
  end
  return false
end

function delegate.switchToTabByUrl(url)
  local tabs = delegate.tabInfo()
  for _,tab in ipairs(tabs) do
    if tab.url == url then
      return delegate.switchToTab(tab.id)
    end
  end
  return false
end

function delegate.switchToTabByTitleStartWith(titlePrefix)
  local tabs = delegate.tabInfo()
  for _,tab in ipairs(tabs) do
    if string.sub(tab.title,1,#titlePrefix) == titlePrefix then
      return delegate.switchToTab(tab.id)
    end
  end
  return false
end




---@class TabInfo
---@field id string
---@field title string
---@field url string


function delegate.ensureClassHasWithClick(targetFinder,clz,timeout,responseTime,clickableFinder)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  local actionInterval = ca.randomTime(7000,9000)
  local lastFindTime = 0
  if not clickableFinder then
    clickableFinder = targetFinder
  end
  local clickNode = nil
  local mClz = nil
  while nowTime - startTime < timeout do
    local node = targetFinder:find()
    if not node then
      goto continue
    end
    mClz = node:clz()
    if mClz and string.find(mClz,clz,1,true) then
      return true
    end
    if clickableFinder then
      clickNode = clickableFinder:find()
    else
      clickNode = node
    end
    if not clickNode then
      goto continue
    end
    if lastFindTime == 0 then
      lastFindTime = nowTime
      goto continue
    end
    if nowTime - lastFindTime > responseTime and nowTime - lastActionTime > actionInterval then
      ca.commonClickNode(clickNode)
      lastFindTime = 0
      lastActionTime = nowTime
      actionInterval = ca.randomTime(7000,9000)
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
end

function delegate.ensureClassVanishWithClick(targetFinder,clz,timeout,responseTime,clickableFinder)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  local actionInterval = ca.randomTime(7000,9000)
  local lastFindTime = 0
  if not  clickableFinder then
    clickableFinder = targetFinder
  end
  local clickNode = nil
  local mClz = nil
  while nowTime - startTime < timeout do
    local node = targetFinder:find()
    if not node then
      goto continue
    end
    mClz = node:clz()
    if mClz and not string.find(mClz,clz,1,true) then
      return true
    end
    if clickableFinder then
      clickNode = clickableFinder:find()
    else
      clickNode = node
    end
    if not clickNode then
      goto continue
    end
    if lastFindTime == 0 then
      lastFindTime = nowTime
      goto continue
    end
    if nowTime - lastFindTime > responseTime and nowTime - lastActionTime > actionInterval then
      ca.commonClickNode(clickNode)
      lastFindTime = 0
      lastActionTime = nowTime
      actionInterval = ca.randomTime(7000,9000)
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
end




return delegate