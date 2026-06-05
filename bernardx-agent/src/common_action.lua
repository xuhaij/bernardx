local M = {}
local utils = require "utils"
local shell = require "shell"
local ime = require "ime"
local iutils = require "iutils"
local net = require "net"
local tablex = require "tablex"
local chromium = require "chromium"
local randomer = random.gaussian(utils.randomSeed())
local action_randomer = random.gaussian(utils.randomSeed())
-- local action_randomer = random.twister(utils.randomSeed())
-- local action_log = require "action_log"

-- local main = require "main"
-- local chromium = require "chromium"

local oldSleep = sleep

local sleepRandomer = random.gaussian(utils.randomSeed())
local actionRandomer = random.gaussian(utils.randomSeed())
local getTimeOfDayMs = GetTimeOfDayMs
local yield = coroutine.yield

local kYield <const> = {}
local kOver <const> = {}
local kReset <const> = {}

local function actionTimeout()
  return randomer:random(MIN_ACTION_REPONSE_TIME, MAX_ACTION_REPONSE_TIME)
end

M.actionTimeout = actionTimeout

function M.netTimeout()
  return randomer:random(70000, 80000)
end

local function tickSleep()
  return sleep(randomer:random(73, 131))
end

-- function M.commonSleep()
--   return sleep(randomer:random(600, 730))
-- end

function M.commonSleep()
  return sleep(randomer:random(600, 1730))
end

function M.randomTap(x1, y1, x2, y2)
  local x = action_randomer:random(x1, x2)
  local y = action_randomer:random(y1, y2)
  return tap(x, y)
end

local function responseTime()
  return randomer:random(230, 410)
end

M.responseTime = responseTime


M.tickSleep = tickSleep

local function randomTap(x1, y1, x2, y2)
  local x = randomer:random(x1, x2)
  local y = randomer:random(y1, y2)
  return tap(x, y)
end

-- 点击HOME返回主页
local function refreshWebView()
  keyPress(KeyCode.HOME)
  ca.commonSleep()
  chromium.start()
  ca.commonSleep()
end
-- TODO
-- 节点点击事件
-- ---@param node UiNode
-- function M.clickNode(node)
--   local x,y,x1,y1 = node:visibleBounds()
--   x,y,x1,y1 = x + 3,y + 3,x1 - 3,y1 - 3
--   return randomTap(x,y,x1,y1)
-- end

-- local startShift = -1

-- -- 节点点击事件
-- ---@param node UiNode
-- function M.clickNode(node)
--   if startShift == -1 then
--     -- print(4444)
--     startShift = math.random(100, 800)
--     startShift = startShift / 1000
--   end
--   -- print(3333)
--   local x1, y1, x2, y2 = node:visibleBounds()
--   logi(x1, y1, x2, y2)
--   if x2 <= x1 or y2 <= y1 then
--     print(2222)
--     logw("click node %s out of bounds", node:text(), x1, y1, x2, y2)
--     return false
--   end
--   x1 = x1 + 5
--   y1 = y1 + 5
--   x2 = x2 - 5
--   y2 = y2 - 5
--   local tx1 = x1 + startShift * (x2 - x1)
--   tx1 = math.floor(tx1)
--   local tx2 = math.min(x2, tx1 + (y2 - y1))
--   local x = action_randomer:random(tx1, tx2)
--   local y = action_randomer:random(y1, y2)

--   -- print(x, y)
--   -- Display:update()
--   -- local width, height = Display:getSize() --获取屏幕的宽高
--   -- print(width, height)
--   -- Display:save("screenshot.png", 0, 0, width, height, 1, 100)
--   -- return nil
--   return tap(x, y)
-- end

-- 修改 startShift 的值来控制点击偏向
-- startShift = -1  -- 偏左 (10%-30%)
-- startShift = 0   -- 居中 (40%-60%)
-- startShift = 1   -- 偏右 (70%-90%)

-- local startShift = -1 -- 默认偏左

-- -- 节点点击事件
-- ---@param node UiNode
-- function M.clickNode(node)
--   local currentShift

--   if startShift == -1 then
--     -- 偏左：10%-30%
--     currentShift = math.random(100, 300) / 1000
--   elseif startShift == 0 then
--     -- 居中：40%-60%
--     currentShift = math.random(400, 600) / 1000
--   elseif startShift == 1 then
--     -- 偏右：70%-90%
--     currentShift = math.random(700, 900) / 1000
--   else
--     -- 默认偏左
--     currentShift = math.random(100, 300) / 1000
--   end

--   local x1, y1, x2, y2 = node:visibleBounds()
--   -- logi(x1, y1, x2, y2)
--   if x2 <= x1 or y2 <= y1 then
--     print(2222)
--     logw("click node %s out of bounds", node:text(), x1, y1, x2, y2)
--     return false
--   end
--   x1 = x1 + 5
--   y1 = y1 + 5
--   x2 = x2 - 5
--   y2 = y2 - 5
--   local tx1 = x1 + currentShift * (x2 - x1)
--   tx1 = math.floor(tx1)
--   local tx2 = math.min(x2, tx1 + (y2 - y1))
--   local x = action_randomer:random(tx1, tx2)
--   local y = action_randomer:random(y1, y2)

--   -- logd(x, y)
--   return tap(x, y)
-- end

--- 点击节点，以指定百分比作为中心点进行正态分布随机
---@param node UiNode
---@param percentage number|nil 0~1 之间的数，表示点击中心在节点宽度上的比例（0=最左，1=最右）
---@param stdXFactor number|nil x方向标准差因子（相对于节点宽度，默认0.1）其余点落在中心点10%左右的范围内
---@param stdYFactor number|nil y方向标准差因子（相对于节点高度，默认0.1）其余点落在中心点10%上下的范围内
function M.clickNode(node, percentage, stdXFactor, stdYFactor)
  percentage = percentage or 0.5
  local x1, y1, x2, y2 = node:visibleBounds()
  if x2 <= x1 or y2 <= y1 then
    logw("click node %s out of bounds", node:text(), x1, y1, x2, y2)
    return false
  end

  -- 添加内边距，避免点击到边缘
  local pad = 5
  x1 = x1 + pad
  y1 = y1 + pad
  x2 = x2 - pad
  y2 = y2 - pad
  if x2 <= x1 or y2 <= y1 then
    logw("node %s too small after padding", node:text())
    return false
  end

  local width = x2 - x1
  local height = y2 - y1

  -- 计算中心点
  local meanX = x1 + percentage * width
  local meanY = y1 + height / 2 -- y轴中心固定为高度的一半

  -- 设置标准差（默认取宽度/高度的10%）
  stdXFactor = stdXFactor or 0.1
  stdYFactor = stdYFactor or 0.1
  local stdX = width * stdXFactor
  local stdY = height * stdYFactor

  -- 生成两个独立的标准正态变量（Box-Muller 返回一对）
  local zx, zy = action_randomer:box_muller()

  -- 转换为目标均值和标准差，并四舍五入取整
  local function round(v)
    return math.floor(v + 0.5)
  end

  local x = round(meanX + zx * stdX)
  local y = round(meanY + zy * stdY)

  -- 边界约束，确保点击点在节点内部
  x = math.max(x1, math.min(x2, x))
  y = math.max(y1, math.min(y2, y))

  logd("点击的坐标：", x, y)

  return tap(x, y)
end

