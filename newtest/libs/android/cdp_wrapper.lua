
local M = {}


local cdp = require "android.cdp"
local class = require "class"

---@type ChromeBrowser
local browser_session_ = nil

---@type ChromeSession
local session_ = nil

---@type ChromeSession worker session (set via attachToWorker)
local worker_session_ = nil

---@type BrowserTargetInfo
local now_window_info_ = nil

local function init()
  local session = cdp.connect()
  if not session then
    return false
  end
  browser_session_ = session
  return true
end

function M.ensureInit(timeout)
  timeout = timeout or 10000
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  while nowTime - startTime < timeout do
    if init() then
      return true
    end
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

---@param targetId string
local function attachTargetById(targetId,activatePage)
  local session = browser_session_:attachTarget(targetId)
  if not session then
    logw("attachTargetById failed")
    return false
  end
  session_ = session
  if activatePage then
    browser_session_:activateTarget(targetId)
  end
  local targets = browser_session_:targets()
  for _,target in ipairs(targets) do
    if target.targetId == targetId then
      now_window_info_ = target
      logd("attachTargetById success",target.title,target.targetId,target.url)
      return true
    end
  end
  logw("attachTargetById failed don't find target info after attach",targetId)
  return false
end

---@param targetInfo BrowserTargetInfo
---@param activatePage boolean
---@return boolean
local function attachTarget(targetInfo,activatePage)
  local session = browser_session_:attachTarget(targetInfo.targetId)
  if not session then
    logw("attachTarget failed")
    return false
  end
  session_ = session
  if activatePage then
    browser_session_:activateTarget(targetInfo.targetId)
  end
  now_window_info_ = targetInfo
  logd("switchToPageWithTitle success",targetInfo.title,targetInfo.targetId,targetInfo.url)
  return true
end

function M.switchToPageWithTitle(title,activatePage)
  local targets = browser_session_:targets()
  for _,target in ipairs(targets) do
    if target.type == "page" and target.title == title then
      return attachTarget(target,activatePage)
    end
  end
  return false
end

local function switchToPageWithUrlStartsWith(url,activatePage)
  local targets = browser_session_:targets()
  for _,target in ipairs(targets) do
    if target.type == "page" and string.find(target.url,url,1,true) == 1 then
      return attachTarget(target,activatePage)
    end
  end
  return false
end

M.switchToPageWithUrlStartsWith = switchToPageWithUrlStartsWith

function M.ensureSwitchToPageWithUrlStartsWith(url,timeout,activatePage)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  while nowTime - startTime < timeout do
    if switchToPageWithUrlStartsWith(url,activatePage) then
      return true
    end
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

function M.targets()
  return browser_session_:targets()
end

function M.switchToFirstPage()
  local targets = browser_session_:targets()
  for _,target in ipairs(targets) do
    if target.type == "page" then
      return attachTarget(target,true)
    end
  end
  return false
end

function M.attachTarget(id)
  return attachTargetById(id,true)
end

function M.currentWindowInfo()
  return now_window_info_
end

function M.currentSession()
  return session_
end

function M.currentTabInfo()
  return {
    id = now_window_info_ and now_window_info_.targetId or nil,
    title = now_window_info_ and now_window_info_.title or nil,
    url = now_window_info_ and now_window_info_.url or nil
  }
end

function M.captureSnapshot()
  if session_ then
    return session_:captureSnapshot()
  end
  logw("captureSnapshot failed don't have session")
  return nil
end

function M.getFullAXTree()
  if session_ then
    return session_:getFullAXTree()
  end
  logw("getFullAXTree failed don't have session")
  return nil
end

function M.getPartialAXTree(params)
  if session_ then
    return session_:getPartialAXTree(params)
  end
  logw("getPartialAXTree failed don't have session")
  return nil
end

function M.getDocument(depth)
  if session_ then
    return session_:getDocument(depth)
  end
  logw("getDocument failed don't have session")
  return nil
end

function M.getOuterHTML(nodeId,includeShadowDOM)
  if session_ then
    return session_:getOuterHTML(nodeId,includeShadowDOM)
  end
  logw("getOuterHTML failed don't have session")
  return nil
