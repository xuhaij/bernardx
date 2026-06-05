-- 读取黑板最终数据并打印

local M = {}

function M:Enter(args)
    print('[goodbye] 读取最终状态...')
end

function M:Tick()
    local hp = blackboard.get('hp')
    print(string.format('[goodbye] 最终血量: %s', tostring(hp)))
    return 'success'
end

return M