--- 点击节点，以指定百分比作为中心点进行正态分布随机
---@param node UiNode
---@param percentageX number|nil 0~1 之间的数，表示点击中心在节点宽度上的比例（0=最左，1=最右）
---@param percentageY number|nil 0~1 之间的数，表示点击中心在节点高度上的比例（0=最上，1=最下）
---@param stdXFactor number|nil x方向标准差因子（相对于节点宽度，默认0.1）其余点落在中心点10%左右的范围内
---@param stdYFactor number|nil y方向标准差因子（相对于节点高度，默认0.1）其余点落在中心点10%上下的范围内
function M.clickNodeXY(node, percentageX, percentageY, stdXFactor, stdYFactor)
  percentageX = percentageX or 0.5
  percentageY = percentageY or 0.5
  local x1, y1, x2, y2 = node:visibleBounds()
  if x2 <= x1 or y2 <= y1 then
    logw("click node %s out of bounds", node:text(), x1, y1, x2, y2)
    return false
  end

  -- 添加内边距，避免点击到边缘
  local pad = 5
  x1 = x1 + pad
  y1 = y1 + pad
  x2 = x2 - pad
  y2 = y2 - pad
  if x2 <= x1 or y2 <= y1 then
    logw("node %s too small after padding", node:text())
    return false
  end

  local width = x2 - x1
  local height = y2 - y1

  -- 计算中心点
  local meanX = x1 + percentageX * width
  local meanY = y1 + percentageY * height

  -- 设置标准差（默认取宽度/高度的10%）
  stdXFactor = stdXFactor or 0.1
  stdYFactor = stdYFactor or 0.1
  local stdX = width * stdXFactor
  local stdY = height * stdYFactor

  -- 生成两个独立的标准正态变量（Box-Muller 返回一对）
  local zx, zy = action_randomer:box_muller()

  -- 转换为目标均值和标准差，并四舍五入取整
  local function round(v)
    return math.floor(v + 0.5)
  end

  local x = round(meanX + zx * stdX)
  local y = round(meanY + zy * stdY)

  -- 边界约束，确保点击点在节点内部
  x = math.max(x1, math.min(x2, x))
  y = math.max(y1, math.min(y2, y))

  logd("点击的坐标：", x, y)

  return tap(x, y)
end

--- 点击节点，以指定百分比作为中心点进行正态分布随机
---@param range table 点击范围
---@param percentage number|nil 0~1 之间的数，表示点击中心在节点宽度上的比例（0=最左，1=最右）
---@param stdXFactor number|nil x方向标准差因子（相对于节点宽度，默认0.1）其余点落在中心点10%左右的范围内
---@param stdYFactor number|nil y方向标准差因子（相对于节点高度，默认0.1）其余点落在中心点10%上下的范围内
function M.clickRange(range, percentage, stdXFactor, stdYFactor)
  percentage = percentage or 0.1
  local x1, y1, x2, y2 = range[1], range[2], range[3], range[4]
  if x2 <= x1 or y2 <= y1 then
    logw("click node %s out of bounds", x1, y1, x2, y2)
    return false
  end

  -- 添加内边距，避免点击到边缘
  local pad = 5
  x1 = x1 + pad
  y1 = y1 + pad
  x2 = x2 - pad
  y2 = y2 - pad
  if x2 <= x1 or y2 <= y1 then
    logw("node %s too small after padding")
    return false
  end

  local width = x2 - x1
  local height = y2 - y1

  -- 计算中心点
  local meanX = x1 + percentage * width
  local meanY = y1 + height / 2 -- y轴中心固定为高度的一半

  -- 设置标准差（默认取宽度/高度的10%）
  stdXFactor = stdXFactor or 0.1
  stdYFactor = stdYFactor or 0.1
  local stdX = width * stdXFactor
  local stdY = height * stdYFactor

  -- 生成两个独立的标准正态变量（Box-Muller 返回一对）
  local zx, zy = action_randomer:box_muller()

  -- 转换为目标均值和标准差，并四舍五入取整
  local function round(v)
    return math.floor(v + 0.5)
  end

  local x = round(meanX + zx * stdX)
  local y = round(meanY + zy * stdY)

  -- 边界约束，确保点击点在节点内部
  x = math.max(x1, math.min(x2, x))
  y = math.max(y1, math.min(y2, y))

  logd(x, y)
  return tap(x, y)
end

-- 节点点击事件，按钮坐标范围缩小一倍
---@param node UiNode
function M.clickNodeShort(node)
  if startShift == -1 then
    print(4444)
    startShift = math.random(100, 800)
    startShift = startShift / 1000
  end
  -- print(3333)
  local x1, y1, x2, y2 = node:visibleBounds()
  logi(x1, y1, x2, y2)
  if x2 <= x1 or y2 <= y1 then
    print(2222)
    logw("click node %s out of bounds", node:text(), x1, y1, x2, y2)
    return false
  end
  x1 = math.floor(x1 / 2 + 5)
  y1 = math.floor(y1 / 2 + 5)
  x2 = math.floor(x2 / 2 - 5)
  y2 = math.floor(y2 / 2 - 5)
  local tx1 = x1 + startShift * (x2 - x1)
  tx1 = math.floor(tx1)
  local tx2 = math.min(x2, tx1 + (y2 - y1))
  local x = action_randomer:random(tx1, tx2)
  local y = action_randomer:random(y1, y2)

  print(x, y)
  -- Display:update()
  -- local width, height = Display:getSize() --获取屏幕的宽高
  -- print(width, height)
  -- Display:save("screenshot.png", 0, 0, width, height, 1, 100)
  -- return nil
  return tap(x, y)
end

function M.randomSleep(min, max)
  return sleep(randomer:random(min, max))
end

function M.rawRandomSleep(min, max)
  return oldSleep(randomer:random(min, max))
end

function M.waitFor(func, timeout, response_time)
  local now_time = GetTimeOfDayMs()
  local start_time = now_time
  timeout = timeout or actionTimeout()
  response_time = response_time or responseTime()
  local last_find_time = 0
  while now_time - start_time < timeout do
    local reuslt = func()
    if reuslt then
      if last_find_time == 0 then
        last_find_time = now_time
      end
      if now_time - last_find_time > response_time then
        return reuslt
      end
    else
      last_find_time = 0
    end
    tickSleep()
    now_time = GetTimeOfDayMs()
  end
  return nil
end

-- 等待并查找一个UI节点
---@return UiNode|nil
function M.waitForNode(finder, timeout, response_time, visible)
  timeout = timeout or actionTimeout()
  local now_time = GetTimeOfDayMs()
  local start_time = now_time
  response_time = response_time or responseTime()
  local last_find_time = 0
  -- print(visible)
  while now_time - start_time < timeout do
    local node = finder:find()
    if visible then
      if node and node:visible() then
        -- print(1111)
        if last_find_time == 0 then
          last_find_time = now_time
        end
        if now_time - last_find_time >= 0 then
          return node
        end
      else
        if now_time - last_find_time > 500 then
          last_find_time = 0
        end
      end
    else
      if node then
        if last_find_time == 0 then
          last_find_time = now_time
        end
        if now_time - last_find_time >= 0 then
          return node
        end
      else
        if now_time - last_find_time > 500 then
          last_find_time = 0
        end
      end
    end

    tickSleep()
    now_time = GetTimeOfDayMs()
  end
  return nil
end

function M.openApp(packageName, activityName)
  local action_timeout = M.actionTimeout()
  local now_time = GetTimeOfDayMs()
  local start_time = now_time
  local action = false
  while now_time - start_time < action_timeout do
    local connectionFinder = By.text("Connection request")
    if ca.waitForNode(connectionFinder) then
      ca.commonWaitAndClickNode(By.text("CANCEL"))
    end
    if System.getPackageName() == packageName and System.getActivity() == activityName then
      return true
    end
    if not action then
      action = shell.startActivity(packageName, activityName)
    end
    tickSleep()
    now_time = GetTimeOfDayMs()
  end
  return false
end

function M.commonClickNode(node)
  M.clickNode(node)
  M.commonSleep()
  return true
end

function M.commonClickNodeShort(node)
  M.clickNodeShort(node)
  M.commonSleep()
  return true
end

-- 等待某个节点（通常是指UI界面上的一个元素）出现，并在出现后对其进行点击操作
function M.commonWaitAndClickNode(finder, timeout, response_time)
  local node = M.waitForNode(finder, timeout, response_time)
  if not node then
    logd("not find node")
    return false
  end
  -- print(1111)
  M.commonClickNode(node)
  return true
end

function M.randomTime(min, max)
  return randomer:random(min, max)
end

local function randomCoord(x1, y1, x2, y2)
  local x = action_randomer:random(x1, x2)
  local y = action_randomer:random(y1, y2)
  return x, y
end

---@param node UiNode
local function randomClickEdit(node)
  local x1, y1, x2, y2 = node:visibleBounds()
  -- logd(x1, y1, x2, y2)
  if y1 == y2 then
    logd(node:res())
    return false
  end
  local kShift <const> = 3
  -- 元素宽度
  local loc = (x2 - x1) // 10
  x1, x2 = x1 + loc * 5, x1 + loc * 6
  -- logd(x1 + kShift, y1 + kShift, x2 - kShift, y2 - kShift)
  return randomTap(x1 + kShift, y1 + kShift, x2 - kShift, y2 - kShift)
end

