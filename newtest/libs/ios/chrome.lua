local M = {}

local api = require "ios.api_net"
local json = require("dkjson")
local class= require("class")
local system = require "ios.system"
local net = require "net"
local utils = require "utils"

local bundleId<const> = "com.maiku.chrome.ios.dev"


local function toFindJsCode(cssSelector)
  -- 转义单引号，防止字符串注入
  local escapedSelector = cssSelector:gsub("'", "\\'")
  return string.format([[
    (function(){
      var selector = '%s';
      var element = document.querySelector(selector);
      if(element){
        var rect = element.getBoundingClientRect();
        return {
          found: true,
          selector: selector,
          rect: {
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height
          },
          text: element.innerText,
          classes: element.className,
          id: element.id,
          tagName: element.tagName,
          focused: document.activeElement === element,
          value: element.value || '',
          href: element.href || '',
          src: element.src || '',
          checked: element.checked || false,
          disabled: element.disabled || false,
          options: element.options ? Array.from(element.options).map(function(option) {
              return {
                  text: option.text,
                  value: option.value,
                  selected: option.selected
              };
          }) : [],
          selectedIndex: element.selectedIndex || -1,
        };
      } else {
        return {found: false, selector: selector};
      }
    })();
  ]], escapedSelector)
end

local function toFindsJsCode(cssSelector)
  -- 转义单引号，防止字符串注入
  local escapedSelector = cssSelector:gsub("'", "\\'")
  return string.format([[
    (function(){
      var selector = '%s';
      var elements = document.querySelectorAll(selector);
      var results = [];
      elements.forEach(function(element){
        var rect = element.getBoundingClientRect();
        results.push({
          rect: {
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height
          },
          text: element.innerText,
          classes: element.className,
          id: element.id,
          tagName: element.tagName,
          focused: document.activeElement === element,
          value: element.value || '',
          href: element.href || '',
          src: element.src || '',
          checked: element.checked || false,
          disabled: element.disabled || false,
          options: element.options ? Array.from(element.options).map(function(option) {
              return {
                  text: option.text,
                  value: option.value,
                  selected: option.selected
              };
          }) : [],
          selectedIndex: element.selectedIndex || -1
        });
      });
      return results;
    })();
  ]], escapedSelector)
end

local function chromePort()
---@diagnostic disable-next-line: undefined-global
  return CHROME_PORT
end

