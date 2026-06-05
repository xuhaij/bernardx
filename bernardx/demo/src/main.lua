-- demo/src/main.lua — 入口脚本：加载所有 skill → 运行行为树

local bt = require('bt')
local lfs = require('lfs')

-- 设置行为树项目路径
bt.set_project_path('bt_project')

-- 扫描并加载所有 skill 模块（skills/ 放在 libs/ 下，require 可以找到）
local skills = {}
local skills_count = 0
print('[main] 加载 skills...')

for name in lfs.dir('libs/skills') do
    if name:match('%.lua$') then
        local module_name = name:gsub('%.lua$', '')
        local full_name = 'skills.' .. module_name
        local ok, mod = pcall(require, full_name)
        if ok and type(mod) == 'table' and mod.name then
            skills[mod:name()] = mod
            skills_count = skills_count + 1
            print(string.format('[main]   ✓ %s', mod:name()))
        else
            print(string.format('[main]   ✗ %s', full_name))
        end
    end
end

print(string.format('[main] 共加载 %d 个 skill', skills_count))

-- 演示：先手动调用几个 skill 操作黑板
if skills.attack then
    skills.attack.execute('target', 30)
end

-- 启动行为树
print('[main] 启动行为树...')
local ok, status = bt.run('trees/my_tree')
print(string.format('[main] 行为树结束: ok=%s, status=%s', tostring(ok), tostring(status)))
