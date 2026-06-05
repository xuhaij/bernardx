local ca = require("common_action")
print("===== 最简测试 =====")
-- 连接 Nd
print("[1] Nd.connect...")
local ok = false
for i = 1, 5 do
    if Nd.connect(3) then ok = true; break end
    ca.randomSleep(3000, 5000)
end
if not ok then print("失败"); return end

-- 解锁 + 回桌面
ca.unlockP2()
System.pressKey(3)
ca.randomSleep(500, 1000)

-- 列桌面元素
print("[2] 桌面文字:")
local nodes = By.clz("android.widget.TextView"):finds()
if nodes then
    for i = 1, math.min(#nodes, 15) do
        local t = nodes[i]:text()
        if t and #t > 0 then print("  " .. t) end
    end
end

print("===== 完成 =====")
