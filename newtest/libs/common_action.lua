
local random = require "randomlua"
local utils = require "utils"
local class = require "class"
local shell = require "android.shell"
local tablex = require "tablex"
local ime = require "ime"
local system = require "system"


local iutils = require "iutils"
local sleepRandomer = random.gaussian(utils.randomSeed())
local actionRandomer = random.gaussian(utils.randomSeed())
local getTimeOfDayMs = GetTimeOfDayMs
local yield = coroutine.yield

local kYield <const> = {}
local kOver <const> = {}
local kReset <const> = {}
local kOverTask <const> = {}




local M = {}

local rawSleep = sleep
local coroutine = require "coroutine"
local isYieldable = coroutine.isyieldable

local function randomTime(min,max)
  return sleepRandomer:random(min,max)
end

local function actionTimeout()
  return randomTime(3000,4000)
end

M.actionTimeout = actionTimeout

local function netTimeout()
  return randomTime(95000,100000)
end

M.netTimeout = netTimeout


local function randomResponseTime()
  return randomTime(230,410)
end


M.randomTime = randomTime

local function rawRandomSleep(min,max)
  return rawSleep(randomTime(min,max))
end

local function sleepByYield(time)
  local startTime = getTimeOfDayMs()
  while getTimeOfDayMs() - startTime < time do
    yield(kYield)
  end
end

local function randomSleepByYield(min,max)
  return sleepByYield(randomTime(min,max))
end

function M.resetTask()
  yield(kReset)
end

function M.overFinalTask()
  yield(kOverTask)
end

local function randomSleep(min,max)
  if isYieldable() then
    return randomSleepByYield(min,max)
  else
    return rawRandomSleep(min,max)
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
  return rawRandomSleep(73,131)
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
  return randomSleep(600,730)
end

M.commonSleep = commonSleep

local function overTask()
  if isYieldable() then
    return yield(kOver)
  end
end

local _guardList = {}

local function addNewGuard(condition,action,prority,name)
  assert(name,"name is required")
  local guard = {
    condition = condition,
    action = action,
    prority = prority,
    running = false,
    thread = coroutine.create(action),
    name = name
  }
  table.insert(_guardList,guard)
  return guard
end

M.addNewGuard = addNewGuard

local function trueFuc()
  return true
end


M.overTask = overTask

local function removeGuard(guard)
  for i,v in ipairs(_guardList) do
    if v == guard then
      table.remove(_guardList,i)
      break
    end
  end
end

M.removeGuard = removeGuard

local mainThread = nil
local mainThreadName<const> = "main thread"

function M.replaceMainFunc(func)
  for _,guard in ipairs(_guardList) do
    if guard.name == mainThreadName then
      guard.action = func
      guard.thread = coroutine.create(func)
      break
    end
  end
end


---@type fun(msg:string):boolean|nil
local errorHandler = nil

function M.setErrorHandler(func)
  errorHandler = func
end

function M.run(func)
  mainThread = addNewGuard(trueFuc,func,0,mainThreadName)
  local nowGuard = mainThread
  while true do
    for _,guard in ipairs(_guardList) do
      if guard.condition() then
        if nowGuard ~= guard then
          if not nowGuard or guard.prority > nowGuard.prority then
            if nowGuard then
              logi(string.format("change task %s to %s",nowGuard.name,guard.name))
            end
            nowGuard = guard
          end
        end
      end
    end
    local status,result = coroutine.resume(nowGuard.thread)
    if not status then
      local handlered
      if errorHandler then
        handlered =   errorHandler(result)
      end
      if not handlered then
        error(result,DEBUG and 1 or 0)
      end
    end
    if result == kOver then
      removeGuard(nowGuard)
      nowGuard = nil
    elseif result == kReset then
      nowGuard.thread = coroutine.create(nowGuard.action)
      nowGuard = nil
    elseif result ~= kYield then
      removeGuard(nowGuard)
      if nowGuard == mainThread or result == kOverTask then
        break
      end
      nowGuard = nil
    end
    rawTickSleep()
  end
end


local function randomTap(x1,y1,x2,y2)
  local x = actionRandomer:random(x1,x2)
  local y = actionRandomer:random(y1,y2)
  return tap(x,y)
