--- AI Agent 操控手机：打开 Google 并登录
-- 配置在 newtest/.env 里

require("env").load(".env")

local init = require("libs.init")
local ai = require("ai")
local harness = require("agent")
local nd = require("agent.nd_tools")

-- ===== 初始化 =====
init.setup({ worker = false })

-- ===== AI 客户端 =====
local api_key = os.getenv("ANTHROPIC_AUTH_TOKEN")
if not api_key then error("请设置 ANTHROPIC_AUTH_TOKEN") end

local ai_client = ai.anthropic({
    api_key = api_key,
    base_url = os.getenv("ANTHROPIC_BASE_URL") or "https://api.anthropic.com",
    model = os.getenv("ANTHROPIC_DEFAULT_SONNET_MODEL") or "claude-sonnet-4-20250514",
    max_tokens = 1024,
})

-- ===== 工具: CDP + Nd =====
local cdp_tools = harness.cdp_tools(ai)
local nd_tools = nd.nd_tools(ai)
local all_tools = {}
for _, t in ipairs(cdp_tools) do table.insert(all_tools, t) end
for _, t in ipairs(nd_tools)  do table.insert(all_tools, t) end

-- ===== Dispatch =====
local nd_dispatch = nd.nd_dispatch()
local all_dispatch = {}
for k, v in pairs(nd_dispatch) do all_dispatch[k] = v end

all_dispatch.observe = function()
    local info = init.chrome and init.chrome.currentTabInfo()
    local html = init.chrome and init.chrome.getOuterHTML()
    local result = "Page: " .. (info and (info.title .. " " .. info.url) or "?") .. "\n"
    if html then result = result .. "HTML: " .. string.sub(html, 1, 3000) end
    return result
end

all_dispatch.click = function(input)
    if not init.cdp then return "error: CDP down" end
    local node = init.cdp.find(input.selector)
    if node then ca.commonClickNode(node); return "clicked " .. input.selector end
    return "error: not found " .. input.selector
end

all_dispatch.type = function(input)
    if not init.cdp then return "error: CDP down" end
    local node = init.cdp.find(input.selector)
    if node then ca.commonClickNode(node); Nd.setText(input.text); return "typed" end
    return "error: not found " .. input.selector
end

all_dispatch.navigate = function(input)
    if not init.chrome then return "error: Chrome down" end
    init.chrome.navigateTo(input.url)
    return "navigated to " .. input.url
end

-- ===== 任务 =====
local email = os.getenv("GOOGLE_EMAIL") or "your-email@gmail.com"
local password = os.getenv("GOOGLE_PASSWORD") or "your-password"

local task = string.format([[
你是手机自动化助手。完成以下任务:
1. open_app 打开 Chrome (com.android.chrome)
2. navigate 导航到 https://accounts.google.com/signin
3. observe 查看页面，找到邮箱输入框
4. type 或 type_by_hint 输入邮箱: %s
5. tap_by_text("下一步") 或 click 点击 Next
6. 等待密码框出现，输入密码: %s
7. 点击下一步/登录
8. done

可用工具: open_app, press_key, tap_by_text, type_by_hint, swipe_screen, observe, click, type, navigate, wait, done
]], email, password)

-- ===== 运行 =====
local messages = {{ role = "user", content = task }}
local system = "你是 Android 手机自动化助手。每步都 observe 验证后再继续。"

print("===== AI Agent: 登录 Google =====")
local _, done = harness.run(ai_client, messages, system, all_tools, all_dispatch, 30)
print(done and "✓ 完成" or "✗ 未完成")
