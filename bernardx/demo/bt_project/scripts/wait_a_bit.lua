-- 修改黑板数据，模拟血量下降

local M = {}

function M:Enter(args)
    print('[modify] 开始修改黑板数据')
    self.count = 0
end

function M:Tick()
    self.count = self.count + 1
    local hp = (blackboard.get('hp') or 100) - 30
    blackboard.set('hp', hp)
    print(string.format('[modify] 第%d次: hp=%d', self.count, hp))

    if self.count >= 3 then
        return 'success'
    end
    -- 暂停 500ms 后再来一次 Tick
    sleep(500)
    return 'running'
end

function M:Exit(status)
    print('[modify] Exit: ' .. status)
end

return M
