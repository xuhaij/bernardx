
local M = {}
local json = require "dkjson"
local class = require "class"


---@class ChromeVersionInfo
---@field Browser string
---@field Protocol-Version string
---@field User-Agent string
---@field V8-Version string
---@field WebKit-Version string
---@field webSocketDebuggerUrl string

---获取浏览器版本信息
---@return ChromeVersionInfo|nil
local function getVersionInfo()
  local url = "http://127.0.0.1:9002/json/version"
  local status,response = http.request{ url = url ,method="GET"}
  if status ~= 200 then
    return nil
  end
  local json = json.decode(response)
  ---@type ChromeVersionInfo
  return json
end

---@param session CDPSession
---@param methodName string
---@param params table|nil
---@param sessionId string|nil
---@return table|nil
local function sessionCall(session,methodName,params,sessionId)
  local state,result = session:call(methodName,params,sessionId)
  if not state then 
    return nil
  end
---@diagnostic disable-next-line: unused-function, return-type-mismatch
  return result
end

---@class VisualViewport
---@field clientWidth number
---@field clientHeight number
---@field pageX number
---@field paageY number
---@field offsetX number
---@field offsetY number

---@class LayoutViewport
---@field clientWidth number
---@field clientHeight number
---@field pageX number
---@field paageY number

---@class ContentSize
---@field x integer
---@field y integer
---@field widht integer
---@field height integer

---@class LayoutMetrics
---@field layoutViewport LayoutViewport
---@field visualViewport VisualViewport
---@field contentSize ContentSize
---@field cssLayoutViewport LayoutViewport
---@field cssVisualViewport VisualViewport
---@field cssContenSize ContentSize


---@alias Quad integer[]

---@class BoxModel
---@field content Quad
---@field padding Quad
---@field border Quad
---@field margin Quad
---@field width integer
---@field height integer

---@class NodeInfo
---@field nodeType string
---@field nodeValue string
---@field nodeName string 
---@field localName string
---@field childNodeCount string
---@field name string
---@field value string
---@field attributes table
---@field publicId string
---@field systemId string
---@field isSVG string
---@field parentId integer


---@class ChromeSession
local ChromeSession = class.new("ChromeSession")

---@param session CDPSession
---@param sessionId string
---@param targetId string
function ChromeSession:ctor(session,sessionId,targetId,notificationBarHeight)
  self._session = session
  self._sessionId = sessionId
  self._targetId = targetId
  self._notificationBarHeight = notificationBarHeight
end

function ChromeSession:disconnect()
  self._session:call("Target.detachFromTarget",{sessionId=self._sessionId,targetId=self._targetId})
end

function ChromeSession:__gc()
  self:disconnect()
end

function ChromeSession:call(methodName,params)
  return sessionCall(self._session,methodName,params,self._sessionId)
end

function ChromeSession:eval(expression)
  local result = self:call("Runtime.evaluate",{expression=expression,returnByValue=true})
  if result then
    return result.result.value
  end
end

---@return LayoutMetrics|nil
function ChromeSession:getLayoutMetrics()
  return self:call("Page.getLayoutMetrics")
end

function ChromeSession:getDocument(depth)
  local result = self:call("DOM.getDocument",{pierce = true,depth = depth or -1})
  if not result then
    return
  end
  return result.root
end


function ChromeSession:getFullAXTree()
  local result = self:call("Accessibility.getFullAXTree")
  if result then
    return result.nodes
  end
end

function ChromeSession:queryAXTree(params)
  local result = self:call("Accessibility.queryAXTree",params)
  if result then
    return result.nodes
  end
end

function ChromeSession:getPartialAXTree(params)
  local result = self:call("Accessibility.getPartialAXTree",params)
  if result then
    return result.nodes
  end
end

function ChromeSession:pushNodesByBackendIdsToFrontend(nodeIds)
  local result = self:call("DOM.pushNodesByBackendIdsToFrontend",{backendNodeIds=nodeIds})
  if result then
    return result.nodeIds
  end
end

---根据css选择器查找节点，返回节点id
---@param selector string
---@return integer|nil
function ChromeSession:find(selector,rootId)
  if not rootId then
    rootId = self:getRootNodeId()
  end
  if not rootId then
    logw("CDP","get document failed")
    return
  end
  -- logd("CDP","root id",rootId)
  local result = self:call("DOM.querySelector",{nodeId=rootId,selector=selector})
  if result then
    if result.nodeId ~= 0 then
      return result.nodeId
    end
  end
end

---根据css选择器查找节点，返回所有找到的节点id
---@param selector string
---@return integer[]|nil
function ChromeSession:finds(selector,rootId)
  if not rootId then
    rootId = self:getRootNodeId()
  end
  if not rootId then
    logw("CDP","get document failed")
    return
  end
  local result = self:call("DOM.querySelectorAll",{nodeId=rootId,selector=selector})
  if result then
    return result.nodeIds
  end
