-- 攻击技能

local M = {}

function M.name()
    return 'attack'
end

function M.execute(target, damage)
    local hp = blackboard.get('hp') or 0
    local new_hp = math.max(0, hp - (damage or 20))
    blackboard.set('hp', new_hp)
    print(string.format('[skill:attack] %s 受到 %d 伤害 → hp=%d', target or 'unknown', damage or 20, new_hp))
    return new_hp
end

return M
