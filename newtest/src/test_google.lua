-- test_google.lua — 测试手机打开 Google
-- 在 VS Code 中打开此文件，按 F5，选择 "Bernard Lua Debugger"

local init = require("libs.init")
ca = require("common_action")

-- 全部初始化
local bot = init.setup()

-- 检查 Chrome 就绪
if not bot.chrome then
    print("[test] Chrome 未就绪，尝试重新连接...")
    init.setup({ nd = false, chrome = true, worker = false })
    bot = init
    if not bot.chrome_ok then
        error("Chrome 初始化失败")
    end
end

-- 打开 Google
print("[test] 正在导航到 Google...")
bot.chrome.navigateTo("https://www.google.com")

-- 等待加载
ca.randomSleep(3000, 4000)

-- 验证
local info = bot.chrome.currentTabInfo()
print("[test] 当前页面: " .. info.title .. " | " .. info.url)

-- 截图（如果扩展支持）
-- 右键 → Bernard Screenshot，或:
-- local ok = bot.chrome.captureSnapshot()
-- print("[test] 截图完成: " .. tostring(ok ~= nil))

print("[test] 完成！手机上应该已经打开了 Google")