end

---@return BoxModel|nil
function ChromeSession:getBoxModel(nodeId)
  local result = self:call("DOM.getBoxModel",{nodeId=nodeId})
  if result then
    return result.model
  end
end

function ChromeSession:getRootNodeId()
  local document = self:getDocument(1)
  return document and document.nodeId
end

function ChromeSession:getOuterHTML(nodeId,includeShadowDOM)
  if not nodeId then
    nodeId = self:getRootNodeId()
  end
  local result = self:call("DOM.getOuterHTML",{nodeId=nodeId,includeShadowDOM=includeShadowDOM})
  if result then
    return result.outerHTML
  end
end

function ChromeSession:callFunctionOn(params)
  local result = self:call("Runtime.callFunctionOn",params)
  if result then
    return result.result
  end
end

---重新加载当前页面
function ChromeSession:reloadPage()
  local result = self:call("Page.reload")
  if result then
    return true
  end
  return false
end


function ChromeSession:resolveNode(nodeId)
  local result = self:call("DOM.resolveNode",{nodeId=nodeId})
  if result then
    return result.object
  end
end

---@class DescribeNode
---@field nodeId integer
---@field nodeType string
---@field nodeName string
---@field contentDocument DescribeNode|nil

---@return DescribeNode|nil
function ChromeSession:describeNode(nodeId)
  local result = self:call("DOM.describeNode",{nodeId=nodeId})
  if result then
    return result.node
  end
end

function ChromeSession:networkEnable()
  local result = self:call("Network.enable")
  if result then
    return true
  end
  return false
end

---@param quad  Quad
local function quad2Scope(quad)
  local x,y = quad[1],quad[2]
  local x1,y1 = quad[5],quad[6]
  return x,y,x1,y1
end

local toolbarFinder = By.res("org.chromium.chrome:id/toolbar")

function ChromeSession:parentNodeId(nodeId)
  local nodeInfo = self:getNodeInfo(nodeId)
  if not nodeInfo then
    print("get node info failed for nodeId",nodeId)
    return
  end
  if nodeInfo.parentId then
    return nodeInfo.parentId
  end
  local jsObject = self:resolveNode(nodeId)
  if not jsObject then
    return
  end

  local object = self:callFunctionOn{
    objectId = jsObject.objectId,
    functionDeclaration = [[
      function() {
        return this.parentNode;
      }
    ]],
    returnByValue = false
  }
  if not object then
    return
  end
  local r = self:call("DOM.requestNode",{objectId = object.objectId})
  if r then
    return r.nodeId
  end
end

function ChromeSession:tryGetBoxModel(nodeId)
  local boxModel = self:getBoxModel(nodeId)
  if boxModel then
    return boxModel
  end
  local parentId = self:parentNodeId(nodeId)
  if not parentId then
    return 
  end
  return self:getBoxModel(parentId)
end

---获取到节点的范围，x1,y1,x2,y2 可能为负数或者超出屏幕范围，需要进一步处理和判断
function ChromeSession:getNodeBound(nodeId)
  local layoutMetrics = self:getLayoutMetrics()
  if not layoutMetrics then
    logd("CDP","get layout metrics failed")
    return
  end
  local boxModel = self:tryGetBoxModel(nodeId)
  if not boxModel then
    logd("CDP","get box model failed")
    return
  end
  local node = toolbarFinder:find()
  local yShift = 0
  if node then
    _,_,_, yShift = node:visibleBounds()
    yShift = yShift -1
  else
    yShift = self._notificationBarHeight -1
  end
  -- local screenWidth,screenHeight = Display:getSize()
  -- local yShift = screenHeight - layoutMetrics.visualViewport.clientHeight - self._navigationBarHeight
  local xShift = 0
  local n = math.floor((layoutMetrics.visualViewport.clientWidth/layoutMetrics.cssVisualViewport.clientWidth)*10000)
  local n1 = n %10
  n = n //10
  if n1 >= 5 then
    n = n + 1
  end
  local dpr = n /1000
  local scope = boxModel.content
  if math.abs(scope[8] - scope[2]) <= 2 then
    scope = boxModel.border
  end
  local cx1,cy1,cx2,cy2 = quad2Scope(scope)
  local x = math.floor(cx1*dpr+xShift) 
  local y = math.floor(cy1*dpr+yShift) 
  local x1 = math.floor(cx2*dpr+xShift) 
  local y1 = math.floor(cy2*dpr+yShift) 
  if x< 0 then
    x = 0
  end
  if y < 0 then
    y = 0
  end
  return x,y,x1,y1
end

