--[[
    缓存函数调用结果，避免重复计算
]]
local M = {}

local _cache = {}
local _cacheIndex = 0
local select = select
local function cacheResult(t,...)
    t[1] = true
    local n = select("#",...)
    t[2] = n
    for i = 1,n do
        t[i+2] = select(i,...)
    end
    return ...
end

local unpack = table.unpack

local function pushToCache(t)
    _cacheIndex = _cacheIndex + 1
    _cache[_cacheIndex] = t
end

---@return fun(...):unknown
function M.new(method)
    local t = {
        false, -- 是否已经计算
        0,-- 结果数量
    }
    return function (...)
        if t[1] then
            return unpack(t,3,t[2]+2)
        else
            pushToCache(t)
            return cacheResult(t,method(...))
        end
    end
end

function M.clean()
    for i = 1, _cacheIndex do
        local t = _cache[i]
        t[1] = false
    end
    _cacheIndex = 0
end

return M