end



function M.navigateTo(url)
  if session_ then
    return session_:pageNavigate(url)
  end
  logw("navigateTo failed don't have session")
  return false
end

function M.getNavigationHistory()
  if session_ then
    return session_:getNavigationHistory()
  end
  logw("getNavigationHistory failed don't have session")
  return nil
end

function M.navigateToHistoryEntry(entryId)
  if session_ then
    return session_:navigateToHistoryEntry(entryId)
  end
  logw("navigateToHistoryEntry failed don't have session")
  return false
end

function M.closePage(id)
  if not session_ then
    logw("closePage failed don't have session")
    return false
  end
  
  if not now_window_info_ or now_window_info_.type ~= "page" then
    logw("closePage failed don't have page window info or window info is not page")
    return false
  end
  if not id then
    id = now_window_info_.targetId
  end
  
  return browser_session_:closeTarget(id)
end

function M.reloadPage()
  if not session_ then
    logw("reloadPage failed don't have session")
    return false
  end
  return session_:reloadPage()
end

function M.networkStats()
  if not session_ then
    logw("networkStats failed don't have session")
    return nil
  end
  return browser_session_:networkStats()
end

function M.networkEnable()
  if not session_ then
    logw("networkEnable failed don't have session")
    return false
  end
  return session_:networkEnable()
end

---@class BrowserRemoteObject
---@field objectId string
---@field type string
---@field subtype string
---@field className string
---@field description string



---@class BrowserNode
---@field _remoteObject BrowserRemoteObject
local BrowserNode = class.new("BrowserNode")

---@param session ChromeSession
---@param nodeId integer
function BrowserNode:ctor(session,nodeId)
  self._session = session
  self._nodeId = nodeId
end

function BrowserNode:visibleBounds()
  return self._session:getNodeBound(self._nodeId)
end

function BrowserNode:axNode()
  local axNodes = self._session:queryAXTree {
    nodeId = self._nodeId,
    fetchRelatives = false
  }
  if axNodes and #axNodes > 0 then
    return axNodes[1]
  end
end

function BrowserNode:visible()
  local axNode = self:axNode()
  if not axNode then
    return false
  end
  if axNode.ignored or axNode.invisible or axNode.offscreen or axNode.role.value == "none" then
    return false
  end

  local x1,y1,x2,y2 = self:visibleBounds()
  if not x1 or not y1 or not x2 or not y2 then
    return false
  end
  local w,h = Display:getSize()
  return x1 >= 0 or y1 >=0 or x2 < w or y2 < h
end

function BrowserNode:ensureObject()
  local remoteObject = self._remoteObject
  if remoteObject then
    return remoteObject
  end
  remoteObject = self._session:resolveNode(self._nodeId)
  if not remoteObject then
    logw("ensureObject failed don't have remote object")
    return nil
  end
  self._remoteObject = remoteObject
  return remoteObject
end

function BrowserNode:focused()
  local func = [[
    function () {
      return {
        focused: document.activeElement === this
      }
    }
  ]]
  local object = self:ensureObject()

  if not object then
    return false
  end
  local objectId = object.objectId
  if not objectId then
    return false
  end
  local result = self._session:callFunctionOn  {
    objectId=objectId,
    functionDeclaration=func,
    returnByValue=true
  }
  if result then
    return result.value.focused
  end
  return false
end

local function getHtmlText(outerHTML)
  local result = string.match(outerHTML,"^%s*(<.+>)%s*$")
  result = string.gsub(result,"%s*\n%s*","")
  result = string.gsub(result,"\t","")
  result = string.gsub(result,"%b<>",function(match)
    if string.find(match,"^<br%s*/?>",1) then
      return "\n"
    end
    return ""
  end)
  return result
end

function BrowserNode:rawText()
  local outerHTML = self._session:getOuterHTML(self._nodeId)
  if not outerHTML then
    return
  end
  return getHtmlText(outerHTML)
end