---获取到节点的信息
---@return NodeInfo|nil
function ChromeSession:getNodeInfo(nodeId)
  local result = self:call("DOM.describeNode",{nodeId=nodeId})
  if not result then
    return
  end
  local node = result.node
  local attributes = {}
  local oldAttributes = node.attributes
  for i = 1, #oldAttributes,2 do
    attributes[oldAttributes[i]] = oldAttributes[i+1]
  end
  node.attributes = attributes
  return node
end

---获取到节点输入框的输入值
---@param nodeId integer
---@return string|nil
function ChromeSession:getInputValue(nodeId)
  local nodeObject = self:resolveNode(nodeId)
  if not nodeObject then
    return
  end
  local func = [[
    function () {
      return {
        value: this.value
      }
    }
  ]]
  local result = self:callFunctionOn  {
    objectId=nodeObject.objectId,
    functionDeclaration=func,
    returnByValue=true
  }
  if result then
    return result.value.value
  end
end

---导航到指定url
---@param url string
---@return boolean
function ChromeSession:pageNavigate(url)
  local result = self:call("Page.navigate",{url=url})
  if result then
    return true
  end
  return false
end

function ChromeSession:captureSnapshot()
  local result = self:call("DOMSnapshot.captureSnapshot",{
    computedStyles = {'display', 'visibility', 'opacity', 'position'},
    includeDOMRects = true,
    includeBlendedBackgroundColors = false,
    includeTextColorOpacities = false
  })
  if result then
    return result
  end
end


---@class NavigationEntry
---@field id integer
---@field url string
---@field title string
---@field transitionType string
---@field userTypedURL string

---@class GetNavigationHistoryResult
---@field entries NavigationEntry[]
---@field currentIndex integer


---@return GetNavigationHistoryResult|nil
function ChromeSession:getNavigationHistory()
  local result = self:call("Page.getNavigationHistory")
  return result
end

function ChromeSession:navigateToHistoryEntry(entryId)
  local result = self:call("Page.navigateToHistoryEntry",{entryId=entryId})
  return true
end


---@class ChromeBrowser
local ChromeBrowser = class.new("ChromeBrowser")

---@param session CDPSession
---@param versionInfo ChromeVersionInfo
function ChromeBrowser:ctor(session,versionInfo,notificationBarHeight)
  self._versionInfo = versionInfo
  self._session = session
  self._notificationBarHeight = notificationBarHeight
end

---@class BrowserTargetInfo
---@field targetId string
---@field browserContextId string
---@field attached boolean
---@field title string
---@field url string
---@field type "page"|"frame"

---获取当前浏览器所有目标信息，包括页面和frame
---@return BrowserTargetInfo[]
function ChromeBrowser:targets()
  local result = sessionCall(self._session,"Target.getTargets")
  if result then
    return result.targetInfos
  end
  return {}
end

---连接到指定目标，比如页面
---@param targetId string
---@return ChromeSession|nil
function ChromeBrowser:attachTarget(targetId)
  local result = sessionCall(self._session,"Target.attachToTarget",{targetId=targetId,flatten=true})
  if result then
    return class.instance(ChromeSession,self._session,result.sessionId,targetId,self._notificationBarHeight)
  end
  return nil
end

function ChromeBrowser:networkStats()
---@diagnostic disable-next-line: undefined-field
  return self._session:networkStats()
end

---如果是页目标时，会将页目标切换到当前页
---@param targetId string
---@return boolean
function ChromeBrowser:activateTarget(targetId)
  local result = sessionCall(self._session,"Target.activateTarget",{targetId=targetId})
  return result and true or false
end

---关闭指定目标，如果是页的话页会关闭tab页
---@param targetId string
---@return boolean
function ChromeBrowser:closeTarget(targetId)
  local result = sessionCall(self._session,"Target.closeTarget",{targetId=targetId})
  if result then
    return true
  end
  return false
end



---@class CDPSession
---@field connect fun(self:CDPSession):boolean
---@field disconnect fun(self:CDPSession):boolean
---@field call fun(self:CDPSession,method:string,params?:table,sessionId?:string):any
---@field networkStats fun(self:CDPSession):integer,integer,integer

---获取所有 Service Worker 目标
---@return BrowserTargetInfo[]
function ChromeBrowser:serviceWorkerTargets()
  local targets = self:targets()
  local workers = {}
  for _, target in ipairs(targets) do
    if target.type == "service_worker" then
      table.insert(workers, target)
    end
  end
  return workers
end

---获取所有 Worker 目标（service_worker + worker + shared_worker）
---@return BrowserTargetInfo[]
function ChromeBrowser:workerTargets()
  local targets = self:targets()
  local workers = {}
  for _, target in ipairs(targets) do
    if target.type == "service_worker" or target.type == "worker" or target.type == "shared_worker" then
      table.insert(workers, target)
    end
  end
  return workers
