
local M = {}
local floor = math.floor

local _lastSeed = 0
function M.randomSeed()
  local s,us = GetTimeOfDay()
  local n = math.abs(us-s)
  if n == _lastSeed then
      n = n + us
  end
  _lastSeed = n
  return n
end

local function toSim(source,now,max_range)
  max_range = max_range or source
  local s = math.abs(source - now)
  if s > max_range then
      return 0
  end
  return 1 - s / max_range
end

M.toSim = toSim


local string_find = string.find
local string_sub = string.sub
function M.split(s,p)
    local last = 1
    local o = last
    local e
    local r = {}
    while o <=#s do
        o,e  = string_find(s,p,o,true)
        if o then
            r[#r+1] = string_sub(s,last,o-1)
            last = e+1
            o = last
        else
            r[#r+1] = string_sub(s,last,#s)
            break
        end
    end
    return r
end

function M.readFile(path)
  local f = io.open(path,"r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

function M.writeFile(path,content)
  local f = io.open(path,"w")
  if not f then
    logw("writeFile failed,path:" .. path)
    return false
  end
  f:write(content)
  f:close()
  return true
end

function M.randomSelect(...)
  local args = {...}
  return args[math.random(1,#args)]
end

function M.randomMove(t,min,max)
  local nr = math.random(min,max)
  local r = {}
  for i=1,nr do
    local index = math.random(1,#t)
    table.insert(r,table.remove(t,index))
  end
  return r
end 

function M.notBlank(text)
  local result = {}
  for c in text:gmatch("%g+") do
    table.insert(result,c)
  end
  return table.concat(result)
end

function M.toDayZore(timestamp)
  local t = os.date("*t",timestamp)
  return os.time({year=t.year,month=t.month,day=t.day,hour=0,min=0,sec=0})
end

local function decodeTime(timeStr)
  local year,month,day,hour,minute,second = string.match(timeStr,"(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  return os.time({year=year,month=month,day=day,hour=hour,min=minute,sec=second})
end

function M.computeTimeDiff(timeStr)
  local targetNowTime = decodeTime(timeStr)
  if not targetNowTime then
    return nil
  end
  local nowTime = os.time()
  local diff = os.difftime(targetNowTime,nowTime)
  return math.abs(diff) // 3600 * 3600 * (diff > 0 and 1 or -1)
end

M.decodeTime = decodeTime


function M.toRange(screenW,screenH,x1,y1,x2,y2)
  return floor(screenW * x1),floor(screenH * y1),floor(screenW * x2),floor(screenH * y2)
end

function M.toRangeWithOffset(w,h,x1,y1,x2,y2,ox,oy)
  return floor(w * x1 + (ox or 0)),floor(h * y1 + (oy or 0)),floor(w * x2 + (ox or 0)),floor(h * y2 + (oy or 0))
end

function M.toRangeWithRange(x1,y1,x2,y2,rangeX1,rangeY1,rangeX2,rangeY2)
  return floor(rangeX1 + (rangeX2 - rangeX1) * x1),floor(rangeY1 + (rangeY2 - rangeY1) * y1),floor(rangeX1 + (rangeX2 - rangeX1) * x2),floor(rangeY1 + (rangeY2 - rangeY1) * y2)
end

function M.toRangeRatio(w,h,x1,y1,x2,y2,ox,oy)
  x1 = x1 - (ox or 0)
  y1 = y1 - (oy or 0)
  x2 = x2 - (ox or 0)
  y2 = y2 - (oy or 0)
  return x1/w,y1/h,x2/w,y2/h
end

return M