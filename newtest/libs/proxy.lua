local M = {}

local function toProxyUrl(host,port,username,password,taskName,rule,useHttp)
  taskName = taskName or "no"
  rule = rule or "CJ"
  local appRule
  if useHttp then
    rule = rule .. "http"
  end
  if IOS then
    appRule = "surgeGZ/DownSurgeYun.php"
  else
    appRule = "clashGZ/DownClash" .. rule .. ".php"
  end
  local url =  "http://io.tetst.com/" .. appRule ..  "?ip="
    .. host .. "&port=" .. tostring(port) .. "&username=" .. username ..
    "&password=" .. password .. "&task=" .. taskName
  return url
end


---@param config ProxyConfig
local function toRolaUrl(config)
  return toProxyUrl(
    "proxyus.rola.vip",
    2081,
    "dry1203shunew_" .. tostring(config.userId) .. "-sesstime-30",
    "209209shu",
    config.taskName,
    config.rule,
    config.useHttp
  )
end

---@param config ProxyConfig
local function toSessionUrl(config)
  local country = string.lower(config.country)
  local url
  if config.proxyType == "ipidea" then
    url = country
  else
    url = "country-" .. country
  end
  if config.state then
    if config.proxyType == "ipidea" then
      url = url .. "-st-" .. config.state
    else
      url = url .. "-state-" .. config.state
    end
  end
  if config.city then
    url = url .. "-city-" .. config.city
  end
  return url .. "-session-" .. tostring(config.userId)
end

---@param config ProxyConfig
local function toIpideaUrl(config)
  return toProxyUrl(
    "643cfb36cf37ef59.fjt.as.grassdata.net",
    2333,
    "mkshushushu-zone-custom-region-" ..
    toSessionUrl(config)
    .. "-sessTime-30",
    "209209us",
    config.taskName,
    config.rule,
    config.useHttp
  )
end

---@param config ProxyConfig
local function toLumUrl(config)
   local rule = config.rule or "CJ"
  return toProxyUrl(
    "brd.superproxy.io",
    33335,
    "brd-customer-hl_8497f263-zone-mk_four_ds-" ..
    toSessionUrl(config),
    "209209cnUS",
    config.taskName,
    rule,
    config.useHttp
  )
end

---@param config ProxyConfig
local function toProxyGuys(config)
  return toProxyUrl(
    "154.198.35.63",
    9093,
    "pg_luckydogs.custom" .. tostring(config.userId),
    "209209cnUS",
    config.taskName,
    config.rule,
    config.useHttp
  )
end

---@class ProxyConfig
---@field userId string?
---@field proxyType string|"rola"|"ipidea"|"proxyguys"|"lum"
---@field country string
---@field taskName string?
---@field rule string?
---@field state string?
---@field city string?
---@field useHttp boolean?

---@param config ProxyConfig
---@return string?
function M.toTargetProxyUrl(config)
  if config.proxyType == "rola" then
    return toRolaUrl(config)
  elseif config.proxyType == "ipidea" then
    return toIpideaUrl(config)
  elseif config.proxyType == "proxyguys" then
    return toProxyGuys(config)
  elseif config.proxyType == "lum" then
    return toLumUrl(config)
  end
end


return M