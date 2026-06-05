--- .env 文件加载器
-- 用法: local env = require("env"); env.load()
-- 之后 os.getenv("KEY") 或 env.get("KEY") 都能取到值

local M = {}

M._values = {}

--- 从文件加载 .env 到 os 环境变量
---@param path? string .env 文件路径，默认当前目录 .env
function M.load(path)
    path = path or ".env"
    local f = io.open(path, "r")
    if not f then return false, "cannot open " .. path end
    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")  -- trim
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local key, value = line:match("^([%w_]+)%s*=%s*(.+)$")
            if key and value then
                -- 去引号
                value = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
                pcall(function() os.setenv(key, value) end)
                M._values[key] = value
            end
        end
    end
    f:close()
    return true
end

--- 获取值（优先 os.getenv，回退 .env 加载的值）
function M.get(key)
    return os.getenv(key) or M._values[key]
end

return M