function BrowserNode:res()
  local outerHTML = self._session:getOuterHTML(self._nodeId)
  if not outerHTML then
    return
  end
  local id = string.match(outerHTML,[[id=['"]([%w_-]+)['"] ?]])

  return id
end

function BrowserNode:clz()
  local outerHTML = self._session:getOuterHTML(self._nodeId)
  if not outerHTML then
    return
  end
  -- print(outerHTML)
  local clz = string.match(outerHTML,[[class=['"]([%w%s_-]*)['"] ?]])
  return clz
end

function BrowserNode:selectText()
  local func = [[
    function () {
      const selectedOption = this.options[this.selectedIndex];
      return selectedOption ? selectedOption.text : '';
    }
  ]]
  local object = self:ensureObject()
  if not object then
    return
  end
  local result = self._session:callFunctionOn  {
    objectId=object.objectId,
    functionDeclaration=func,
    returnByValue=true
  }
  if result then
    return result.value
  end
end

function BrowserNode:valueText()
  local func = [[
    function () {
      return this.value
    }
  ]]
  local object = self:ensureObject()
  if not object then
    return
  end
  local result = self._session:callFunctionOn  {
    objectId=object.objectId,
    functionDeclaration=func,
    returnByValue=true
  }
  if result then
    return result.value
  end
end

function BrowserNode:text()
  local object = self:ensureObject()
  if not object then
    return
  end

  if object.className == "HTMLSelectElement" then
    return self:selectText()
  elseif object.className == "HTMLInputElement" or object.className == "HTMLTextAreaElement" then
    return self:valueText()
  end
  return self:rawText()
end


function BrowserNode:contentDocumentNodeId()
  local describeNode = self._session:describeNode(self._nodeId)
  if not describeNode then
    logw("iframeId failed don't have describe node")
    return nil
  end
  return describeNode.contentDocument.nodeId
end

function BrowserNode:shadowRootIds()
  local describeNode = self._session:describeNode(self._nodeId)
  if not describeNode then
    logw("shadowRoot failed don't have describe node")
    return nil
  end
  local shadowRoots = describeNode.shadowRoots
  if not shadowRoots then
    logw("shadowRoot failed don't have shadow root")
    return nil
  end
  local ids ={}
  for index, value in ipairs(shadowRoots) do
    ids[index] = value.nodeId
  end
  return ids
end



---@class CssSelectorFinder:UiNodeFilter
local CssSelectorFinder = class.new("CssSelectorFinder")

---@param selector string
---@param session ChromeSession
function CssSelectorFinder:ctor(selector,session)
  self._selector = selector
  self._session = session
end

local function find(session,selector,rootId)
  local nodeId = session:find(selector,rootId)
  if not nodeId then
    return nil
  end
  return class.instance(BrowserNode,session,nodeId)
end

local function finds(session,selector,rootId)
  local nodeIds = session:finds(selector,rootId)
  if not nodeIds then
    return nil
  end
  local nodes = {}
  for _,nodeId in ipairs(nodeIds) do
    table.insert(nodes,class.instance(BrowserNode,session,nodeId))
  end
  return nodes
end

function CssSelectorFinder:find()
  return find(self._session,self._selector)
end

function CssSelectorFinder:finds()
  return finds(self._session,self._selector)
end

---@class ShadowRootFinder:UiNodeFilter
local ShadowRootFinder = class.new("ShadowRootFinder")


function ShadowRootFinder:ctor(session,...)
  self._session = session
  self._selectors = {...}
end

local function getShadowRootIds(session,nodeId)
  local describeNode = session:describeNode(nodeId)
  if not describeNode then
    logw("getShadowRootIds failed don't have describe node")
    return nil
  end
  local shadowRoots = describeNode.shadowRoots
  if not shadowRoots then
    logw("getShadowRootIds failed don't have shadow root")
    return nil
  end
  local ids ={}
  for index, value in ipairs(shadowRoots) do
    ids[index] = value.nodeId
  end
  return ids
end

local function findShadowRoot(session,selectors,index,rootId)
  local selector = selectors[index]
  local nodeId = session:find(selector,rootId)
  if not nodeId then
    return nil
  end
  if index == #selectors then
    return nodeId
  end
  local shadowRootIds = getShadowRootIds(session,nodeId)
  if not shadowRootIds or #shadowRootIds == 0 then
    return nil
  end
  for _,shadowRootId in ipairs(shadowRootIds) do
    local result = findShadowRoot(session,selectors,index + 1,shadowRootId)
    if result then
      return result
    end
  end
end

local function findsShadowRoot(session,selectors,index,rootId)
  local selector = selectors[index]
  local nodeIds = session:finds(selector,rootId)
  if not nodeIds then
    return nil
  end
  if index == #selectors then
    return nodeIds
  end
  local result = {}
  for _,nodeId in ipairs(nodeIds) do
    local shadowRootIds = getShadowRootIds(session,nodeId)
    if shadowRootIds and #shadowRootIds > 0 then
      for _,shadowRootId in ipairs(shadowRootIds) do
        local findResult = findsShadowRoot(session,selectors,index + 1,shadowRootId)
        if findResult then
          for _,id in ipairs(findResult) do
            table.insert(result,id)
          end
        end
      end
    end
  end
  return result
end


function ShadowRootFinder:find(rootId)
  local nodeId = findShadowRoot(self._session,self._selectors,1,rootId)
  if not nodeId then
    return nil
  end
  return class.instance(BrowserNode,self._session,nodeId)
end

function ShadowRootFinder:finds(rootId)
  local nodeIds = findsShadowRoot(self._session,self._selectors,1,rootId)
  if not nodeIds then
    return nil
  end
  local nodes = {}
  for _,nodeId in ipairs(nodeIds) do
    table.insert(nodes,class.instance(BrowserNode,self._session,nodeId))
  end
  return nodes
end


---@class CssSelectorFinderX:UiNodeFilter
local CssSelectorFinderX = class.new("CssSelectorFinderX")


function CssSelectorFinderX:ctor(selector,session)
  self._selector = selector
  self._session = session
end

---@param session ChromeSession
---@param selector string
---@param rootId integer|nil
---@return integer[]|nil
local function findX(session,selector,rootId)
  -- print("findX",selector,rootId)
  local nodeIds = session:finds(selector,rootId)
  if nodeIds and #nodeIds > 0 then
    return nodeIds
  end
  local iframeNodeIds = session:finds("iframe",rootId)
  if not iframeNodeIds or #iframeNodeIds == 0 then
    return nil
  end
  for _,iframeNodeId in ipairs(iframeNodeIds) do
    local describeNode = session:describeNode(iframeNodeId)
    if not describeNode then
      goto continue
    end
    local contentDocumentNodeId = describeNode.contentDocument.nodeId
    if not contentDocumentNodeId then
      goto continue
    end
    local result = findX(session,selector,contentDocumentNodeId)
    if result then
      return result
    end
    ::continue::
  end
end

function CssSelectorFinderX:find()
  local nodeIds = findX(self._session,self._selector)
  if not nodeIds or #nodeIds == 0 then
    return nil
  end
  return class.instance(BrowserNode,self._session,nodeIds[1])
end

function CssSelectorFinderX:finds()
  local nodeIds = findX(self._session,self._selector)
  if not nodeIds or #nodeIds == 0 then
    return nil
  end
  local nodes = {}
  for _,nodeId in ipairs(nodeIds) do
    table.insert(nodes,class.instance(BrowserNode,self._session,nodeId))
  end
  return nodes
end

---@class AXFinder:UiNodeFilter
local AXFinder = class.new("AXFinder")

---@param session ChromeSession
function AXFinder:ctor(role,name,index,session)
  self._role = role
  self._name = name
  self._index = index
  self._session = session
end

function AXFinder:finds()
  local rootId = self._session:getRootNodeId()
  local nodes = self._session:queryAXTree {
    nodeId = rootId,
    role=self._role,
    name=self._name
  }
  if not nodes then
    logw("AXFinder:finds failed don't have ax tree")
    return nil
  end
  local ids = {}
  for index,node in ipairs(nodes) do
    ids[index] = node.backendDOMNodeId
  end
  ids = self._session:pushNodesByBackendIdsToFrontend(ids)
  if not ids then
    return
  end
  local result = {}
  for index,nodeId in ipairs(ids) do
    table.insert(result,class.instance(BrowserNode,self._session,nodeId))
  end
  return result
end

function AXFinder:find()
  local rootId = self._session:getRootNodeId()
  local nodes = self._session:queryAXTree {
    nodeId = rootId,
    role=self._role,
    accessibleName=self._name
  }
  if not nodes then
    logw("AXFinder:finds failed don't have ax tree")
    return nil
  end
  local index = self._index or 1
  local node = nodes[index]
  if not node then
    return nil
  end
  local nodeIds = self._session:pushNodesByBackendIdsToFrontend({node.backendDOMNodeId})
  if not nodeIds or #nodeIds == 0 then
    return nil
  end
  return class.instance(BrowserNode,self._session,nodeIds[1])
end


function M.cssSelectorFinder(selector)
  -- assert(session_, "have session")
  return class.instance(CssSelectorFinder,selector,session_)
end

function M.cssSelectorFinderX(selector)
  assert(session_, "have session")
  return class.instance(CssSelectorFinderX,selector,session_)
end

---@param role string
---@param name string|nil
---@param index integer|nil
function M.AXFinder(role,name,index)
  assert(session_, "don't have session")
  return class.instance(AXFinder,role,name,index,session_)
end


function M.find(selector,rootId)
  return find(session_,selector,rootId)
end

function M.finds(selector,rootId)
  return finds(session_,selector,rootId)
end

function M.shadowRootFinder(...)
  -- assert(session_, "don't have session")
  return class.instance(ShadowRootFinder, session_, ...)
end



-- 获取所有的<page>页面
---@deprecated 使用chrome 下 tabInfo 函数
---@returns BrowserTargetInfo[]
function M.getAllPages()
  local targets = browser_session_:targets()
  local pages = {}
  for _, target in ipairs(targets) do
    if target.type == "page" then
      table.insert(pages, target)
    end
  end
  return pages
end


-- 获取所有的<page>页面的 title
---@deprecated 使用chrome 下 tabInfo 函数
---@returns string[]
function M.getAllPageTitles()
  local targets = browser_session_:targets()
  local pageTitle = {}
  for _, target in ipairs(targets) do
    if target.type == "page" then
      table.insert(pageTitle, target.title)
    end
  end
  return pageTitle
end


-- 通过 targetId 获取对应的 url
---@deprecated 使用 chrome 下 tabInfo 函数
---@param targetId string
function M.getUrlByTargetId(targetId)
  local targets = browser_session_:targets()
  for _, item in ipairs(targets) do
    if item.targetId == targetId then
      return item.url or nil
    end
  end
  return nil
end

---@deprecated 使用 chrome 下 ensureClassHasWithClick
function M.ensureClassHasWithClick(targetFinder, clz, timeout, responseTime, clickableFinder)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  local actionInterval = ca.randomTime(7000, 9000)
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
    if mClz and type(mClz) == "string" and string.find(mClz, clz, 1, true) then
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
      actionInterval = ca.randomTime(7000, 9000)
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
end

---@deprecated 使用 chrome 下 tabInfo 函数
function M.getFirstPageInfo()
  local targets = browser_session_:targets()
  for _, target in ipairs(targets) do
    if target.type == "page" then
      return target
    end
  end
  return nil
end

-- 获取所有page页面的title和url
---@deprecated 使用 chrome 下 tabInfo 函数
---@returns table[]  返回格式: {{title="xxx", url="xxx"}, ...}
function M.getAllPageTitleAndUrl()
  local targets = browser_session_:targets()
  local pageInfo = {}
  for _, target in ipairs(targets) do
    if target.type == "page" then
      table.insert(pageInfo, {
        title = target.title,
        url = target.url
      })
    end
  end
  return pageInfo
end

---@deprecated 使用 chrome 下 ensureClassVanishWithClick
function M.ensureClassVanishWithClick(targetFinder, clz, timeout, responseTime, clickableFinder)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  local actionInterval = ca.randomTime(7000, 9000)
  local lastFindTime = 0
  if not clickableFinder then
    clickableFinder = targetFinder
  end
  local clickNode = nil
  local mClz = nil
  while nowTime - startTime < timeout do
    local node = targetFinder:find()
    if not node then
      print("ensureClassVanishWithClick: node not found")
      goto continue
    end
    mClz = node:clz()
    print("ensureClassVanishWithClick:", mClz, clz)
    if mClz and not string.find(mClz, clz, 1, true) then
      return true
    end
    if clickableFinder then
      clickNode = clickableFinder:find()
    else
      clickNode = node
    end
    if not clickNode then
      print("ensureClassVanishWithClick: clickNode not found")
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
      actionInterval = ca.randomTime(7000, 9000)
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
end



-- 根据pageTitle，切换到对应的<page>页面
---@param pageTitle string
---@returns string[]
---@deprecated
function M.switchByPageTitle(pageTitle)
  local targets = browser_session_:targets()
  for _, target in ipairs(targets) do
    if target.type == "page" and string.find(target.title, pageTitle, 1, true) then
      logd("根据pageTitle，切换到对应的<page>页面", json.encode(target))
      return attachTarget(target, true)
    end
  end
  return true
end


function M.eval(expression)
  assert(session_, "don't have session")
  return session_:eval(expression)
end

---------------------------------------------------------------------------
-- Worker 支持
---------------------------------------------------------------------------

---获取所有 Service Worker 目标
---@return BrowserTargetInfo[]
function M.serviceWorkerTargets()
  return browser_session_:serviceWorkerTargets()
end

---获取所有 Worker 目标（service_worker + worker + shared_worker）
---@return BrowserTargetInfo[]
function M.workerTargets()
  return browser_session_:workerTargets()
end

---连接到 Worker 目标并开始控制
---@param targetId string
---@return ChromeSession|nil
function M.attachToWorker(targetId)
  assert(browser_session_, "browser_session not initialized")
  local session = browser_session_:attachToWorker(targetId)
  if session then
    worker_session_ = session
  end
  return session
end

---ServiceWorker.enable
---@return boolean
function M.enableServiceWorker()
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:enableServiceWorker() ~= nil
end

---ServiceWorker.disable
---@return boolean
function M.disableServiceWorker()
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:disableServiceWorker() ~= nil
end

---启动 Service Worker
---@param scopeURL string
---@return boolean
function M.startWorker(scopeURL)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:startWorker(scopeURL)
end

---停止 Service Worker
---@param versionId string
---@return boolean
function M.stopWorker(versionId)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:stopWorker(versionId)
end

---跳过等待，立即激活 worker
---@param scopeURL string
---@return boolean
function M.skipWaiting(scopeURL)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:skipWaiting(scopeURL)
end

---注销 Service Worker 注册
---@param scopeURL string
---@return boolean
function M.unregisterServiceWorker(scopeURL)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:unregisterServiceWorker(scopeURL)
end

---更新 Service Worker 注册
---@param scopeURL string
---@return boolean
function M.updateRegistration(scopeURL)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:updateRegistration(scopeURL)
end

---向 Service Worker 投递推送消息
---@param origin string
---@param registrationId string
---@param data string base64-encoded data
---@return boolean
function M.deliverPushMessage(origin, registrationId, data)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:deliverPushMessage(origin, registrationId, data)
end

---向 Service Worker 投递后台同步事件
---@param origin string
---@param registrationId string
---@param tag string
---@param lastChance boolean
---@return boolean
function M.dispatchSyncEvent(origin, registrationId, tag, lastChance)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:dispatchSyncEvent(origin, registrationId, tag, lastChance)
end

---向 Service Worker 投递定期后台同步事件
---@param origin string
---@param registrationId string
---@param tag string
---@return boolean
function M.dispatchPeriodicSyncEvent(origin, registrationId, tag)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:dispatchPeriodicSyncEvent(origin, registrationId, tag)
end

---在 Chrome DevTools 中检查 Service Worker
---@param versionId string
---@return boolean
function M.inspectWorker(versionId)
  assert(browser_session_, "browser_session not initialized")
  return browser_session_:inspectWorker(versionId)
end

---获取当前 worker session（通过 attachToWorker 设置）
---@return ChromeSession|nil
function M.currentWorkerSession()
  return worker_session_
end



return M