end

local function clickNode(node)
  local x,y,x1,y1 = node:visibleBounds()
  local shift<const> = 8
  if not x or not y then
    return false
  end
  x,y,x1,y1 = x + shift,y + shift,x1 - shift,y1 - shift
  if x1 <= x or y1 <= y then
    logw("click node %s out of bounds",node:text(),x,y,x1,y1)
    return false
  end
  return randomTap(x,y,x1,y1)
end

M.clickNode = clickNode

function M.waitFor(func,timeout,response_time)
  local now_time = getTimeOfDayMs()
  local start_time = now_time
  timeout = timeout or actionTimeout()
  response_time = response_time or randomResponseTime()
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
    now_time = getTimeOfDayMs()
  end
  return nil
end

function M.maintain(func,timeout,tolerance)
  local now_time = getTimeOfDayMs()
  local start_time = now_time
  timeout = timeout or actionTimeout()
  tolerance = tolerance or randomTime(100,200)
  local last_not_find_time = 0
  while now_time - start_time < timeout do
    local reuslt = func()
    if not reuslt then
      if last_not_find_time == 0 then
        last_not_find_time = now_time
      end
      if now_time - last_not_find_time > tolerance then
        return false
      end
    end
    tickSleep()
    now_time = getTimeOfDayMs()
  end
  return true
end



---@return UiNode|nil
function M.waitForNode(finder,timeout,response_time)
  timeout = timeout or actionTimeout()
  local now_time = getTimeOfDayMs()
  local start_time = now_time
  response_time = response_time or randomResponseTime()
  local last_find_time = 0
  while now_time - start_time < timeout do
    local node = finder:find()
    if node then
      if last_find_time == 0 then
        last_find_time = now_time
      end
      if now_time - last_find_time > response_time then
        return node
      end
    end
    tickSleep()
    now_time = getTimeOfDayMs()
  end
  return nil
end

---@return UiNode[]|nil
function M.waitForNodes(finder,timeout,response_time)
  timeout = timeout or actionTimeout()
  local now_time = getTimeOfDayMs()
  local start_time = now_time
  response_time = response_time or randomResponseTime()
  local last_find_time = 0
  while now_time - start_time < timeout do
    local nodes = finder:finds()
    if nodes then
      if last_find_time == 0 then
        last_find_time = now_time
      end
      if now_time - last_find_time > response_time then
        return nodes
      end
    end
    tickSleep()
    now_time = getTimeOfDayMs()
  end
  return nil
end

function M.openApp(packageName,activityName)
  local action_timeout = actionTimeout()
  local now_time = getTimeOfDayMs()
  local start_time = now_time
  local action = false
  while now_time - start_time < action_timeout do
    if System.getPackageName() == packageName and System.getActivity() == activityName then
      return true
    end
    if not action then
      action = shell.startActivity(packageName,activityName)
    end
    tickSleep()
    now_time = getTimeOfDayMs()
  end
  return false
end

function M.commonClickNode(node)
  clickNode(node)
  commonSleep()
  return true
end

function M.commonWaitAndClickNode(finder,timeout,response_time)
  local node = M.waitForNode(finder,timeout,response_time)
  if not node then
    return false
  end
  M.commonClickNode(node)
  return true
end

---@param node UiNode
local function randomClickEdit(node)
  local x1,y1,x2,y2 = node:visibleBounds()
  if not x1 then
    return false
  end
  local kShift<const> = 3
  local loc = (x2-x1)//10
  x1,x2 = x1 + loc*5,x1+loc*6
  return randomTap(x1+kShift,y1+kShift,x2-kShift,y2-kShift)
end

---@param type integer|nil 0-4  0-230-410,1-800-1100,2-1500-1900,3-2300-2900,4-3000-3700
local function randomReactionTime(type)
  type = type or 0
  if type == 0 then
    return sleepRandomer:random(230,410)
  elseif type == 1 then
    return sleepRandomer:random(800,1100)
  elseif type == 2 then
    return sleepRandomer:random(1500,1900)
  elseif type == 3 then
    return sleepRandomer:random(2300,2900)
  elseif type == 4 then
    return sleepRandomer:random(3000,3700)
  end
end

M.randomReactionTime = randomReactionTime