end

---连接到 Service Worker 目标
---@param targetId string
---@return ChromeSession|nil
function ChromeBrowser:attachToWorker(targetId)
  return self:attachTarget(targetId)
end

---ServiceWorker.enable
function ChromeBrowser:enableServiceWorker()
  return sessionCall(self._session, "ServiceWorker.enable")
end

---ServiceWorker.disable
function ChromeBrowser:disableServiceWorker()
  return sessionCall(self._session, "ServiceWorker.disable")
end

---启动 Service Worker
---@param scopeURL string
---@return boolean
function ChromeBrowser:startWorker(scopeURL)
  local result = sessionCall(self._session, "ServiceWorker.startWorker", { scopeURL = scopeURL })
  return result ~= nil
end

---停止 Service Worker
---@param versionId string
---@return boolean
function ChromeBrowser:stopWorker(versionId)
  local result = sessionCall(self._session, "ServiceWorker.stopWorker", { versionId = versionId })
  return result ~= nil
end

---跳过等待，立即激活 worker
---@param scopeURL string
---@return boolean
function ChromeBrowser:skipWaiting(scopeURL)
  local result = sessionCall(self._session, "ServiceWorker.skipWaiting", { scopeURL = scopeURL })
  return result ~= nil
end

---注销 Service Worker 注册
---@param scopeURL string
---@return boolean
function ChromeBrowser:unregisterServiceWorker(scopeURL)
  local result = sessionCall(self._session, "ServiceWorker.unregister", { scopeURL = scopeURL })
  return result ~= nil
end

---更新 Service Worker 注册（重新下载脚本）
---@param scopeURL string
---@return boolean
function ChromeBrowser:updateRegistration(scopeURL)
  local result = sessionCall(self._session, "ServiceWorker.updateRegistration", { scopeURL = scopeURL })
  return result ~= nil
end

---向 Service Worker 投递推送消息
---@param origin string
---@param registrationId string
---@param data string base64-encoded data
---@return boolean
function ChromeBrowser:deliverPushMessage(origin, registrationId, data)
  local result = sessionCall(self._session, "ServiceWorker.deliverPushMessage", {
    origin = origin,
    registrationId = registrationId,
    data = data,
  })
  return result ~= nil
end

---向 Service Worker 投递后台同步事件
---@param origin string
---@param registrationId string
---@param tag string
---@param lastChance boolean
---@return boolean
function ChromeBrowser:dispatchSyncEvent(origin, registrationId, tag, lastChance)
  local result = sessionCall(self._session, "ServiceWorker.dispatchSyncEvent", {
    origin = origin,
    registrationId = registrationId,
    tag = tag,
    lastChance = lastChance or false,
  })
  return result ~= nil
end

---向 Service Worker 投递定期后台同步事件
---@param origin string
---@param registrationId string
---@param tag string
---@return boolean
function ChromeBrowser:dispatchPeriodicSyncEvent(origin, registrationId, tag)
  local result = sessionCall(self._session, "ServiceWorker.dispatchPeriodicSyncEvent", {
    origin = origin,
    registrationId = registrationId,
    tag = tag,
  })
  return result ~= nil
end

---在 Chrome DevTools 中检查 Service Worker
---@param versionId string
---@return boolean
function ChromeBrowser:inspectWorker(versionId)
  local result = sessionCall(self._session, "ServiceWorker.inspectWorker", { versionId = versionId })
  return result ~= nil
end

---连接到浏览器，确保浏览器已经打开
---@return ChromeBrowser|nil
function M.connect()
  local versionInfo = getVersionInfo()
  if not versionInfo then
    logw("CDP","get version info fail")
    return
  end
  local session = CDP.newSession()
  local result,err = session:connect(versionInfo.webSocketDebuggerUrl)
  if not result then
    logw("CDP","connect driver fail",err) 
    return
  end
  if ENGINE_VERSION >= 76 then
    Nd.findOtherWindows(true)
  end
  local finder = By.pkg("com.android.systemui")
  local notificationBarHeight = 0
  local nodes = finder:finds()
  if nodes and #nodes > 0 then
    for _,node in ipairs(nodes) do
      if node:res() ~="com.android.systemui:id/navigation_bar_frame" and node:index() == 0 and node:depth() == 0 then
        _,_,_,notificationBarHeight = node:bounds()
        break
      end
    end
  end
  if ENGINE_VERSION >= 76 then
    Nd.findOtherWindows(false)
  end
  logd("CDP","notificationBarHeight",notificationBarHeight)
  return class.instance(ChromeBrowser,session,versionInfo,notificationBarHeight)
end


M.getVersionInfo = getVersionInfo


return M