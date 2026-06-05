local utils = require "utils"
local system = require "system"
local json = require "dkjson"

local M = {}

local function joinParams(params)
  local str = ""
  for k,v in pairs(params) do
    str = str .. k .. "=" .. v .. "&"
  end
  return string.sub(str,1,-2)
end



local function commonRequest(url,params,method,body,headers)
  if params then
    url = url .. "?" .. joinParams(params)
  end
  print(url)
  local request = {
    url = url,
    headers = {
      Accept = "application/json",
      ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    },
    method = method or "GET",
    body = body
  }
  if headers then
    request.headers = headers
  end
  return http.request(request)
end

M.commonRequest = commonRequest

local function commonEnsureRequest(url,params,method,body,headers)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  while nowTime - startTime < 60000 do
    local code,result = commonRequest(url,params,method,body,headers)
    if code == 200 then
      return result
    else
      logd("commonEnsureRequest failed",code,result)
    end
    ca.randomSleep(2000,3000)
    nowTime = GetTimeOfDayMs()
  end
  return nil
end
M.commonEnsureRequest = commonEnsureRequest


local function commonGet(url,params)
  return commonRequest(url,params,"GET")
end


local function commonEnsureGet(url,params)
  for i = 1, 3 do
    local code,result = commonGet(url,params)
    if code >=200 and code < 300 then
      return result
    else
      logd("commonEnsureGet failed",code,result)
    end
    ca.randomSleep(5000,6000)
  end
  return nil
end


M.commonEnsureGet = commonEnsureGet
--curl -i --proxy brd.superproxy.io:33335 --proxy-user brd-customer-hl_8497f263-zone-mk_four_rw:209209cnUS "https://geo.brdtest.com/welcome.txt?product=resi&method=native"
local function getRandomPort(proxyType,forceNewId)
  local user_id = system.getDeviceId()
  local timeout = nil
  if proxyType == "lum" or forceNewId then
    user_id = user_id .. "-" .. tostring(os.time())
    timeout = 60*60*2
  end
  if proxyType == "proxyguys" or proxyType == "lum" then
    proxyType = "rola"
  end

  local params = {
    user_id = user_id,
    proxy_type = proxyType or "rola",
    timeout = timeout
  }

  local url = "http://api.jb.51wmsy.com/api/proxy/port"
  local now_time = GetTimeOfDayMs()
  local start_time = now_time
  while now_time - start_time < 60000 do
    local code,result = commonGet(url,params)
    if code == 200 then
      local data = json.decode(result)
      assert(type(data) == "table","data is not a table")
      if data.status == 0 then
        return data.port
      end
    end
    ca.randomSleep(2000,3000)
    now_time = GetTimeOfDayMs()
  end
  return nil
end

local function releaseProxyPort()
  local user_id = system.getDeviceId()
  local body = {
    user_id = user_id,
    proxy_type = "rola",
  }
  local url = "http://api.jb.51wmsy.com/api/proxy/port"
  local request = {
    url = url,
    headers = {
      Accept = "application/json",
      ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    },
    method = "POST",
    body = json.encode(body)
  }
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  while nowTime - startTime < 60000 do
    local code,result = http.request(request)
    logd("releaseProxyPort result",code,result)
    if code == 200 then
      local data = json.decode(result)
      return type(data) == "table" and data.status == 0
    end
    ca.randomSleep(2000,3000)
    nowTime = GetTimeOfDayMs()
  end
  return false
end


local function resetIpideaProxy(port)
  local sns = {"30329259cc321738cdd70e11c3a9e189"}
  local url = "http://apiproxy.grassdata.net/changeAccountSession?sn=%s&account=mkshushushu&session=" .. tostring(port)
  for i = 1, 4 do
    local url = string.format(url,sns[1])
    local response = commonEnsureGet(url)
    print(response)
    ---@type table
---@diagnostic disable-next-line: assign-type-mismatch
    local data = json.decode(response)
    if data.success then
      return true
    end
    ca.randomSleep(2000,3000)
  end
  return false
end

M.resetIpideaProxy = resetIpideaProxy


function M.resetProxyGuysProxy(port)
  local url = "https://portal.proxyguys.com/proxy/locations/pg_luckydogs/custom"
    .. tostring(port)
    .. "/77d3039582f6c39c7f663c43f9322ab9:WbodQZdXKpMqgKhAe6sny-N4Mc_dK11Ebf78zuKH6TM"
  for i = 1, 3 do
    local response = commonEnsureGet(url)
    print(response)
    ---@type table
---@diagnostic disable-next-line: assign-type-mismatch
    local data = json.decode(response)
    if data then
      return true
    end
    ca.randomSleep(2000,3000)
  end
  return false
end