---@param finder UiNodeFilter
local function ensurehasFocusOnAndroid(finder)
  for i = 1,3 do
    local node = M.waitForNode(finder,actionTimeout())
    if not node then
      goto continue
    end
    if node:focused() then
      return true
    end
    randomClickEdit(node)
    commonSleep()
    if M.waitFor(function()
      local node = finder:find()
      return node and node:focused()
    end,actionTimeout(),randomReactionTime()) then
      return true
    end
    ::continue::
    commonSleep()
  end
  return false
end

local function ensureHasFocusOnIos(finder)
  for i = 1,3 do
    local node = M.waitForNode(finder,actionTimeout())
    if not node then
      goto continue
    end
    if ime.enable() then
      return true
    end
    randomClickEdit(node)
    commonSleep()
    if M.waitFor(ime.enable,actionTimeout(),randomReactionTime()) then
      return true
    end
    ::continue::
    commonSleep()
  end
  return false
end

local ensureHasFocus = IOS and ensureHasFocusOnIos or ensurehasFocusOnAndroid

local function ensureClearText(finder,localText,filter)
  local lastText
  local nowText
  for i = 1,50 do
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
      if tablex.getKey(localText,nowText) then
        return true
      end
    end

    if filter then
      nowText = string.gsub(nowText,filter,"")
    end
    if nowText == "" then
      return true
    end
    if nowText == lastText then
      randomClickEdit(node)
    end
    if not ensureHasFocus(finder) then
      return false
    end
    ime.delete()
    lastText = nowText
    ::continue::
    ca.randomSleep(220,300)
  end
  return false
end

local function isInputRight(finder,text,filter)
  local node = finder:find()
  if not node then
    return false
  end
  local nowText = node:text()
  if filter then
    nowText = string.gsub(nowText,filter,"")
  end
  return nowText == text
end


---@param finder UiNodeFilter
---@param text string 
local function inputTextOnce(finder,text,filter,localText)
  localText = localText or ""
  if isInputRight(finder,text,filter) then
    return true
  end
  if not ensureHasFocus(finder) then
    logd("get focuse fail")
    return false
  end
  if not ensureClearText(finder,localText,filter) then
    logd("clear text fail")
    return false
  end
  if not ime.simInput(text) then
    return false
  end
  return M.waitFor(function()
    local node = finder:find()
    if not node then
      return false
    end
    local nowText = node:text()
    if filter then
      nowText = string.gsub(nowText,filter,"")
    end
    -- print(nowText,text,nowText == text)
    return nowText == text
  end,randomTime(800,1100))
end

---@param finder UiNodeFilter
---@param text string
function M.ensureInputByFilter(finder,text,filter,localText)
  for i = 1,3 do
    if inputTextOnce(finder,text,filter,localText) then
      return true
    end
    local node = ca.waitForNode(finder,actionTimeout())
    if node then
      randomClickEdit(node)
    end
  end
  return false
end

---@param finder UiNodeFilter
---@param text string
---@param filter string|nil
function M.ensureSetText(finder,text,filter,pressBack)
  local lastText = nil
  for i = 1,3 do
    local node = finder:find()
    if node then
      local nowText = node:text()
      if filter then
        nowText = string.gsub(nowText,filter,"")
      end
      if nowText == text then
        return true
      end
      lastText = nowText
      node:setText(text)
      if pressBack then
        logd("ensureSetText", "press back")
        keyPress(KeyCode.BACK)
      end
    end
    ca.commonSleep()
  end
  logw("ensureSetText failed",lastText,text)
  return false
end


local function randomCoord(x1,y1,x2,y2)
  local x = actionRandomer:random(x1,x2)
  local y = actionRandomer:random(y1,y2)
  return x,y
end


local swipeFromPath = system.swipe

---@class MoveFeature
---@field leftOrDown integer[]
---@field rightOrUp integer[]
---@field timerange integer[]
---@field distance1 integer[]
---@field distance2 integer[]

