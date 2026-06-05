-- 治疗技能

local M = {}

function M.name()
    return 'heal'
end

function M.execute(target, amount)
    local hp = blackboard.get('hp') or 0
    local new_hp = hp + (amount or 50)
    blackboard.set('hp', new_hp)
    print(string.format('[skill:heal] %s 回复 %d → hp=%d', target or 'unknown', amount or 50, new_hp))
    return new_hp
end

return M