---@param finder UiNodeFilter
local function ensurehasFocus(finder)
  for i = 1, 3 do
    -- print(1111)
    local node = ca.waitForNode(finder, ca.actionTimeout())
    if not node then
      print(55555555)
      goto continue
    end
    -- print(2222)
    if node:focused() then
      return true
    end
    -- print(3333)
    if not randomClickEdit(node) then
      -- print(55555555)
      goto continue
    end
    ca.commonSleep()
    -- print(4444)
    if ca.waitFor(function()
          return node:focused()
        end, ca.actionTimeout(), ca.responseTime()) then
      return true
    end
    ::continue::
    ca.commonSleep()
  end
  return false
end


local function ensureClearText(finder, localText)
  local lastText
  local nowText
  for i = 1, 50 do
    local node = finder:find()
    if not node then
      goto continue
    end

    nowText = node:text()
    if type(localText) == "string" then
      if nowText == localText then
        return true
      end
    elseif type(localText) == "table" then
      if tablex.getKey(localText, nowText) then
        return true
      end
    end
    if nowText == "" then
      return true
    end
    if nowText == lastText then
      randomClickEdit(node)
    end
    if not ensurehasFocus(finder) then
      return false
    end
    keyPress(KeyCode.MENU)
    lastText = nowText
    ::continue::
    ca.randomSleep(220, 300)
  end
  return false
end

---@param finder UiNodeFilter
---@param text string
local function inputTextOnce(finder, text, notBlank)
  ca.randomSleep(2000, 4000)
  if not ensurehasFocus(finder) then
    print(111)
    return false
  end
  -- if not ensureClearText(finder, originalContent) then
  --   print(222)
  --   return false
  -- end
  if not ime.simInput(text) then
    print(333)
    return false
  end
  -- refreshWebView()
  return ca.waitFor(function()
    local node = finder:find()
    if not node then
      print(444)
      return false
    end
    local nowText = node:text()
    if notBlank then
      nowText = utils.notBlank(nowText)
    end
    -- print(nowText, text, nowText == text)
    -- print(type(nowText), type(text))
    return nowText == text
  end, ca.randomTime(800, 1100))
end

---@param finder UiNodeFilter
---@param text string
function M.ensureInputByFilter(finder, text, notBlank)
  for i = 1, 3 do
    logi("ensureInputByFilter", text)
    -- action_log.setLogs("input-begin" .. text)
    if inputTextOnce(finder, text, notBlank) then
      -- action_log.setLogs("input-end" .. text)
      return true
    end
    ca.commonSleep()
    local node = ca.waitForNode(finder, ca.actionTimeout())
    if node then
      randomClickEdit(node)
    end
  end
  return false
end