function M.resetRolaProxy(userName,country,isVip)
  isVip = true
  local url = isVip and "http://refreshus.rola.vip/refresh" or "http://refresh.rola.info/refresh"
  local params = {
    user = userName,
    country = country
  }
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  while nowTime - startTime < 60000 do
    logd("resetRolaProxy",url,joinParams(params))
    local code,result = commonGet(url,params)
    logd("resetRolaProxy result",code,result)
    if code == 200 then
      local data = json.decode(result)
      return type(data) == "table" and tonumber(data.code) == 0
    end
    ca.randomSleep(2000,3000)
    nowTime = GetTimeOfDayMs()
  end
  return false
end

M.getRandomProxyUserId = getRandomPort
M.releaseProxyPort = releaseProxyPort

function M.checkIpCountry(country)
  local url = "https://api.ipstack.com/check?access_key=bd8184ae3137d4056c0c60305faad826"
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  while nowTime - startTime < 60000 do
    local code,result = commonGet(url)
    logd("checkIpCountry result",code,result)
    if code == 200 then
      local data = json.decode(result)
      return type(data) == "table" and data.country_code == country
    end
    ca.randomSleep(2000,3000)
    nowTime = GetTimeOfDayMs()
  end
  return false
end

---@class IpInfo
---@field ip string
---@field country_code string
---@field zip string


---@return IpInfo|nil
function M.getIpInfo(url)
  url = url or "https://api.ipstack.com/check?access_key=bd8184ae3137d4056c0c60305faad826"
  local response = commonEnsureGet(url)
  if not response then
    return nil
  else
    logi("getIpInfo",response)
  end
  local data = json.decode(response)
  if not data then
    return nil
  end
---@diagnostic disable-next-line: return-type-mismatch
  return data
end

function M.getChromiumConfigure(params)
  if not params then
    params = {}
  end
  params.platform = "Android"
  
  for k,v in pairs(params) do
    params[k] = v
  end
  local url = "https://cpl.51wmsy.com/search.php"

  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  while nowTime - startTime < 60000 do
    local code,result = commonGet(url,params)
    if code == 200 then
      return result
    end
    ca.randomSleep(2000,3000)
    nowTime = GetTimeOfDayMs()
  end
end

---@class LinkInfo
---@field name string
---@field url string
---@field show_url string
---@field code string
---@field country string
---@field app_package_name string



---@return LinkInfo|nil
function M.getLinkInfo(linkCode)
  if not linkCode then
    linkCode = settings.get("link_code",2)
  end
  if not linkCode then
    return nil
  end

  local url = "http://api.jb.51wmsy.com/api/link_info"
  local params = {
    code = linkCode
  }
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  while nowTime - startTime < 60000 do
    local code,result = commonGet(url,params)
    if code == 200 then
      logd("getLinkInfo result",result)
      ---@type table
---@diagnostic disable-next-line: assign-type-mismatch
      local data = json.decode(result)
      if data.status == 0 then
        return data.data
      end
      logw("getLinkInfo failed",data.status)
    end
    ca.randomSleep(2000,3000)
    nowTime = GetTimeOfDayMs()
  end
  return nil
end



---@class AccountInfo
---@field id integer
---@field account_name string
---@field email string
---@field password string
---@field phone_type integer
---@field country string
---@field register_time string
---@field FA string

