--- AI Agent 操控手机：打开 Google 并登录
-- 使用完整的 agent 系统：skills、sub-agents、memory、prompt
-- 配置在 newtest/.env 里

require("env").load(".env")

local init   = require("libs.init")
local ai     = require("ai")
local harness = require("agent")
local nd     = require("agent.nd_tools")
local skills = require("agent.skills")
local prompt = require("agent.prompt")
local memory = require("agent.memory")
local agents = require("agent.agents")

-- ===== 1. 初始化手机 =====
local bot = init.setup({ worker = false })

-- ===== 2. AI 客户端 =====
local api_key = os.getenv("ANTHROPIC_AUTH_TOKEN")
if not api_key then error("请设置 ANTHROPIC_AUTH_TOKEN") end

local ai_client = ai.anthropic({
    api_key    = api_key,
    base_url   = os.getenv("ANTHROPIC_BASE_URL") or "https://api.anthropic.com",
    model      = os.getenv("ANTHROPIC_DEFAULT_SONNET_MODEL") or "claude-sonnet-4-20250514",
    max_tokens = 1024,
})

-- ===== 3. Skills、Memory、Sub-agents =====
local skills_dir = ".\\skills"
local skill_registry = skills.scan(skills_dir)
local skill_catalog  = skills.catalog(skill_registry)
print("Skills: " .. skill_catalog)

local agents_dir = ".\\agents"
local agent_registry = agents.scan(agents_dir)
local agent_names    = agents.names(agent_registry)
print("Sub-agents: " .. table.concat(agent_names, ", "))

local memory_dir = ".\\memory"
local memory_registry = memory.scan(memory_dir)
local memory_index    = memory.index_text(memory_dir, memory_registry)
if memory_index ~= "" then print("Memory: " .. memory_index) end

-- ===== 4. 工具: CDP + Nd + Skills =====
local cdp_t  = harness.cdp_tools(ai)
local nd_t   = nd.nd_tools(ai)
local sk_t   = harness.skill_tools(ai)

local all_tools = {}
for _, t in ipairs(cdp_t) do table.insert(all_tools, t) end
for _, t in ipairs(nd_t)  do table.insert(all_tools, t) end
for _, t in ipairs(sk_t)  do table.insert(all_tools, t) end

-- ===== 5. Dispatch: CDP + Nd + Skills =====
local nd_d  = nd.nd_dispatch()
local sk_d  = harness.skill_dispatch(skill_registry, skills_dir, {
    ai_client   = ai_client,
    ai          = ai,
    client      = bot.chrome,
    memory_dir  = memory_dir,
    output_dir  = ".\\output",
    agent_path  = ".",
}, agent_registry)

local all_dispatch = {}
for k, v in pairs(nd_d) do all_dispatch[k] = v end
for k, v in pairs(sk_d) do all_dispatch[k] = v end

-- CDP 相关
all_dispatch.observe = function()
    local info = bot.chrome and bot.chrome.currentTabInfo()
    local html = bot.chrome and bot.chrome.getOuterHTML()
    return "Page: " .. (info and (info.title .. " " .. info.url) or "?") .. "\n" ..
           (html and ("HTML: " .. string.sub(html, 1, 3000)) or "")
end
all_dispatch.click = function(input)
    if not bot.cdp then return "error: CDP down" end
    local node = bot.cdp.find(input.selector)
    if node then ca.commonClickNode(node); return "clicked " .. input.selector end
    return "error: not found " .. input.selector
end
all_dispatch.type = function(input)
    if not bot.cdp then return "error: CDP down" end
    local node = bot.cdp.find(input.selector)
    if node then ca.commonClickNode(node); Nd.setText(input.text); return "typed" end
    return "error: not found " .. input.selector
end
all_dispatch.navigate = function(input)
    if not bot.chrome then return "error: Chrome down" end
    bot.chrome.navigateTo(input.url); return "navigated to " .. input.url
end

-- ===== 6. Prompt（带 sections）=====
prompt.section("identity", "你是 Android 手机自动化助手。用 observe 了解当前状态，然后用工具操作。")
prompt.section("instructions", [[
完成任务流程:
1. open_app 打开 Chrome
2. navigate 到登录页面
3. observe 查看页面 → click/type 操作
4. 每步都观察验证后再继续
5. 完成后调用 done

可以在需要时使用 task 工具派发子 agent 处理子任务。
]])
if #agent_names > 0 then
    prompt.section("agents", "可用子 agent (用 task 工具调用):\n" .. agents.catalog(agent_registry))
end
prompt.section("skills", "可用技能 (用 load_skill 加载):\n" .. skill_catalog)
if memory_index ~= "" then
    prompt.section("memory", "记忆:\n" .. memory_index)
end

local system = prompt.assemble()

-- ===== 7. 任务 =====
local email    = os.getenv("GOOGLE_EMAIL")    or "your-email@gmail.com"
local password = os.getenv("GOOGLE_PASSWORD") or "your-password"

local task = string.format([[
打开 Google 并登录:
1. open_app("com.android.chrome")
2. navigate("https://accounts.google.com/signin")
3. 输入邮箱 %s，点击下一步
4. 输入密码 %s，点击下一步
5. 确认登录成功后 done
]], email, password)

local messages = {{ role = "user", content = task }}

print("\n===== AI Agent (完整 agent 系统) =====")
print("任务: " .. task)
print("======================================\n")

local _, done = harness.run(ai_client, messages, system, all_tools, all_dispatch, 30)
print("\n" .. (done and "✓ 完成" or "✗ 未完成"))