local function moveUp()
  local ox, oy = randomCoord(541, 1680, 642, 1774)
  local tx, ty = randomCoord(646, 1270, 728, 1444)
  local time = math.random(700, 950)
  local distance1 = math.random(100, 200)
  local distance2 = math.random(100, 200)
  local path = iutils.generatePath(ox, oy, tx, ty, -distance1, -distance2, time // 23)
  local pt = pointer()
  for _, v in ipairs(path) do
    pt.x = v[1]
    pt.y = v[2]
    pt:sync()
    M.rawRandomSleep(17, 23)
  end
  pt:up()
end


---@param finder UiNodeFilter
---@param site number 0-1
function M.ensureMoveUpTo(finder, site, timeout)
  local _, h = Display:getSize()
  local targetY = math.floor(h * site)
  timeout = timeout or 35000
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local x, y, x1, y1
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      goto continue
    end
    x, y, x1, y1 = node:visibleBounds()
    if y <= targetY then
      return true
    end
    ::continue::
    moveUp()
    ca.randomSleep(1100, 1311)
    nowTime = GetTimeOfDayMs()
  end
  return false
end

M.moveUp = moveUp


local timeDiffRecord = {}

function M.calculateTimeDiff(targetCountry)
  if timeDiffRecord[targetCountry] then
    return timeDiffRecord[targetCountry]
  end
  local targetCountryCurrentTime = net.getNowTime(targetCountry)
  if not targetCountryCurrentTime then
    return nil
  end
  local localCurrentTime = os.time()
  local timeDiff = os.difftime(targetCountryCurrentTime, localCurrentTime) // 60 // 60 * 60 * 60
  timeDiffRecord[targetCountry] = timeDiff
  return timeDiff
end

local sMoveDown = { 736, 1934, 784, 1987 }
local sMoveUp = { 820, 1409, 879, 1465 }

-- 修改后的坐标（短距离）
local sMoveDownShort = { 736, 1750, 784, 1800 } -- 将底部区域上移约200像素
local sMoveUpShort = { 820, 1550, 879, 1600 }   -- 将顶部区域下移约150像素

-- -- 修改后的坐标（长距离）
-- local sMoveDownLong = { 736, 1950, 784, 2000 } -- 将底部区域上移约200像素
-- local sMoveUpLong = { 820, 1300, 879, 1360 }

-- 修改后的坐标（长距离）
local sMoveDownLong = { 736, 1950, 784, 2000 } -- 将底部区域上移约200像素
local sMoveUpLong = { 820, 1000, 879, 1060 }

-- 修改后的坐标（更短距离）
local sMoveDownShortMini = { 736, 1700, 784, 1750 } -- 将底部区域再上移50像素
local sMoveUpShortMini = { 820, 1600, 879, 1650 }   -- 将顶部区域再下移50像素

-- local function moveS(o, t)
--   -- local ox,oy = randomCoord(541,1680,642,1774)
--   -- local tx,ty = randomCoord(646,870,728,944)
--   local ox, oy = randomCoord(table.unpack(o))
--   local tx, ty = randomCoord(table.unpack(t))
--   local time = math.random(700, 900)
--   local distance1 = math.random(100, 180)
--   local distance2 = math.random(100, 180)
--   local path = iutils.generatePath(ox, oy, tx, ty, -distance1, -distance2, time // 23)
--   local pt = pointer()
--   for _, v in ipairs(path) do
--     pt.x = v[1]
--     pt.y = v[2]
--     pt.pressure = math.random(35, 50)
--     pt:sync()
--     M.rawRandomSleep(17, 23)
--   end
--   pt:up()
-- end

local function moveS(o, t)
  local ox, oy = randomCoord(table.unpack(o))
  local tx, ty = randomCoord(table.unpack(t))
  -- action_log.setLogs("move: 【起始坐标】 " .. ox .. "," .. oy .. " 【终止坐标】" .. tx .. "," .. ty)
  -- 计算实际滑动距离
  local dx, dy = tx - ox, ty - oy
  local distance = math.sqrt(dx * dx + dy * dy)

  -- 动态控制弧度：距离越长，允许的偏移越大，但有上限
  local max_offset = math.floor(math.min(100, distance * 0.25)) -- 最多偏移距离的 15%，且不超过 60px，并转换为整数
  local min_offset = math.ceil(math.max(20, distance * 0.08))   -- 至少偏移 8px 避免完全直线，并转换为整数

  local offset1 = -math.random(min_offset, max_offset)
  local offset2 = -math.random(min_offset, max_offset)

  local options = {
    humanize = {
      control_jitter = 20, -- 控制点微扰（让弧线不完美）
      path_jitter = 6,     -- 路径抖动极小！<1像素
      timing = {
        total_ms = math.random(650, 850)
      }
    }
  }

  local path = iutils.generatePath(
    ox, oy, tx, ty,
    offset1,
    offset2,
    math.random(32, 57), -- 触控点数量
    options
  )

  local pt = pointer()
  local last_time = 0
  for _, v in ipairs(path) do
    pt.x = v[1]
    pt.y = v[2]
    pt.pressure = v[4] or math.random(50, 70) -- 使用生成的压力值
    pt:sync()

    if v[3] then
      local delay = v[3] - last_time
      if delay > 0 then
        -- 微小随机偏移（±5%）
        M.rawRandomSleep(delay * 0.95, delay * 1.05)
      end
      last_time = v[3]
    else
      M.rawRandomSleep(20, 30)
    end
  end
  pt:up()
end

local function moveToUpS()
  return moveS(sMoveDown, sMoveUp)
end

local function moveToDownS()
  return moveS(sMoveUp, sMoveDown)
end
M.moveToDownS = moveToDownS
M.moveToUpS = moveToUpS

-- 超短距离滑动
local function moveShort(o, t)
  local ox, oy = randomCoord(table.unpack(o))
  local tx, ty = randomCoord(table.unpack(t))

  local time = math.random(700, 900)                                                   -- 非常短的滑动时间
  local distance1 = math.random(30, 60)                                                -- 很小的控制点偏移
  local distance2 = math.random(30, 60)                                                -- 很小的控制点偏移

  local path = iutils.generatePath(ox, oy, tx, ty, -distance1, -distance2, time // 10) -- 很少的点

  local pt = pointer()
  for _, v in ipairs(path) do
    pt.x = v[1]
    pt.y = v[2]
    pt.pressure = math.random(15, 25)
    pt:sync()
    M.rawRandomSleep(5, 8) -- 极短的延迟
  end
  pt:up()
end

-- 超短距离滑动
local function moveShortMini(o, t)
  local ox, oy = randomCoord(table.unpack(o))
  local tx, ty = randomCoord(table.unpack(t))

  local time = math.random(700, 900)                                                   -- 非常短的滑动时间
  local distance1 = math.random(30, 60)                                                -- 很小的控制点偏移
  local distance2 = math.random(30, 60)                                                -- 很小的控制点偏移

  local path = iutils.generatePath(ox, oy, tx, ty, -distance1, -distance2, time // 10) -- 很少的点

  local pt = pointer()
  for _, v in ipairs(path) do
    pt.x = v[1]
    pt.y = v[2]
    pt.pressure = math.random(15, 25)
    pt:sync()
    M.rawRandomSleep(5, 8) -- 极短的延迟
  end
  pt:up()
end

local function moveToUpShortMini()
  -- return moveShortMini(sMoveDownShortMini, sMoveUpShortMini)
  return moveS(sMoveDownShortMini, sMoveUpShortMini)
end
local function moveToDownShortMini()
  return moveS(sMoveUpShortMini, sMoveDownShortMini)
end

local function moveToUpShort()
  -- return moveShort(sMoveDownShort, sMoveUpShort)
  return moveS(sMoveDownShort, sMoveUpShort)
end

local function moveToDownShort()
  -- return moveShort(sMoveUpShort, sMoveDownShort)
  return moveS(sMoveUpShort, sMoveDownShort)
end

M.moveToUpShortMini = moveToUpShortMini
M.moveToDownShortMini = moveToDownShortMini
M.moveToUpShort = moveToUpShort
M.moveToDownShort = moveToDownShort

local function moveToUpLong()
  return moveS(sMoveDownLong, sMoveUpLong)
end

local function moveToDownLong()
  return moveS(sMoveUpLong, sMoveDownLong)
end
M.moveToUpShort = moveToUpShort
M.moveToDownShort = moveToDownShort
M.moveToUpLong = moveToUpLong
M.moveToDownLong = moveToDownLong

-- 将一个节点移动到屏幕的特定范围内
function M.moveToRangeOnce(finder, min, max)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local node = finder:find()
  if not node then
    return false
  end
  local x, y, x1, y1 = node:visibleBounds()
  if y < minTargetY then
    moveToDownS()
  elseif y > maxTargetY then
    moveToUpS()
  else
    return true
  end
  return false
end

-- 通过随机参数来实现重载，如果是两个参数，则调用moveToRange，否则调用moveToRangeSpeed
function M.moveToRangeOverload(...)
  local parameter = { ... }
  if #parameter == 4 then
    -- 固定滑动速度
    M.moveToRange(...)
  else
    -- 根据最后一个参数来确定滑动参数
    M.moveToRangeSpeed(...)
  end
end

---@param node UiNode
---@param min integer
---@param max integer
function M.moveToRangeForNode(node, min, max, timeout)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 20000
  local x, y, x1, y1
  while nowTime - startTime < timeout do
    if not node then
      print(1111)
      moveToUpS()
      goto continue
    end
    x, y, x1, y1 = node:visibleBounds()
    print(x, y, x1, y1)
    print(minTargetY)
    if y < minTargetY then
      print(2222)
      moveToDownS()
    elseif y > maxTargetY then
      print(3333)
      moveToUpS()
    else
      -- print(4444)
      return true
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

---@param finder UiNodeFilter
---@param min integer
---@param max integer
function M.moveToRange(finder, min, max, timeout)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 60000
  local x, y, x1, y1
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      print(1111)
      moveToUpS()
      goto continue
    end
    x, y, x1, y1 = node:visibleBounds()
    print(x, y, x1, y1)
    logd("minTargetY:", minTargetY)
    logd("maxTargetY:", maxTargetY)
    if y < minTargetY then
      print(2222)
      moveToDownS()
    elseif y > maxTargetY then
      print(3333)
      moveToUpS()
    else
      logi("y:", y, "minTargetY:", minTargetY, "maxTargetY:", maxTargetY)
      print(4444)
      return true
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

---@param finder UiNodeFilter
---@param min integer
---@param max integer
function M.moveToDownRange(finder, min, max, timeout)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 20000
  local x, y, x1, y1
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      print(1111)
      moveToDownS()
      goto continue
    end
    x, y, x1, y1 = node:visibleBounds()
    if y < minTargetY then
      print(2222)
      moveToDownS()
    elseif y > maxTargetY then
      print(3333)
      moveToUpS()
    else
      return true
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

---@param finder UiNodeFilter
---@param min integer
---@param max integer
function M.moveToUpRange(finder, min, max, timeout)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 20000
  local x, y, x1, y1
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      print(1111)
      moveToUpS()
      goto continue
    end
    x, y, x1, y1 = node:visibleBounds()
    if y > minTargetY then
      print(2222)
      -- moveToUpS()
    elseif y < maxTargetY then
      print(3333)
      moveToDownS()
    else
      return true
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

---@param finder UiNodeFilter
---@param min integer
---@param max integer
function M.moveToUpShortRange(finder, min, max, timeout)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 20000
  local x, y, x1, y1
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      print(1111)
      moveToUpShort()
      goto continue
    end
    x, y, x1, y1 = node:visibleBounds()
    if y > minTargetY then
      print(2222)
      moveToUpShort()
    elseif y < maxTargetY then
      print(3333)
      moveToDownShort()
    else
      return true
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

local function moveSSpeed(o, t, time)
  local ox, oy = randomCoord(541, 1680, 642, 1774)
  local tx, ty = randomCoord(646, 1270, 728, 1444)
  local time1 = math.random(time, time + 200)
  local distance1 = math.random(100, 180)
  local distance2 = math.random(100, 180)
  local path = iutils.generatePath(ox, oy, tx, ty, -distance1, -distance2, time1 // 23)
  local pt = pointer()
  for _, v in ipairs(path) do
    pt.x = v[1]
    pt.y = v[2]
    pt.pressure = math.random(35, 50)
    pt:sync()
    M.rawRandomSleep(17, 23)
  end
  pt:up()
end

local function moveSSpeedDistance(o, t, time, dis1, dis2)
  local ox, oy = randomCoord(table.unpack(o))
  local tx, ty = randomCoord(table.unpack(t))
  local time1 = math.random(time, time + 200)
  local distance1 = dis1
  local distance2 = dis2
  local path = iutils.generatePath(ox, oy, tx, ty, -distance1, -distance2, time1 // 23)
  local pt = pointer()
  for _, v in ipairs(path) do
    pt.x = v[1]
    pt.y = v[2]
    pt.pressure = math.random(35, 50)
    pt:sync()
    M.rawRandomSleep(17, 23)
  end
  pt:up()
end

local function moveToUpSSpeed(speedTime)
  return moveSSpeed(sMoveDown, sMoveUp, speedTime)
end

local function moveToDownSSpeed(speedTime)
  return moveSSpeed(sMoveUp, sMoveDown, speedTime)
end

-- 将一个节点移动到屏幕的特定范围内
function M.moveToRangeOnceSpeed(finder, min, max, speedTime)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local node = finder:find()
  if not node then
    return false
  end
  local x, y, x1, y1 = node:visibleBounds()
  if y < minTargetY then
    moveToDownSSpeed(speedTime)
  elseif y > maxTargetY then
    moveToUpSSpeed(speedTime)
  else
    return true
  end
  return false
end

---@param finder UiNodeFilter
---@param min integer
---@param max integer
function M.moveToRangeSpeed(finder, min, max, timeout, speedTime)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 20000
  local x, y, x1, y1
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      moveToUpSSpeed(speedTime)
      goto continue
    end
    x, y, x1, y1 = node:visibleBounds()
    if y < minTargetY then
      moveToDownSSpeed(speedTime)
    elseif y > maxTargetY then
      moveToUpSSpeed(speedTime)
    else
      return true
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

function M.waitForVanishWithNode(finder, timeout, minVanishTime)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local lastVanishTime = 0
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      if lastVanishTime == 0 then
        lastVanishTime = nowTime
      end
      if nowTime - lastVanishTime > minVanishTime then
        return true
      end
    else
      lastVanishTime = 0
    end
    ::continue::
    M.tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

function M.assert(condition, message)
  if not condition then
    net.stopTask()
    error(message)
  end
end

local function generateActionInterval(actionIntervalType)
  if actionIntervalType == 0 then
    return M.randomTime(3000, 5000)
  elseif actionIntervalType == 1 then
    return M.randomTime(5000, 7000)
  elseif actionIntervalType == 2 then
    return M.randomTime(7000, 9000)
  end
end

---@param clickable UiNodeFilter
---@param target UiNodeFilter
---@param timeout number
---@param actionIntervalType number 0-3000-5000,1-5000-7000,2-7000-9000
---@return integer 0-success,1-timeout,2-background
function M.ensureClickToByNode(clickable, target, timeout, actionIntervalType, reactionTime)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  actionIntervalType = actionIntervalType or 0
  reactionTime = reactionTime or M.reactionTime()
  local lastFindTime = 0
  local actionInterval = generateActionInterval(actionIntervalType)
  while nowTime - startTime < timeout do
    local node = target:find()
    if node then
      return 0
    end
    node = clickable:find()
    if node then
      if lastFindTime == 0 then
        lastFindTime = nowTime
      elseif nowTime - lastFindTime > reactionTime and nowTime - lastActionTime > actionInterval then
        M.clickNode(node)
        lastFindTime = 0
        lastActionTime = nowTime
        actionInterval = generateActionInterval(actionIntervalType)
      end
    end
    tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return 1
end

local function isWakeLock()
  local result = shell.exec("cat /sys/class/backlight/*/brightness")
  return tonumber(result) > 0
end

function M.unlockP5()
  local unlockButton = By.res("com.android.systemui:id/lock_icon")
  if not isWakeLock() then
    keyPress(KeyCode.POWER)
    M.commonSleep()
    M.moveUp()
  end
  local node = M.waitForNode(unlockButton, 1000)
  if node then
    M.clickNode(node)
  end
end

---@param type integer|nil 0-4  0-230-410,1-800-1100,2-1500-1900,3-2300-2900,4-3000-3700
function M.reactionTime(type)
  type = type or 0
  if type == 0 then
    return randomer:random(230, 410)
  elseif type == 1 then
    return randomer:random(800, 1100)
  elseif type == 2 then
    return randomer:random(1500, 1900)
  elseif type == 3 then
    return randomer:random(2300, 2900)
  elseif type == 4 then
    return randomer:random(3000, 3700)
  end
end

function M.waitForNodes(finder, timeout, response_time, visible)
  timeout = timeout or actionTimeout()
  local now_time = GetTimeOfDayMs()
  local start_time = now_time
  response_time = response_time or responseTime()
  local last_find_time = 0

  while now_time - start_time < timeout do
    local nodes = finder:finds()

    if nodes and #nodes > 0 then
      -- 如果有可见性要求
      if visible then
        local visibleNodes = {}

        -- 只收集可见的节点
        for _, node in ipairs(nodes) do
          if node:visible() then
            table.insert(visibleNodes, node)
          end
        end

        -- 如果没有可见节点，继续等待
        if #visibleNodes == 0 then
          goto continue
        end

        -- 使用可见节点替换原节点数组
        nodes = visibleNodes
      end

      -- 满足条件
      if last_find_time == 0 then
        last_find_time = now_time
      end

      if now_time - last_find_time > response_time then
        return nodes
      end
    end

    ::continue::
    tickSleep()
    now_time = GetTimeOfDayMs()
  end
  return nil
end

-- ---@return UiNode[]|nil
-- function M.waitForNodes(finder, timeout, response_time, visible)
--   timeout = timeout or actionTimeout()
--   local now_time = GetTimeOfDayMs()
--   local start_time = now_time
--   response_time = response_time or responseTime()
--   local last_find_time = 0
--   -- print(visible)
--   while now_time - start_time < timeout do
--     local nodes = finder:finds()
--     if visible then
--       if nodes and nodes:visible() then
--         if last_find_time == 0 then
--           last_find_time = now_time
--         end
--         if now_time - last_find_time > response_time then
--           return nodes
--         end
--       end
--     else
--       if nodes then
--         if last_find_time == 0 then
--           last_find_time = now_time
--         end
--         if now_time - last_find_time > response_time then
--           return nodes
--         end
--       end
--     end

--     tickSleep()
--     now_time = GetTimeOfDayMs()
--   end
--   return nil
-- end

local SelectFinder = class.new("SelectFinder")

function SelectFinder:ctor(finder, index)
  self.finder = finder
  self.index = index
end

function SelectFinder:find()
  local nodes = self.finder:finds()
  if not nodes then
    return nil
  end
  return nodes[self.index]
end

function M.selectFinder(finder, index)
  return class.instance(SelectFinder, finder, index)
end

local WhichFinder = class.new("WhichFinder")

function WhichFinder:ctor(...)
  self.finders = { ... }
end

function WhichFinder:find()
  for _, v in ipairs(self.finders) do
    local node = v:find()
    if node then
      return node
    end
  end
  return nil
end

function WhichFinder:finds()
  local result = {}
  for _, v in ipairs(self.finders) do
    local nodes = v:finds()
    if nodes then
      for _, node in ipairs(nodes) do
        table.insert(result, node)
      end
    end
  end
  return #result > 0 and result or nil
end

local WhichFinderOne = class.new("WhichFinderOne")

function WhichFinderOne:ctor(...)
  self.finders = { ... }
end

function WhichFinderOne:find()
  for _, v in ipairs(self.finders) do
    local node = v:find()
    if node then
      return node
    end
  end
  return nil
end

function WhichFinderOne:finds()
  for _, v in ipairs(self.finders) do
    local nodes = v:finds()
    -- print(nodes)
    if nodes and #nodes > 0 then
      return nodes
    end
  end
end

local ChildFinder = class.new("ChildFinder")

function ChildFinder:ctor(finder, index)
  self.finder = finder
  self.index = index
end

function ChildFinder:find()
  local node = self.finder:find()
  if not node then
    return nil
  end
  return node:child(self.index)
end

---@param finder UiNodeFilter
---@param index integer
---@return UiNodeFilter
function M.childFinder(finder, index)
  return class.instance(ChildFinder, finder, index)
end

local FinderWrapper = class.new("FinderWrapper")

function FinderWrapper:ctor(func)
  self.func = func
end

function FinderWrapper:find()
  return self.func()
end

---@return UiNodeFilter
function M.finderWrapper(func)
  return class.instance(FinderWrapper, func)
end

---@param ... UiNodeFilter
---@return UiNodeFilter
function M.whichFinder(...)
  return class.instance(WhichFinder, ...)
end

---@param ... UiNodeFilter
---@return UiNodeFilter
function M.whichFinderOne(...)
  return class.instance(WhichFinderOne, ...)
end

local WebViewFinder = By.clz("android.webkit.WebView")

---@param node UiNode|nil
---@param depth number
---@return boolean
local function hasDepth(node, depth)
  if not node then
    return false
  end
  if depth == 0 then
    return true
  end
  for i = 0, node:childCount() - 1 do
    local child = node:child(i)
    if hasDepth(child, depth - 1) then
      return true
    end
  end
  return false
end


---@param clickable UiNodeFilter
---@param target UiNodeFilter
---@param timeout number
---@param actionIntervalType number 0-3000-5000,1-5000-7000,2-7000-9000
---@param reactionTime number|nil
---@return integer 0-success,1-timeout,2-background
function M.ensureClickToByNodeOnWebView(clickable, target, timeout, actionIntervalType, reactionTime)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  actionIntervalType = actionIntervalType or 0
  reactionTime = reactionTime or M.reactionTime()
  local lastFindTime = 0
  local actionInterval = generateActionInterval(actionIntervalType)
  while nowTime - startTime < timeout do
    local node = target:find()
    if node and node:visible() then
      return 0
    end
    node = clickable:find()
    if node and node:visible() then
      if lastFindTime == 0 then
        lastFindTime = nowTime
      elseif nowTime - lastFindTime > reactionTime and nowTime - lastActionTime > actionInterval then
        -- print(2222)
        M.clickNode(node)
        -- M.commonSleep()
        M.randomSleep(3000, 5000)
        lastFindTime = 0
        lastActionTime = nowTime
        actionInterval = generateActionInterval(actionIntervalType)
      end
    end
    tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return 1
end

---@param clickable UiNodeFilter
---@param target UiNodeFilter
---@param timeout number
---@param actionIntervalType number 0-3000-5000,1-5000-7000,2-7000-9000
---@return integer 0-success,1-timeout,2-background
function M.ensureClickToByNodeOnWebViewTryCount(clickable, target, timeout, actionIntervalType, reactionTime)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  actionIntervalType = actionIntervalType or 0
  reactionTime = reactionTime or M.reactionTime()
  local lastFindTime = 0
  local actionInterval = generateActionInterval(actionIntervalType)
  local tryMaxCount = 4
  local targetCount = 0
  while nowTime - startTime < timeout do
    local node = WebViewFinder:find()
    if not node or not hasDepth(node, 3) then
      if nowTime - lastActionTime > actionInterval then
        refreshWebView()
        lastActionTime = nowTime
        actionInterval = generateActionInterval(actionIntervalType)
        goto continue
      end
    end
    node = target:find()
    if node then
      return 0
    end
    node = clickable:find()
    if node then
      if lastFindTime == 0 then
        lastFindTime = nowTime
      elseif nowTime - lastFindTime > reactionTime and nowTime - lastActionTime > actionInterval then
        targetCount = targetCount + 1
        print("targetCount:", targetCount)
        -- 如果尝试了5次后，还不行就，下拉一下，再点击
        if targetCount == tryMaxCount
            or targetCount == tryMaxCount + 5
            or targetCount == tryMaxCount + 10
            or targetCount == tryMaxCount + 15
            or targetCount == tryMaxCount + 20 then
          print("超过最大尝试次数，下拉刷新一下！")
          -- 下拉一下
          chromium.clickUrlEdit()
          ca.commonSleep()
        end
        M.clickNode(node)
        ca.commonSleep()
        M.clickNode(node)
        lastFindTime = 0
        lastActionTime = nowTime
        actionInterval = generateActionInterval(actionIntervalType)
      end
    end
    ::continue::
    tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return 1
end

-- 在超时时间内就点击一次
---@param clickable UiNodeFilter
---@param target UiNodeFilter
---@param timeout number
---@return integer 0-success,1-timeout,2-background
function M.ensureClickToByNodeOnWebViewOnce(clickable, target, timeout)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local hasClicked = false

  while nowTime - startTime < timeout do
    -- 检查目标元素是否存在
    local targetNode = target:find()
    if targetNode then
      return 0 -- 找到目标元素，返回成功
    end

    -- 如果还没点击过，尝试点击
    if not hasClicked then
      local clickableNode = clickable:find()
      if clickableNode then
        M.clickNode(clickableNode)
        hasClicked = true
        ca.commonSleep()
      end
    end

    tickSleep()
    nowTime = GetTimeOfDayMs()
  end

  return 1 -- 超时
end

-- 滑动屏幕
M.randomSwipe = function()
  moveToDownS()
  ca.randomSleep(200, 300)
  moveToUpS()
end

function M.moveToUpSSpeed(speedTime)
  return moveSSpeed(sMoveDown, sMoveUp, speedTime)
end

function M.moveToDownSSpeed(speedTime)
  return moveSSpeed(sMoveUp, sMoveDown, speedTime)
end

function M.moveToUpSSpeedDistance(speedTime, distance1, distance2)
  return moveSSpeedDistance(sMoveDown, sMoveUp, speedTime, distance1, distance2)
end

function M.moveToDownSSpeedDistance(speedTime, distance1, distance2)
  return moveSSpeedDistance(sMoveUp, sMoveDown, speedTime, distance1, distance2)
end

local screenWidth = 1080
local screenHeight = 1920

--- 随机移动手指
function M.pointerRandomMove(pointer)
  -- local w,h = Display:getSize()
  -- local minTargetY = math.floor(h*min)
  -- local maxTargetY = math.floor(h*max)
  -- 生成随机的坐标
  local x = math.random(0, screenWidth)
  local y = math.random(500, 800)
  -- 设置手指的坐标
  pointer.x = x
  pointer.y = y
  -- 同步手指状态到屏幕
  pointer:sync()

  print("x" .. pointer.x, "y" .. pointer.y)
  -- 随机等待一段时间
  local waitTime = math.random(1000, 2000) -- 0.5秒到1秒之间
  sleep(waitTime)
end

local rawSleep = sleep
local coroutine = require "coroutine"
local isYieldable = coroutine.isyieldable

local function randomTime(min, max)
  return sleepRandomer:random(min, max)
end

local function actionTimeout()
  return randomTime(3000, 4000)
end

M.actionTimeout = actionTimeout

local function netTimeout()
  return randomTime(95000, 100000)
end

M.netTimeout = netTimeout


local function randomResponseTime()
  return randomTime(230, 410)
end


M.randomTime = randomTime

local function rawRandomSleep(min, max)
  return rawSleep(randomTime(min, max))
end

local function sleepByYield(time)
  local startTime = getTimeOfDayMs()
  while getTimeOfDayMs() - startTime < time do
    yield(kYield)
  end
end

local function randomSleepByYield(min, max)
  return sleepByYield(randomTime(min, max))
end

function M.resetTask()
  yield(kReset)
end

local function randomSleep(min, max)
  if isYieldable() then
    return randomSleepByYield(min, max)
  else
    return rawRandomSleep(min, max)
  end
end

function M.sleep(time)
  if isYieldable() then
    return sleepByYield(time)
  else
    return rawSleep(time)
  end
end

local function rawTickSleep()
  return rawRandomSleep(73, 131)
end

M.randomSleep = randomSleep

local function tickSleep()
  if isYieldable() then
    return yield(kYield)
  else
    return rawTickSleep()
  end
end

M.tickSleep = tickSleep

local function commonSleep()
  return randomSleep(600, 730)
end

M.commonSleep = commonSleep

local function overTask()
  if isYieldable() then
    return yield(kOver)
  end
end

local _guardList = {}

local function addNewGuard(condition, action, prority, name)
  assert(name, "name is required")
  local guard = {
    condition = condition,
    action = action,
    prority = prority,
    running = false,
    thread = coroutine.create(action),
    name = name
  }
  table.insert(_guardList, guard)
  return guard
end

M.addNewGuard = addNewGuard

local function trueFuc()
  return true
end


M.overTask = overTask

local function removeGuard(guard)
  for i, v in ipairs(_guardList) do
    if v == guard then
      table.remove(_guardList, i)
      break
    end
  end
end

M.removeGuard = removeGuard

-- 错误处理器管理
local ErrorHandler = {
  handlers = {},
  currentMainTask = nil,
  isRecovering = false
}

-- 注册错误处理函数
function M.registerErrorHandler(name, handlerFunc)
  ErrorHandler.handlers[name] = handlerFunc
end

-- 执行错误处理并替换主任务
function M.handleAndReplaceMainTask(errorMsg, errorTaskFunc)
  logi("执行错误处理: " .. (errorMsg or "未知错误"))

  -- 保存当前状态
  local oldTask = ErrorHandler.currentMainTask

  -- 创建错误处理任务包装器
  local wrappedErrorTask = function()
    logi("开始执行错误恢复任务...")

    -- 执行错误处理代码
    local success, result = pcall(errorTaskFunc, errorMsg)

    if success then
      logi("错误处理任务执行成功")
      -- 错误处理完成后，可以选择恢复原任务或执行新任务
      if result and type(result) == "function" then
        -- 返回一个新的主任务函数
        logi("切换到新任务")
        return result()
      elseif oldTask and not ErrorHandler.isRecovering then
        -- 恢复原任务
        logi("恢复原始主任务")
        ErrorHandler.currentMainTask = oldTask
        return oldTask()
      end
    else
      loge("错误处理任务失败: " .. tostring(result))
    end

    logd("结束错误处理任务")
    M.overTask()
  end

  -- 标记为恢复状态
  ErrorHandler.isRecovering = true
  ErrorHandler.currentMainTask = wrappedErrorTask

  -- 直接替换主线程的协程
  for i, guard in ipairs(_guardList) do
    if guard.name == "main thread" then
      -- 替换协程
      guard.action = wrappedErrorTask
      guard.thread = coroutine.create(wrappedErrorTask)
      logi("已替换主任务为错误处理任务")
      return guard
    end
  end

  return nil
end

-- -- resume 错误处理部分
-- function M.safeResume(guard)
--   local status, result = coroutine.resume(guard.thread)

--   if not status then
--     -- 协程出错
--     local errMsg = tostring(result)

--     -- 查找注册的错误处理器
--     for handlerName, handlerFunc in pairs(ErrorHandler.handlers) do
--       logi("尝试使用错误处理器: " .. handlerName)

--       -- replacement 处理器函数的返回值
--       local success, replacement = pcall(handlerFunc, errMsg, guard)
--       if success and replacement then
--         -- 返回一个替换后的守卫
--         return "REPLACED", replacement
--       end
--     end

--     -- 没有找到处理器，抛出错误
--     error(errMsg)
--   end

--   return "OK", result
-- end

local recoveryChainCount = 0 -- 当前恢复链的长度
local MAX_RECOVERY_CHAIN = 1 -- 最大恢复链长度

function M.setMaxRecoveryChain(length)
  MAX_RECOVERY_CHAIN = length
  logi("设置最大恢复链长度为: " .. length)
end

-- -- resume 错误处理部分
-- function M.safeResume(guard)
--   if not guard then -- 添加守卫检查
--     return "ERROR", {}
--   end
--   local status, result = coroutine.resume(guard.thread)

--   if not status then
--     local errMsg = tostring(result)

--     -- 检查 init_step 条件
--     if not INIT_STEP or INIT_STEP ~= "step3" then
--       -- 不在 step3 阶段，直接抛出错误，不进行错误恢复
--       logi(string.format(
--         "任务出错但未启用错误恢复 (init_step=%s, 任务=%s)",
--         tostring(INIT_STEP), guard.name or "未知"
--       ))
--       error(string.format("错误[阶段%s]: %s", tostring(INIT_STEP), errMsg))
--     end

--     -- 判断当前守卫类型
--     local isMainThread = (guard.name == "main thread")
--     local isRecoveryTask = guard.isRecoveryTask

--     logi(string.format("任务出错: %s (类型: %s, 当前链长: %d/%d)",
--       guard.name,
--       isMainThread and "主线程" or (isRecoveryTask and "恢复任务" or "普通任务"),
--       recoveryChainCount,
--       MAX_RECOVERY_CHAIN
--     ))

--     -- 主线程出错：开始新的恢复链
--     if isMainThread then
--       recoveryChainCount = 1
--       logi("主线程出错，开始恢复链 (1/" .. MAX_RECOVERY_CHAIN .. ")")
--       -- 恢复任务出错：增加恢复链长度
--     elseif isRecoveryTask then
--       recoveryChainCount = recoveryChainCount + 1
--       logi(string.format("恢复任务出错，恢复链增长: %d/%d",
--         recoveryChainCount, MAX_RECOVERY_CHAIN))
--     end

--     -- 检查是否超过最大恢复链长度
--     if recoveryChainCount > MAX_RECOVERY_CHAIN then
--       local finalError = string.format(
--         "恢复链长度超过最大限制(%d)，系统停止\n" ..
--         "错误链: %s -> ... (共%d次尝试)\n" ..
--         "最终错误: %s",
--         MAX_RECOVERY_CHAIN,
--         guard.name,
--         recoveryChainCount,
--         errMsg
--       )
--       recoveryChainCount = 0
--       error(finalError)
--     end

--     -- 查找错误处理器
--     for handlerName, handlerFunc in pairs(ErrorHandler.handlers) do
--       logi("调用错误处理器: " .. handlerName .. " (链长: " .. recoveryChainCount .. ")")

--       local success, replacement = pcall(handlerFunc, errMsg, guard)
--       if success and replacement then
--         -- 标记新任务为恢复任务
--         if type(replacement) == "table" then
--           replacement.isRecoveryTask = true
--           replacement.recoveryChainIndex = recoveryChainCount
--         end
--         return "REPLACED", replacement
--       end
--     end

--     -- 没有处理器能处理，重置计数
--     recoveryChainCount = 0
--     error("没有错误处理器能处理: " .. errMsg)
--   end

--   -- 任务正常完成，重置恢复链
--   if result == kOver or result == kReset then
--     recoveryChainCount = 0
--     logi("任务正常结束，重置恢复链")
--   end

--   -- logd(status, result)
--   return "OK", result
-- end

-- resume 错误处理部分
function M.safeResume(guard)
  if not guard then
    return "ERROR", {}
  end

  local status, result = coroutine.resume(guard.thread)

  if not status then
    local errMsg = tostring(result)

    -- 检查 init_step 条件
    if not INIT_STEP or INIT_STEP ~= "step3" then
      logi(string.format(
        "任务出错但未启用错误恢复 (init_step=%s, 任务=%s)",
        tostring(INIT_STEP), guard.name or "未知"
      ))
      error(string.format("错误[阶段%s]: %s", tostring(INIT_STEP), errMsg))
    end

    -- 修改判断逻辑：通过 isRecoveryTask 属性判断，而不是名字
    local isMainThread = (guard.name == "main thread" and not guard.isRecoveryTask)
    local isRecoveryTask = guard.isRecoveryTask or (guard.name == "error recovery")

    logi(string.format("任务出错: %s (类型: %s, 当前链长: %d/%d)",
      guard.name,
      isMainThread and "主线程" or (isRecoveryTask and "恢复任务" or "普通任务"),
      recoveryChainCount,
      MAX_RECOVERY_CHAIN
    ))

    -- 主线程出错：开始新的恢复链
    if isMainThread then
      recoveryChainCount = 1
      logi("主线程出错，开始恢复链 (1/" .. MAX_RECOVERY_CHAIN .. ")")
      -- 恢复任务出错：增加恢复链长度
    elseif isRecoveryTask then
      recoveryChainCount = recoveryChainCount + 1
      logi(string.format("恢复任务出错，恢复链增长: %d/%d",
        recoveryChainCount, MAX_RECOVERY_CHAIN))
    else
      -- 普通任务出错，不影响恢复链
      logi("普通任务出错，不影响恢复链")
    end

    -- 修改这里：超过最大长度时优雅结束
    if recoveryChainCount > MAX_RECOVERY_CHAIN then
      local finalMsg = string.format(
        "恢复链长度超过最大限制(%d)，优雅结束\n" ..
        "错误链: %s -> ... (共%d次尝试)\n" ..
        "最终错误: %s",
        MAX_RECOVERY_CHAIN,
        guard.name,
        recoveryChainCount,
        errMsg
      )
      logi(finalMsg)
      recoveryChainCount = 0

      -- 返回特殊标记，让run函数知道要结束
      return "MAX_RECOVERY_EXCEEDED", {
        message = finalMsg,
        guard = guard,
        errMsg = errMsg
      }
    end

    -- 查找错误处理器
    for handlerName, handlerFunc in pairs(ErrorHandler.handlers) do
      logi("调用错误处理器: " .. handlerName .. " (链长: " .. recoveryChainCount .. ")")

      local success, replacement = pcall(handlerFunc, errMsg, guard)
      if success and replacement then
        -- 标记新任务为恢复任务
        if type(replacement) == "table" then
          replacement.isRecoveryTask = true
          replacement.recoveryChainIndex = recoveryChainCount
        end
        return "REPLACED", replacement
      end
    end

    -- 没有处理器能处理，重置计数
    recoveryChainCount = 0

    -- 也可以选择优雅结束而不是error
    local noHandlerMsg = "没有错误处理器能处理: " .. errMsg
    logi(noHandlerMsg)
    return "NO_HANDLER", {
      message = noHandlerMsg,
      guard = guard,
      errMsg = errMsg
    }
  end

  -- 任务正常完成，重置恢复链
  if result == kOver or result == kReset then
    recoveryChainCount = 0
    logi("任务正常结束，重置恢复链")
  end

  -- logd(status, result)
  return "OK", result
end

function M.run(func)
  -- 保存当前主任务
  ErrorHandler.currentMainTask = func

  local mainThread = addNewGuard(trueFuc, func, 0, "main thread")
  local nowGuard = mainThread

  while true do
    for _, guard in ipairs(_guardList) do
      if guard.condition() then
        if nowGuard ~= guard then
          if not nowGuard or guard.prority > nowGuard.prority then
            if nowGuard then
              logi(string.format("change task %s to %s", nowGuard.name, guard.name))
            end
            nowGuard = guard
          end
        end
      end
    end

    -- 如果 nowGuard 为空，尝试重新选择
    if not nowGuard then
      nowGuard = _guardList[1]
      if not nowGuard then
        logi("没有可用任务，自然结束")
        break
      end
    end

    -- 安全地恢复协程
    local status, result = M.safeResume(nowGuard)

    if status == "REPLACED" then
      -- 任务已被错误处理器替换
      nowGuard = result
      goto continue
    elseif status == "MAX_RECOVERY_EXCEEDED" then
      -- 超过最大恢复链长度，优雅结束
      logi("超过最大恢复次数，程序优雅结束")
      logi(result.message)

      -- 可以在这里执行一些清理工作
      if M.onMaxRecoveryExceeded then
        M.onMaxRecoveryExceeded(result)
      end

      break -- 退出主循环，自然结束
    elseif status == "NO_HANDLER" then
      -- 没有处理器能处理错误，优雅结束
      logi("没有错误处理器，程序优雅结束")
      logi(result.message)

      if M.onNoErrorHandler then
        M.onNoErrorHandler(result)
      end

      break
    elseif status == "ERROR" then
      -- 其他错误，结束
      logi("发生错误，程序结束")
      break
    end

    -- 处理协程的正常返回值
    if result == kOver then
      removeGuard(nowGuard)
      if nowGuard == mainThread then
        logi("主任务正常结束")
        break
      end
      nowGuard = nil
    elseif result == kReset then
      nowGuard.thread = coroutine.create(nowGuard.action)
      nowGuard = nil
    elseif result ~= kYield then
      removeGuard(nowGuard)
      if nowGuard == mainThread then
        logi("主任务返回非yield值，结束")
        break
      end
      nowGuard = nil
    end

    ::continue::
    rawTickSleep()
  end

  -- 程序结束前的清理
  logi("程序运行结束")

  -- 可以在这里执行最终的清理工作
  if M.onProgramEnd then
    M.onProgramEnd()
  end
end

function M.maintainNode(finder, time)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local node = nil
  while nowTime - startTime < time do
    node = finder:find()
    if not node then
      return nil
    end
    tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return node
end

local function isWakeLockOnP2()
  local path = "/sys/power/wake_lock"
  local content = utils.readFile(path)
  return content ~= nil and string.find(content, "PowerManagerService.Display", 1, true) and true or false
end

local function isWakeLockOnP5()
  local result = shell.exec("cat /sys/class/backlight/*/brightness")
  return tonumber(result) > 0
end

local function currentSystemVersion()
  local result = shell.exec("getprop ro.build.version.release")
  return tonumber(result)
end

M.currentSystemVersion = currentSystemVersion

local function unlockP5()
  local unlockButton = By.res("com.android.systemui:id/lock_icon")
  local qqsPanel = By.res("com.android.systemui:id/quick_qs_panel")

  if not isWakeLockOnP5() then
    keyPress(KeyCode.POWER)
  end
  local node = M.waitForNode(unlockButton, 1000)
  if node then
    M.commonSleep()
    moveToUpLong()
  end

  -- 出现，手机下拉，网络蓝牙的时候，需要点击一下home返回桌面
  if M.waitForNode(qqsPanel, 1000) then
    keyPress(KeyCode.HOME)
  end
end

local function unlockP2()
  local unlockButton = By.res("com.android.systemui:id/lock_icon")
  if not isWakeLockOnP2() then
    keyPress(KeyCode.POWER)
  end
  local node = M.waitForNode(unlockButton, 1000)
  if node then
    M.clickNode(node)
  end
end

local function unlock()
  if currentSystemVersion() >= 13 then
    return unlockP5()
  end
  return unlockP2()
end



local function sureP5()
  if currentSystemVersion() >= 13 then
    return true
  end
  return false
end


-- 0x29B015 29B015
local function clickByColoer(color)
  local width, height = Display:getSize() --获取屏幕的宽高
  print(width, height)                    --打印屏幕的宽高，屏幕旋转后宽高会变化
  -- 根据按钮颜色找
  local x1, y1 = Display:findColor(width * 0.1, height * 0.4, width * 0.9, height * 0.9, color, 0.9, 0)
  print(x1, y1)
  tap(x1, y1)
end

local function toVersionString(versionCode)
  versionCode = versionCode + 100
  local major = math.floor(versionCode / 100)
  local minor = math.floor(versionCode % 100 / 10)
  local patch = versionCode % 10
  return string.format("%d.%d.%d", major, minor, patch)
end

-- worker 升级版本
function M.ensureEngineVersion(versionCode)
  if ENGINE_VERSION <= 57 then
    logw("当前脚本不支持自动升级脚本引擎，最低支持引擎版本为1.5.7")
    return false
  end
  if ENGINE_VERSION >= versionCode then
    logi("当前脚本引擎版本为" .. toVersionString(ENGINE_VERSION) .. "，已满足要求")
    return true
  end
  if ENGINE_VERSION < 92 then
    shell.exec("settings put global package_verifier_user_consent -1")
  end
  shell.startApp("com.maiku.runoffer.worker")
  local targetVersionString = toVersionString(versionCode)
  local targetUrl = string.format("http://download.jb.51wmsy.com/bernard/bernard-%s.apk", targetVersionString)
  SUI.toast("正在升级引擎版本到 " .. targetVersionString .. "，请稍后...")
  print(Guardian.upgradeEngine(targetUrl, "com.maiku.runoffer.worker", "com.maiku.runoffer.worker.MainActivity"))
  sleep(20 * 60 * 1000)
  error("引擎版本升级失败，请手动升级")
end

---@param finder UiNodeFilter
---@param min integer
---@param max integer
function M.moveToRangeAndRefresh(finder, min, max, timeout)
  local w, h = Display:getSize()
  local minTargetY = math.floor(h * min)
  local maxTargetY = math.floor(h * max)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 20000
  local x, y, x1, y1
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      print(1111)
      moveToUpS()
      ca.commonSleep()
      refreshWebView()
      goto continue
    end

    refreshWebView()
    x, y, x1, y1 = node:visibleBounds()
    if y < minTargetY then
      print(2222)
      moveToDownS()
      refreshWebView()
    elseif y > maxTargetY then
      print(3333)
      moveToUpS()
      refreshWebView()
    else
      print(4444)
      return true
    end
    ::continue::
    ca.commonSleep()
    nowTime = GetTimeOfDayMs()
  end
  return false
end

-- 短幅度的上下滑动
local function upAndDownMoveForShort()
  ca.commonSleep()
  ca.moveToUpShort()
  ca.randomSleep(1000, 2000)
  ca.moveToDownShort()
  ca.commonSleep()
end

-- 输入，不检查
---@param finder UiNodeFilter
---@param text string
function M.inputAndNotCheck(finder, text)
  ca.randomSleep(2000, 4000)
  for i = 1, 3, 1 do
    if not ensurehasFocus(finder) then
      print(111)
      return false
    end
  end

  if not ensureClearText(finder) then
    print(222)
    return false
  end
  if not ime.simInput(text) then
    print(333)
    return false
  end
  return true
end

-- 输入手机号，不需要匹配
---@param finder UiNodeFilter
---@param text string
function M.inputPhoneOnce(finder, text, notBlank)
  -- TODO
  ca.randomSleep(2000, 4000)
  if not ensurehasFocus(finder) then
    print(111)
    return false
  end
  if not ensureClearText(finder) then
    print(222)
    return false
  end
  if not ime.simInput(text) then
    print(333)
    return false
  end
  -- refreshWebView()
  return true
end

-- 获取北京时间
---@returns string 北京时间，格式为 yyyy-MM-dd HH:mm:ss
function M.getBJTime()
  -- 获取当前 UTC 时间戳
  local utc_timestamp = os.time()

  -- 假设要转成东八区 (北京时间, UTC+8)
  local bj_offset = 8 * 3600
  local bj_date = os.date("!*t", utc_timestamp + bj_offset)

  print(string.format("北京时间: %d年%d月%d日 %02d:%02d", bj_date.year, bj_date.month, bj_date.day, bj_date.hour, bj_date.min))

  -- 转化成统一格式 yyyy-MM-dd HH:mm:ss
  return os.date("%Y-%m-%d %H:%M:%S", utc_timestamp + bj_offset)
end

M.unlock = unlock
M.sureP5 = sureP5
M.clickByColoer = clickByColoer
M.hasDepth = hasDepth
M.refreshWebView = refreshWebView
M.upAndDownMoveForShort = upAndDownMoveForShort
return M
