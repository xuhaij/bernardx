-- 初始化黑板数据（Enter 时设置，Tick 时返回 success）

local M = {}

function M:Enter(args)
    print('[init] 初始化黑板: hp=100')
    blackboard.set('hp', 100)
end

function M:Tick()
    print('[init] Tick called')
    return 'success'
end

return M