---@param moveFeature MoveFeature
local function moveToRightOrUp(moveFeature)
  -- print("move to right or up")
  local ox,oy = randomCoord(table.unpack(moveFeature.leftOrDown))
  local tx,ty = randomCoord(table.unpack(moveFeature.rightOrUp))
  local time = math.random(table.unpack(moveFeature.timerange))
  local distance1 = math.random(table.unpack(moveFeature.distance1))
  local distance2 = math.random(table.unpack(moveFeature.distance2))
  local path = iutils.generatePath(ox,oy,tx,ty,-distance1,-distance2,time//23)
  swipeFromPath(path)
end

M.moveToRightOrUp = moveToRightOrUp

---@param moveFeature MoveFeature
local function moveToLeftOrDown(moveFeature)
  -- print("move to left or down")
  local ox,oy = randomCoord(table.unpack(moveFeature.rightOrUp))
  local tx,ty = randomCoord(table.unpack(moveFeature.leftOrDown))
  local time = math.random(table.unpack(moveFeature.timerange))
  local distance1 = math.random(table.unpack(moveFeature.distance1))
  local distance2 = math.random(table.unpack(moveFeature.distance2))
  local path = iutils.generatePath(ox,oy,tx,ty,distance1,distance2,time//23)
  swipeFromPath(path)
end

M.moveToLeftOrDown = moveToLeftOrDown


---@param finder UiNodeFilter
---@param min number
---@param max number
---@param timeout number|nil
---@param moveFeature MoveFeature
local function moveToRangeX(finder,min,max,moveFeature,timeout)
  local w,h = Display:getSize()
  local minTargetX = math.floor(w*min)
  local maxTargetX = math.floor(w*max)
  local nowTime = getTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 20000
  if maxTargetX > w then
    maxTargetX = w
  end
  local x1,y1,x2,y2 
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      moveToRightOrUp(moveFeature)
      goto continue
    end
    x1,y1,x2,y2 = node:visibleBounds()
    if x1 >=x2 then
      if x1 < w //2 then
        moveToRightOrUp(moveFeature)
      else
        moveToLeftOrDown(moveFeature)
      end
    elseif x1 < minTargetX then
      moveToRightOrUp(moveFeature)
    elseif x1 > maxTargetX then
      moveToLeftOrDown(moveFeature)
    else
      return node
    end
    randomSleep(1000,1300)
    ::continue::
    tickSleep()
    nowTime = getTimeOfDayMs()
  end
  return nil
end

M.moveToRangeX = moveToRangeX

---@return MoveFeature
local function commonMoveFeature()
  -- 0.590278,0.159429,0.644444,0.179901
  -- 0.430556,0.593052,0.494444,0.621588

  local screen_w,screen_h = Display:getSize()
  local up = {utils.toRange(screen_w,screen_h,0.759259,0.602137,0.813889,0.626068)}
  local down = {utils.toRange(screen_w,screen_h,0.681481,0.826496,0.725926,0.849145)}
  return {
    leftOrDown = down,
    rightOrUp = up,
    timerange = {700,933},
    distance1 = {100,200},
    distance2 = {100,200}
  }
end



---@param finder UiNodeFilter
---@param min number
---@param max number
---@param timeout number|nil
---@param moveFeature MoveFeature
local function moveToRangeY(finder,min,max,moveFeature,timeout)
  local w,h = Display:getSize()
  local minTargetY = math.floor(h*min)
  local maxTargetY = math.floor(h*max)
  local nowTime = getTimeOfDayMs()
  local startTime = nowTime
  timeout = timeout or 20000
  if maxTargetY > h then
    maxTargetY = h
  end
  local x1,y1,x2,y2 
  while nowTime - startTime < timeout do
    local node = finder:find()
    if not node then
      moveToRightOrUp(moveFeature)
      goto continue
    end
    x1,y1,x2,y2 = node:visibleBounds()
    if not x1 or not y1 then
      goto continue
    end
    if y1 >=y2 then
      if y1 < h //2 then
        moveToLeftOrDown(moveFeature)
      else
        moveToRightOrUp(moveFeature)
      end
    elseif y1 < minTargetY then
      moveToLeftOrDown(moveFeature)
    elseif y1 > maxTargetY then
      moveToRightOrUp(moveFeature)
    else
      return node
    end
    ::continue::
    randomSleep(1500,2300)
    nowTime = getTimeOfDayMs()
  end
  return nil
end

M.moveToRangeY = moveToRangeY

function M.moveToRange(finder,min,max,timeout)
  return moveToRangeY(finder,min,max,commonMoveFeature(),timeout)
end




local FinderWrapper = class.new("FinderWrapper")

function FinderWrapper:ctor(func)
  self.func = func
end


function FinderWrapper:find()
  return self.func()
end

local SelectFinder = class.new("SelectFinder")

function SelectFinder:ctor(finder,index)
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


function M.selectFinder(finder,index)
  return class.instance(SelectFinder,finder,index)
end

---@class WhichFinder:UiNodeFilter
local WhichFinder = class.new("WhichFinder")

function WhichFinder:ctor(...)
  self.finders = {...}
  ---@type UiNodeFilter|nil
  self._lastFinder = nil
  self._lastIndex = 0
end

function WhichFinder:find()
  for i,v in ipairs(self.finders) do
    local node = v:find()
    if node then
      self._lastFinder = v
      self._lastIndex = i
      return node
    end
  end
  return nil
end

function WhichFinder:lastFinder()
  return self._lastFinder
end

function WhichFinder:lastIndex()
  return self._lastIndex
end

function WhichFinder:index(index)
  return self.finders[index]
end



---@return UiNodeFilter
function M.finderWrapper(func)
  return class.instance(FinderWrapper,func)
end

---@param ... UiNodeFilter
---@return WhichFinder
function M.whichFinder(...)
  return class.instance(WhichFinder,...)
end

function M.waitForVanishWithNode(finder,timeout,minVanishTime)
  local nowTime = getTimeOfDayMs()
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
    tickSleep()
    nowTime = getTimeOfDayMs()
  end
  return false
end

---@type table<integer, integer[]>
local ACTION_INTERVAL_RANGES <const> = {
  {3000, 5000},
  {5000, 7000},
  {7000, 9000}
}

---@param actionIntervalType integer 0-2
---@return integer
local function generateActionInterval(actionIntervalType)
  actionIntervalType = actionIntervalType + 1
  local range = ACTION_INTERVAL_RANGES[actionIntervalType]
  if not range then
    error("unknown interval type " .. tostring(actionIntervalType))
  end
  return randomTime(range[1], range[2])
end

function M.commonActionTimeout()
  return randomTime(17000, 23000)
end

---@class EnsureClickConfig
---@field timeout number
---@field actionIntervalType number 0-3000-5000,1-5000-7000,2-7000-9000
---@field reactionTime number?
---@field checkCondition (fun(node:UiNode|nil):boolean,boolean|nil) 检查条件，返回 (是否完成, 是否跳过点击)
---@field getClickable (fun(node:UiNode):UiNode|nil)? 从找到的节点获取可点击节点

---@param finder UiNodeFilter
---@param config EnsureClickConfig
---@return integer 0-success,1-timeout,2-special
local function ensureClickCore(finder, config)
  local nowTime = getTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  local lastFindTime = 0
  local timeout = config.timeout or actionTimeout()
  local actionIntervalType = config.actionIntervalType or 0
  local reactionTime = config.reactionTime or randomReactionTime()
  local actionInterval = generateActionInterval(actionIntervalType)

  while nowTime - startTime < timeout do
    local node = finder:find()
    if node then
      local done, specialReturn = config.checkCondition(node)
      if done then
        return 0
      end
      if specialReturn ~= nil then
        return specialReturn
      end
      if lastFindTime == 0 then
        lastFindTime = nowTime
      end
      if nowTime - lastFindTime > reactionTime and nowTime - lastActionTime > actionInterval then
        local clickNode_ = config.getClickable and config.getClickable(node) or node
        if clickNode_ then
          clickNode(clickNode_)
          lastActionTime = nowTime
          actionInterval = generateActionInterval(actionIntervalType)
        end
        lastFindTime = 0
      end
    end
    tickSleep()
    nowTime = getTimeOfDayMs()
  end
  return 1
end

---@param clickable UiNodeFilter
---@param target UiNodeFilter
---@param timeout number
---@param actionIntervalType number 0-3000-5000,1-5000-7000,2-7000-9000
---@return integer 0-success,1-timeout,2-background
function M.ensureClickToByNode(clickable, target, timeout, actionIntervalType, reactionTime, notClickableError)
  local nowTime = getTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  actionIntervalType = actionIntervalType or 0
  reactionTime = reactionTime or randomReactionTime()
  local lastFindTime = 0
  local actionInterval = generateActionInterval(actionIntervalType)
  while nowTime - startTime < timeout do
    local node = target:find()
    if node then
      return 0
    end
    node = clickable:find()
    if node then
      local x1, y1, x2, y2 = node:visibleBounds()
      if not x1 then
        goto continue
      end
      if x2 <= x1 or y2 <= y1 then
        if notClickableError then
          return 2
        end
      end
      if lastFindTime == 0 then
        lastFindTime = nowTime
      elseif nowTime - lastFindTime > reactionTime and nowTime - lastActionTime > actionInterval then
        clickNode(node)
        lastFindTime = 0
        lastActionTime = nowTime
        actionInterval = generateActionInterval(actionIntervalType)
      end
    end
    ::continue::
    tickSleep()
    nowTime = getTimeOfDayMs()
  end
  return 1
end

---@param finder UiNodeFilter
---@param timeout number
---@param reactionTime number
---@param actionIntervalType number 0-3000-5000,1-5000-7000,2-7000-9000
---@return integer 0-success,1-timeout
function M.ensureSelected(finder, timeout, reactionTime, actionIntervalType)
  return ensureClickCore(finder, {
    timeout = timeout,
    actionIntervalType = actionIntervalType,
    reactionTime = reactionTime or randomReactionTime(),
    checkCondition = function(node)
      if node and node:selected() then
        return true, nil
      end
      return false
    end
  })
end

---@param finder UiNodeFilter
---@param timeout number
---@param reactionTime number?
---@param actionIntervalType number? 0-3000-5000,1-5000-7000,2-7000-9000
---@param target boolean? 期望的 checked 状态
---@return integer 0-success,1-timeout
function M.ensureChecked(finder, timeout, reactionTime, actionIntervalType, target)
  return ensureClickCore(finder, {
    timeout = timeout,
    actionIntervalType = actionIntervalType or 2,
    reactionTime = reactionTime,
    checkCondition = function(node)
      if node and node:checked() == target then
        return true, nil
      end
      return false
    end
  })
end

---@param finder UiNodeFilter
---@param timeout number
---@param reactionTime number
---@param actionIntervalType number 0-3000-5000,1-5000-7000,2-7000-9000
---@return integer 0-success,1-timeout
function M.ensureNotChecked(finder, timeout, reactionTime, actionIntervalType)
  return ensureClickCore(finder, {
    timeout = timeout,
    actionIntervalType = actionIntervalType,
    reactionTime = reactionTime,
    checkCondition = function(node)
      if node and not node:checked() then
        return true, nil
      end
      return false
    end
  })
end



M.commonMoveFeature = commonMoveFeature

function M.moveToUpX()
  moveToRightOrUp(commonMoveFeature())
  return true
end

-- 一定时间内持续查找并返回一个节点，也就是要找到节点会存留一段时间在屏幕上
function M.maintainNode(finder,time,maxInterval)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local node = nil
  maxInterval = maxInterval or 123
  local lastNotFindTime = 0
  while nowTime - startTime < time do
    node = finder:find()
    if not node then
      if lastNotFindTime == 0 then
        lastNotFindTime = nowTime
      elseif nowTime - lastNotFindTime > maxInterval then
        return nil
      end
    else
      lastNotFindTime = 0
    end
    tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return node
end

M.randomTap = randomTap
M.ensureClearText = ensureClearText


---@param clickable UiNodeFilter
---@param target UiNodeFilter|nil
---@param timeout number
---@param actionIntervalType number 0-3000-5000,1-5000-7000,2-7000-9000
---@param reactionTime number?
---@return integer 0-success,1-timeout
function M.ensureClickToVanish(clickable, target, timeout, actionIntervalType, reactionTime)
  target = target or clickable
  local nowTime = getTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  local lastFindTime = 0
  actionIntervalType = actionIntervalType or 0
  reactionTime = reactionTime or randomReactionTime()
  local actionInterval = generateActionInterval(actionIntervalType)
  while nowTime - startTime < timeout do
    local node = target:find()
    if not node then
      return 0
    end
    node = clickable:find()
    if node then
      local x1, y1, x2, y2 = node:visibleBounds()
      if not x1 then
        goto continue
      end
      if x2 <= x1 or y2 <= y1 then
        goto continue
      end
      if lastFindTime == 0 then
        lastFindTime = nowTime
      elseif nowTime - lastFindTime > reactionTime and nowTime - lastActionTime > actionInterval then
        clickNode(node)
        lastActionTime = nowTime
        actionInterval = generateActionInterval(actionIntervalType)
        lastFindTime = 0
      end
    end
    ::continue::
    tickSleep()
    nowTime = getTimeOfDayMs()
  end
  return 1
end

function M.ensureClickToVisible(clickable, target, timeout, actionIntervalType, reactionTime)
  target = target or clickable
  local nowTime = getTimeOfDayMs()
  local startTime = nowTime
  local lastActionTime = 0
  local lastFindTime = 0
  actionIntervalType = actionIntervalType or 0
  reactionTime = reactionTime or randomReactionTime()
  local actionInterval = generateActionInterval(actionIntervalType)
  while nowTime - startTime < timeout do
    local node = target:find()
    if node and node:visible() then
      return 0
    end
    node = clickable:find()
    if node then
      local x1, y1, x2, y2 = node:visibleBounds()
      if not x1 then
        goto continue
      end
      if x2 <= x1 or y2 <= y1 then
        goto continue
      end
      if lastFindTime == 0 then
        lastFindTime = nowTime
      elseif nowTime - lastFindTime > reactionTime and nowTime - lastActionTime > actionInterval then
        clickNode(node)
        lastActionTime = nowTime
        actionInterval = generateActionInterval(actionIntervalType)
        lastFindTime = 0
      end
    end
    ::continue::
    tickSleep()
    nowTime = getTimeOfDayMs()
  end
  return 1
end

local function isWakeLockOnP5()
  local result = shell.exec("cat /sys/class/backlight/*/brightness")
  return tonumber(result)> 0
end

local function isP5()
  local result = shell.exec("cat /sys/class/backlight/*/brightness")
  return result ~= nil
end

function M.unlockP5()
  local unlockButton = By.res("com.android.systemui:id/lock_icon")
  -- print("unlockP5",isWakeLock(),unlockButton:find())
  if not isWakeLockOnP5() or unlockButton:find() then
    if not isWakeLockOnP5() then
      keyPress(KeyCode.POWER)
    end
    M.commonSleep()
    moveToRightOrUp(commonMoveFeature())
  end
end

local function isWakeLock()
  local path = "/sys/power/wake_lock"
  local content = utils.readFile(path)
  return content ~= nil and string.find(content,"PowerManagerService.Display",1,true) and true or false
end

function M.unlockP2()
  local unlockButton = By.res("com.android.systemui:id/lock_icon")
  if not isWakeLock() then
    keyPress(KeyCode.POWER)
  end
  local node = M.waitForNode(unlockButton,1000)
  if node then
    M.clickNode(node)
  end
end

function M.unlockScreen()
  if isP5() then
    M.unlockP5()
  else
    M.unlockP2()
  end
end

M.reactionTime = randomReactionTime
M.moveToUp = M.moveToUpX

function M.maintainNodeVisible(finder,time,maxInterval)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local node = nil
  maxInterval = maxInterval or 123
  local lastNotVisibleTime = 0
  while nowTime - startTime < time do
    node = finder:find()
    if not node or not node:visible() then
      if lastNotVisibleTime == 0 then
        lastNotVisibleTime = nowTime
      elseif nowTime - lastNotVisibleTime > maxInterval then
        return nil
      end
    else
      lastNotVisibleTime = 0
    end
    tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return node
end


function M.ensureMaintainNodeVisible(finder,time,maxInterval,timeout)
  local nowTime = GetTimeOfDayMs()
  local startTime = nowTime
  local node = nil
  maxInterval = maxInterval or 123
  local lastNotVisibleTime = 0
  while nowTime - startTime < timeout do
    node = M.maintainNodeVisible(finder,time,maxInterval)
    if node then
      return node
    end
    tickSleep()
    nowTime = GetTimeOfDayMs()
  end
  return nil
end


return M