local function rawFind(cssSelector)
  local jsCode = toFindJsCode(cssSelector)
  local status,response = api.post(
    chromePort(),
    "exec",
    jsCode
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result
  else
    return nil
  end
end

local function rawFinds(cssSelector)
  local jsCode = toFindsJsCode(cssSelector)
  local status,response = api.post(
    chromePort(),
    "exec",
    jsCode
  )
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result
  else
    return nil
  end
end


local function find(cssSelector)
  local status,response = api.post(chromePort(),"find",{
    selector = cssSelector
  })
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result
  else
    return nil
  end
end

M.find = find
M.rawFind = rawFind
M.rawFinds = rawFinds


local function finds(cssSelector)
  local status,response = api.post(chromePort(),"finds",{
    selector = cssSelector
  })
  if status == 200 then
    print("Finds response:",response)
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result
  end
end

---@class IosHtmlNodeBaseInfo
---@field rect table
---@field text string
---@field classes string
---@field id string
---@field tagName string
---@field focused boolean
---@field value string
---@field href string
---@field src string
---@field checked boolean
---@field disabled boolean
---@field options table[]
---@field selectedIndex integer


---@class IosHtmlNode:UiNode
local IosHtmlNode = class.new("IosHtmlNode")

---@param info IosHtmlNodeBaseInfo
---@param origin table
function IosHtmlNode:ctor(info,origin)
  self._info = info
  self._origin = origin
end

local function round(num)
  local n = math.floor(num + 0.5)
  return n
end


function IosHtmlNode:visibleBounds()
  local origin = self._origin
  local rect = self._info.rect
  local oLeft,oTop = rect.left + origin.left, rect.top + origin.top
  local left,top = math.max(origin.left, oLeft), math.max(origin.top, oTop)
  return round(left), round(top), round(oLeft + rect.width), round(oTop + rect.height)
end

function IosHtmlNode:visible()
  local rect = self._info.rect
  return rect.left + rect.width > 0 and rect.top + rect.height > 0
end

function IosHtmlNode:text()
  local info = self._info
  if info.tagName == "INPUT" or info.tagName == "TEXTAREA" then
    return info.value
  elseif info.tagName == "SELECT" then
    local selectedIndex = info.selectedIndex
    if selectedIndex >=0 and selectedIndex < #info.options then
      return info.options[selectedIndex + 1].text
    end
    return ""
  end
  return info.text
end

function IosHtmlNode:checked()
  return self._info.checked
end

function IosHtmlNode:enabled()
  return not self._info.disabled
end

function IosHtmlNode:clz()
  return self._info.classes
end

function IosHtmlNode:res()
  return self._info.id
end

function IosHtmlNode:tag()
  return self._info.tagName
end

function IosHtmlNode:focused()
  return self._info.focused
end


---@class IOSCssSelector:UiNodeFilter
local Selector = class.new("IOSCssSelector")

function Selector:ctor(selector)
  self._selector = selector
end

function Selector:find()
  local result = find(self._selector)
  if result and result.found then
    return class.instance(IosHtmlNode,result.result,result.origin)
  else
    return nil
  end
end

function Selector:finds()
  local results = finds(self._selector)
  if results and results.found then
    local nodes = {}
    for _,info in ipairs(results.results) do
      table.insert(nodes,class.instance(IosHtmlNode,info,results.origin))
    end
    return nodes
  end
end


function M.cssSelectorFinder(selector)
  return class.instance(Selector,selector)
end

function M.reset()
  local appInfo = system.activeAppInfo()
  if appInfo and appInfo.bundleId ~= bundleId then
    system.openApp(bundleId)
  end
  local status,response = api.delete(
    chromePort(),
    "browsing_data")
  if status == 200 then
    return response == "true"
  else
    return false
  end
end

function M.navigateTo(url)
  local status,response = api.post(
    chromePort(),
    "url",
    {url = url}
  )
  if status == 200 then
    return response == "true"
  else
    return false
  end
end

---@class InjectHeaderItem
---@field name string
---@field value string

---@class InjectReferrerItem
---@field source string
---@field referrer string

---@class IOSFingerprint
---@field user_agent string
---@field inject_headers InjectHeaderItem[]
---@field inject_referrers InjectReferrerItem[]

---@param fingerprint IOSFingerprint|string
local function changeFingerprint(fingerprint)
  if type(fingerprint) == "table" then
---@diagnostic disable-next-line: cast-local-type
    fingerprint = json.encode(fingerprint)
  end
  local status,response = api.post(
    chromePort(),
    "fingerprint",
    fingerprint
  )
  print(status,response)
  if status == 200 then
    return response == "1"
  else
    return false
  end
end

M.changeFingerprint = changeFingerprint

local function toReferrer(referrer)
  if not referrer then
    return nil
  end
  local sourceList = utils.split(referrer.targetUrl,";")
  local newList = utils.split(referrer.newUrl,";")
  local result = {}

  for i,source in ipairs(sourceList) do
    table.insert(result,{
      source = source,
      referrer = newList[i]
    })
  end
  return result 
end

local function toHeader(heaserDict)
  local result = {}
  for name,value in pairs(heaserDict) do
    table.insert(result,{
      name = name,
      value = value
    })
  end
  return result
end


local function toIosFingerprint(str)
  local data = json.decode(str)
  assert(type(data) == "table","decode fingerprint")
  print(json.encode(data))
  local result = {
    inject_headers = toHeader(data.injectHeaders),
    inject_referrers = toReferrer(data.referrer)
  }
  return result
end

function M.ensureInit(params)
  system.ensureInit()
  if not system.openApp(bundleId) then 
    return false
  end
  if not params then
    return true
  end

  local fingerprint = net.getChromiumConfigure(params)
  local ios_fingerprint = toIosFingerprint(fingerprint)
  if not next(ios_fingerprint) then
    return true
  end
  return changeFingerprint(ios_fingerprint)
end

---@return integer
function M.tabCount()
  local status,response = api.get(chromePort(),"tab/count")
  if status == 200 then
    local result = json.decode(response)
---@diagnostic disable-next-line: return-type-mismatch
    return result
  else
    return 0
  end
end


---@return TabInfo[]
function M.tabInfo()
  local status,response = api.get(chromePort(),"tab/info")
  if status == 200 then
    local result = json.decode(response)
    assert(type(result) == "table","Invalid response")
    return result.tabs
  end
  return {}
end

function M.closeTab(id)
  local status,response = api.post(chromePort(),"tab/close",{
    id = id
  })
  if status == 200 then
    return response == "true"
  else
    return false
  end
end

function M.reloadTab()
  local status,response = api.get(chromePort(),"reload")
  print(status,response)
  if status == 200 then
    return response == "true"
  else
    return false
  end
end

function M.switchToTab(id)
  local status,response = api.post(chromePort(),"tab/switch",{
    id = id
  })
  if status == 200 then
    return response == "true"
  else
    return false
  end
end

function M.alert(title,message,buttons,timeout)
  local status,response = api.post(
    chromePort(),
    "alert",
    {
      title = title,
      message = message,
      buttons = buttons,
      timeout_seconds = timeout
    }
  )
  if status == 200 then
    local data = json.decode(response)
    assert(type(data) == "table","Invalid response")
    return data.success, data.clicked
  end
  return false
end

function M.get(url)
  local status,response = api.post(
    chromePort(),
    "proxy_get",
    url
  )
  print(status,response)
  if status == 200 then
    return response
  else
    return nil
  end
end



return M