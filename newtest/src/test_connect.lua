-- 最简连接测试（不 require 任何本地模块，全用全局 API）

print("===== 连接测试 =====")

-- 连接无障碍服务
local ok = false
for i = 1, 5 do
    if Nd.connect(3) then
        print("Nd.connect 成功 (attempt " .. i .. ")")
        ok = true
        break
    end
    print("重试 " .. i .. "/5...")
    Nd.sleep(3000)
end

if not ok then
    print("Nd 连接失败")
    return
end

-- 解锁
ca = require("common_action")
ca.unlockP2()
print("屏幕已解锁")

-- 设备信息
print("引擎版本: " .. tostring(ENGINE_VERSION))
print("设备名称: " .. tostring(DEVICE_NAME))
print("当前包名: " .. tostring(System.getPackageName()))

local w, h = Display:getSize()
print(string.format("屏幕: %dx%d", w, h))

-- 列一下桌面上的 App 图标
print("\n桌面可见元素（前10个）:")
local nodes = By.clz("android.widget.TextView"):finds()
local count = 0
if nodes then
    for _, n in ipairs(nodes) do
        local t = n:text()
        if t and #t > 0 and count < 10 then
            print("  - " .. t)
            count = count + 1
        end
    end
end

print("\n===== 连接成功! =====")
