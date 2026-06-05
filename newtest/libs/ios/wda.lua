
local M = {}

local api = require "ios.api_net"
local class = require "class"
local json = require("dkjson")
local random = require "randomlua"
local base64 = require "base64"

local sleepRandomer = random.gaussian(os.time())
local format = string.format

local function wdaPort()
---@diagnostic disable-next-line: undefined-global
  return WDA_PORT
end

---@class WDASessionConfig
---@field bundleId string?
---@field initialUrl string?


---@param config WDASessionConfig?
local function newSessionId(config)
  local payload = {
    capabilities = {
      alwaysMatch = config or {}
    }
  }
  local status,response = api.post(
    wdaPort(),
    "session",
    payload
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result["value"]["sessionId"]
  end
end

---@class WDASession
local Session = class.new("WDASession")

function Session:ctor(sessionId,displayScale)
  self._sessionId = sessionId
  self._displayScale = displayScale
end

local function sendTouchEvents(sessionId,actions)
  local payload = {
    actions = {
      {
        type = "pointer",
        id = "finger1",
        parameters = {pointerType = "touch"},
        actions = actions
      }
    }
  }
  local status = api.post(
    wdaPort(),
    format("session/%s/actions",sessionId),
    payload
  )
  return status == 200
end


---@class WDADeviceInfo
---@field model string
---@field uuid string
---@field displayScale number
---@field timeZone string
---@field currentLocale string
---@field thermalState integer
---@field isSimulator boolean
---@field name string
---@field userInterfaceStyle string

---@return WDADeviceInfo?
local function deviceInfo()
  local status,response = api.get(
    wdaPort(),
    "wda/device/info"
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result["value"]
  end
end

M.deviceInfo = deviceInfo


local function getPasteboard()
  local status,response = api.post(
    wdaPort(),
    "wda/getPasteboard",
    {
      contentType = "plaintext"
    }
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return base64.decode(result["value"])
  end
  return nil
end

M.getPasteboard = getPasteboard

---检查设备是否锁屏
---@return boolean isLocked
function M.isLocked()
  local status,response = api.get(
    wdaPort(),
    "wda/locked"
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result["value"] == true
  end
  return false
end

---解锁设备屏幕
---@return boolean success
function M.unlock()
  local status = api.post(
    wdaPort(),
    "wda/unlock",
    {}
  )
  return status == 200
end

---锁定设备屏幕
---@return boolean success
function M.lock()
  local status = api.post(
    wdaPort(),
    "wda/lock",
    {}
  )
  return status == 200
end

---@class IosPhotoInfo
---@field id string
---@field filename string
---@field creationDate string
---@field pixelWidth integer
---@field pixelHeight integer


---@return IosPhotoInfo[]
function M.photoList()
  local status,response = api.get(
    wdaPort(),
    "wda/photos/list"
  )
  print(status,response)
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result.value.photos
  end
  return {}
end

function M.photoSave(path)
  local multipart = {
      file = {
        file = path
      }
    }
  local status, response = api.request(
    wdaPort(),
    "wda/photos/save",
    {
      method = "POST",
      headers = {
        ["Content-Type"] = "multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW"
      },
      multipart = multipart
    }
  )
  return status == 200
end

function M.photoDeleteRequest(identifier)
  local status,response = api.post(
    wdaPort(),
    "wda/photos/delete",
    {
      id = identifier,
      action = "request"
    }
  )
  return status == 200
end

function M.photoDeleteQuery(identifier)
  local status,response = api.post(
    wdaPort(),
    "wda/photos/delete",
    {
      id = identifier,
      action = "query"
    }
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    local r = result["value"]
    return true,r.completed,r.success
  end
  return false
end

function Session:tap(x,y)
  local delay = sleepRandomer:random(230,300)
  local actions = {
    {type = "pointerMove", duration = 0, x = x, y = y},
    {type = "pointerDown", button = 0},
    {type = "pause", duration = delay},
    {type = "pointerUp", button = 0},
  }
  return sendTouchEvents(self._sessionId,actions)
end



function Session:swipe(paths)
  local actions = {
    {
      type = "pointerMove", duration = 0, x = paths[1][1], y = paths[1][2]
    },
    {
      type = "pointerDown",
      button = 0
    }
  }

  for i = 2,#paths do
    local path = paths[i]
    local delay = sleepRandomer:random(17,23)
    table.insert(actions,{
      type = "pointerMove",
      duration = 0,
      x = path[1],
      y = path[2]
    })
    table.insert(actions,{
      type = "pause",
      duration = delay
    })
  end
  table.insert(actions,{
    type = "pointerUp",
    button = 0
  })
  print(json.encode(actions))
  return sendTouchEvents(self._sessionId,actions)
end

function Session:keyboardDismiss()
  local status,response = api.post(
    wdaPort(),
    format("session/%s/wda/keyboard/dismiss",self._sessionId),
    {keyNames = {"前往"}}
  )
  print(status,response)

  return status == 200
end

function Session:getWindowSize()
  local status,response = api.get(
    wdaPort(),
    "window/size"
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result["value"]
  end
end

function Session:openApp(bundleId)
  local payload = {
    bundleId = bundleId
  }
  local status = api.post(
    wdaPort(),
    "wda/apps/launchUnattached",
    payload
  )
  return status == 200
end

function Session:closeApp(bundleId)
  local payload = {
    bundleId = bundleId
  }
  local status,response = api.post(
    wdaPort(),
    format("session/%s/wda/apps/terminate",self._sessionId),
    payload
  )
  print(status,response)
  return status == 200
end

function Session:sendKeys(keys)
  local status,response = api.post(
    wdaPort(),
    format("session/%s/wda/keys",self._sessionId),
    {value = keys}
  )
  print(status,response)
  return status == 200
end

---@class IosAppInfo
---@field bundleId string
---@field pid integer
---@field name string

---@return IosAppInfo?
function Session:activeAppInfo()
  local status,response = api.get(
    wdaPort(),
    "wda/activeAppInfo"
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result["value"]
  end
end

---@class IosUINode:UiNode
local UINode = class.new("IosUINode")

function Session:findElement(using,value,rootId)
  local payload = {
    using = using,
    value = value
  }
  local path
  if rootId then
    path = format("session/%s/element/%s/element",self._sessionId,rootId)
  else
    path = format("session/%s/element",self._sessionId)
  end
  local status,response = api.post(
    wdaPort(),
    path,
    payload
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    local elementId = result["value"]["ELEMENT"] or result["value"]["element-6066-11e4-a52e-4f735466cecf"]
    return class.instance(UINode,self,elementId,result["value"])
  end
end

function Session:findElements(using,value,rootId)
  local payload = {
    using = using,
    value = value
  }
  local path
  if rootId then
    path = format("session/%s/element/%s/elements",self._sessionId,rootId)
  else
    path = format("session/%s/elements",self._sessionId)
  end
  local status,response = api.post(
    wdaPort(),
    path,
    payload
  )
  local nodes = {}
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    for _,elem in ipairs(result["value"]) do
      local elementId = elem["ELEMENT"] or elem["element-6066-11e4-a52e-4f735466cecf"]
      table.insert(nodes,class.instance(UINode,self,elementId,elem))
    end
  end
  return nodes
end

function Session:setSettings(settings)
  local status,response = api.post(
    wdaPort(),
    format("session/%s/appium/settings",self._sessionId),
    {
      settings = settings
    }
  )
  print(status,response)
  return status == 200
end


---@param session WDASession
---@param id string
function UINode:ctor(session,id,info)
  self._session = session
  self._id = id
  self._info = info
end

function UINode:_call(path,default)
  local status,response = api.get(
    wdaPort(),
    format("session/%s/element/%s/%s",self._session._sessionId,self._id,path)
  )
  if status == 200 then
    
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result["value"]
  end
  return default
end

function UINode:enabled()
  return self:_call("enabled",false)
end

function UINode:selected()
  return self:_call("selected",false)
end

function UINode:displayed()
  return self:_call("displayed",false)
end

function UINode:setText(value)
  local payload = {
    value = {value}
  }
  local status = api.post(
    wdaPort(),
    format("session/%s/element/%s/value",self._session._sessionId,self._id),
    payload
  )
  return status == 200
end

function UINode:visibleBounds()
  local rect = self:_call("rect")
  if rect then
    return rect.x,rect.y,rect.x + rect.width,rect.y + rect.height
  end
end

function UINode:text()
  return self:_call("text")
end


function UINode:attr(attrName,default)
  return self:_call("attribute/" .. attrName, default)
end

function UINode:name()
  return self:attr("name")
end

function UINode:res()
  return self:name()
end


function UINode:value()
  return self:attr("value")
end

function UINode:label()
  return self:attr("label")
end

function UINode:desc()
  return self:label()
end

function UINode:clz()
  return self:attr("type")
end

function UINode:visible()
  return self:attr("visible", false)
end

function UINode:clickable()
  return self:attr("hittable", false)
end

function UINode:placeholder()
  return self:attr("placeholderValue")
end

function UINode:index()
  return self:attr("index")
end

function UINode:focused()
  return self:attr("focused", false)
end

function UINode:checked()
  return self:attr("value") == "1"
end




---@class IOSUINodeFilter:UiNodeFilter
local UINodeFilter = class.new("IOSUINodeFilter")

---@param session WDASession
function UINodeFilter:ctor(session,using,value)
  self._session = session
  self._using = using
  self._value = value
end

---@param rootNode IosUINode?
---@return IosUINode?
function UINodeFilter:find(rootNode)
  return self._session:findElement(self._using,self._value,rootNode and rootNode._id)
end

---@param rootNode IosUINode?
---@return IosUINode[]
function UINodeFilter:finds(rootNode)
  return self._session:findElements(self._using,self._value,rootNode and rootNode._id)
end


---@param config WDASessionConfig?
---@return WDASession
function M.newSession(config)
  local devInfo = deviceInfo()
  assert(devInfo,"Failed to get device info from WDA server")
  local sessionId = newSessionId(config)
  return class.instance(Session,sessionId,devInfo.displayScale)
end


---@enum IOSFilterType
local FilterType = {
  kClassChain = "class chain",
  kXpath = "xpath",
  kId = "id",
  kClassName = "class name",
  kPredicateString = "predicate string",
}

M.FilterType = FilterType

---@param session WDASession
---@param filterType IOSFilterType
---@param filterValue string
function M.newUIFilter(session,filterType,filterValue)
  return class.instance(UINodeFilter,session,filterType,filterValue)
end


return M