---@param camp_id string
---@param country string
---@return AccountInfo|nil
---@return boolean isNetError
function M.getAccountInfo(camp_id,country)
  local url = "http://hy.51wmsy.com/api/get_amazon_account_fuse"
  country = "US"
  local params = {
    camp_id = camp_id,
    country = country,
    operator = "FuseAPI用户"
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return nil,true
  else
    logd("getAccountInfo response",response)
  end
  ---@type table
---@diagnostic disable-next-line: unused-local, assign-type-mismatch
  local data = json.decode(response)
  if not data then
    return nil,false
  end
  if tonumber(data.status) == 1 then
    return data.data,false
  end
  logw("getAccountInfo failed",data.info)
  return nil,false
end

---@param camp_id string
---@param email string
---@param use_status integer 1:登陆成功，2:登陆失败，3:账号异常，4：帐号未使用
---@param task_name string
---@param task_country string
---@return boolean
function M.returnAccountUseState(camp_id,email,use_status,task_name,task_country)
  local url = "http://hy.51wmsy.com/api/return_get_amazon_account_fuse"
  local params = {
    camp_id = camp_id,
    email = email,
    use_status = use_status,
    task_name = task_name,
    task_country = task_country
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return tonumber(data.status) == 1
end

---@class CardInfo
---@field id integer
---@field card string
---@field ex_date string
---@field cvv string
---@field card_type integer


---@param card_type integer|nil 卡类型，1为1-2刀 2为5刀， 3为15刀，5为20刀
---@return CardInfo|nil
function M.getCardInfo(card_type,card_header)
  card_type = card_type or 1
  local url = "http://hy.51wmsy.com/api/get_card_web_info_fuse"
  local params = {
    card_type = card_type,
    card_header = card_header
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return nil
  else
    logi("get card",response)
  end
  local data = json.decode(response)
  if not data then
    return nil
  end
  if tonumber(data.status) == 1 then
    return data.data
  end
  logw("getCardInfo failed",data.info)
  return nil
end


---@param card string
---@param cvv string
---@param use_status integer|nil 1:已使用，2未使用,3 支付成功
---@return boolean
function M.returnCardUsed(card,cvv,use_status)
  local url = "http://hy.51wmsy.com/api/return_get_card_web_info_fuse"
  use_status = use_status or 1
  local params = {
    card = card,
    cvv = cvv,
    use_status = use_status
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return tonumber(data.status) == 1
end

---@class AddressInfo
---@field country string
---@field address1 string
---@field city string
---@field state string
---@field name string
---@field postcode string

local function getAddressInfo(country,postcode)
  local url = "http://jb.51wmsy.com/mailAPI/public/index.php/mail_api/amazon_eaccount0729/get_country_address_pro"
  local params = {
    key = "81166edc6ebef059c9171fa487f2d233",
    country = country,
    postcode = postcode
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return nil
  else
    logd("getAddressInfo response",response)
  end
  local data = json.decode(response)
  if not data then
    return nil
  end
  return data.data
end


---@param country string
---@param postcode string
---@return AddressInfo|nil
function M.getAddressInfo(country,postcode)
  -- postcode 一直递减，直到找到为止
  for i = #postcode,0,-1 do
    local nowZip = string.sub(postcode,1,i)
    local addressInfo = getAddressInfo(country,nowZip)
    if addressInfo then
      addressInfo.country = country
      return addressInfo
    end
  end
  return nil
end

---@return string|nil
function M.getBuyerName(country)
  country = country or "US"
  local result = getAddressInfo(country)
  if not result then
    return nil
  end
  return result.buyer_name
end


local function decodeTime(timeStr)
  local year,month,day,hour,minute,second = string.match(timeStr,"(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")

  return os.time({year=year,month=month,day=day,hour=hour,min=minute,sec=second})
end

---@param country string|nil
---@param timezone string|nil 
---@return number|nil
function M.getNowTime(country,timezone,notTimestamp)
  local url = "http://api.jb.51wmsy.com/api/time"
  local params = {
    country = country,
    timezone = timezone
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return nil
  end
  local data = json.decode(response)
  if not data then
    return nil
  end
  local time = data.time
  if not time then
    return nil
  end
  logd("net","now country time ",country,time)
  return notTimestamp and time or decodeTime(time)
end

function M.getTimeDiff(targetCountry)
  local targetNowTime = M.getNowTime(targetCountry)
  if not targetNowTime then
    return nil
  end
  local nowTime = os.time()
  print(targetNowTime,nowTime,os.difftime(targetNowTime,nowTime))
  local diff = os.difftime(targetNowTime,nowTime)
  return math.abs(diff) // 3600 * 3600 * (diff > 0 and 1 or -1)
end


function M.uploadRemain(camp_id,data,worker_id)
  local url = "http://api.jb.51wmsy.com/api/remain"
  local body = {
    camp_id = tostring(camp_id),
    remain_data = data,
    worker_id = worker_id or WORKER_ID
  }

  print(json.encode(body))
  local response = commonEnsureRequest(url,nil,"POST",json.encode(body))
  if not response then
    return false
  end
  logd("upload remain: response",response)
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.success
end

function M.getRemain(remain_model_name,camp_id,worker_id,country)
  local url = "http://api.jb.51wmsy.com/api/remain"
  local params = {
    remain_model_name = remain_model_name,
    camp_id = camp_id,
    worker_id = worker_id,
    country = country
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return nil
  end
  local data = json.decode(response)
  if not data then
    return nil
  end
  return data.data
end

function M.superIntervalLock(camp_id,min_interval_sec,max_interval_sec,timeout_sec)
  local url = "http://api.jb.51wmsy.com/api/interval/lock"
  min_interval_sec = min_interval_sec or 60 *60 *24 *2
  max_interval_sec = max_interval_sec or 60 *60 *24 *2.2
  timeout_sec = timeout_sec or 60 *60 *2
  min_interval_sec = math.floor(min_interval_sec)
  max_interval_sec = math.floor(max_interval_sec)
  timeout_sec = math.floor(timeout_sec)
  local params = {
    key = camp_id,
    min_interval_sec = min_interval_sec,
    max_interval_sec = max_interval_sec,
    timeout_sec = timeout_sec
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.success
end


function M.superIntervalSuccess(camp_id)
  local url = "http://api.jb.51wmsy.com/api/interval/success"
  local params = {
    key = camp_id
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.success
end

function M.superIntervalFail(camp_id)
  local url = "http://api.jb.51wmsy.com/api/interval/fail"
  local params = {
    key = camp_id
  }
  local response = commonEnsureGet(url,params)
  if not response then
    return false
  end
  local data = json.decode(response)
  if not data then
    return false
  end
  return data.success
end

return M