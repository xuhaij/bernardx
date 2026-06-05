-- 传感器：每 500ms 检查黑板 hp，低于阈值时写入黑板通知

local M = {}

function M:Enter(args)
    self.threshold = args and args.threshold or 50
    self.count = 0
    print(string.format('[hp_sensor] 开始监控, 阈值=%d', self.threshold))
end

function M:Tick()
    self.count = self.count + 1
    local hp = blackboard.get('hp') or 100
    print(string.format('[hp_sensor] 第%d次检查: hp=%d, threshold=%d', self.count, hp, self.threshold))

    -- 把检查结果写入黑板
    blackboard.set('hp_low', hp <= self.threshold)

    if hp <= self.threshold then
        print('[hp_sensor] ⚠ 血量过低！')
    end

    return hp
end

function M:Exit()
    print('[hp_sensor] 停止监控')
end

return M
