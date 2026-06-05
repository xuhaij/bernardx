# bernardx-playground: AI+行为树测试靶场 — 执行计划

## 1. 项目背景与目标

### 现有框架

- **bernardx**: C++20 + Lua 5.4 异步运行时，内置完整行为树引擎（Selector、Sequence、Parallel、Decorator、Sensor 等）
- **bernardx-agent**: Lua 脚本项目，包含 CDP 客户端库、AI API 封装、BT 通用脚本，提供 run/explore 两种运行模式
- **playground**: Node.js 测试靶场，提供多难度网页场景和验证 API

### 问题

框架已具备完整的浏览器自动化能力，但缺少系统化的测试目标来验证 AI+行为树是否能真正完成复杂网页操作任务。

### 目标

创建独立的测试靶场项目 **bernardx-playground**，生成不同认知难度等级的网页场景，配合验证 API，系统化评估 AI+行为树框架的能力边界。

### 已验证的端到端闭环

以下流程已在开发环境中验证通过：

```
bernardx 启动 → BT 引擎创建独立 LuaRuntime（继承主运行时的 C++ 库）
→ Script 节点初始化 CDP + AI 客户端，存入黑板
→ BT 循环：observe(DOM 信息) → ai_decide(工具调用) → execute(CDP 操作) → verify(检查)
→ AI 判断 done → check_done 退出循环 → cleanup 关闭连接
```

---

## 2. 设计决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 架构 | 轻量后端 (Express.js) + 前端页面 | 支持登录、表单提交等真实交互，开发成本低 |
| 验证机制 | 服务端验证 API (`GET /verify/:scenarioId`) | 检查服务端状态而非 DOM，防止伪造结果 |
| 页面生成 | 先手工设计核心场景，再模板化 | 降低风险，验证过的模式再抽象 |
| 难度划分 | 按认知难度分 5 级 | 从"能否找到按钮"到"能否处理异常"，精准测试 AI 推理能力 |
| AI 感知方式 | DOM 节点信息文本（非视觉/截图） | 更高效，成本更低，信息更精确 |
| AI 配置 | 环境变量 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_DEFAULT_SONNET_MODEL` | 支持不同 AI 后端和模型切换 |

---

## 3. 项目结构

### 三项目分离架构

```
bernardx/                        # C++ Lua 运行时引擎
├── src/lua/                     # Lua 运行时核心
├── src/bt/                      # 行为树引擎
└── src/main.cc                  # 可执行入口

bernardx-agent/                  # Lua 脚本 — AI Agent
├── src/
│   ├── main.lua                 # 入口（run/explore 模式选择）
│   ├── dom_helper.lua           # DOM 信息提取
│   ├── test_ai.lua              # AI 接口测试
│   ├── test_dom.lua             # DOM 解析测试
│   └── test_interactions.lua    # 交互操作测试
├── libs/
│   ├── cdp/init.lua             # Chrome DevTools Protocol 客户端
│   ├── ai/                      # AI API 封装（Anthropic/OpenAI）
│   │   ├── init.lua
│   │   ├── anthropic.lua
│   │   ├── openai.lua
│   │   ├── tools.lua
│   │   └── utils.lua
│   └── agent/                   # Agent 框架（harness 层）
│       ├── init.lua             # 模块入口
│       ├── compact.lua          # 上下文压缩
│       ├── hooks.lua            # 钩子系统
│       ├── memory.lua           # 记忆管理
│       ├── prompt.lua           # 提示词构建
│       ├── recovery.lua         # 错误恢复
│       ├── skills.lua           # 技能加载
│       ├── subagent.lua         # 子代理调度
│       └── util.lua             # 通用工具
├── scripts/
│   └── common/                  # BT 通用脚本
│       ├── init_cdp.lua         # 初始化 CDP + AI
│       ├── observe.lua          # DOM 观察
│       ├── ai_decide.lua        # AI 决策
│       ├── execute_action.lua   # 执行操作
│       ├── check_done.lua       # 循环退出检查
│       ├── verify.lua           # 结果验证
│       └── cleanup.lua          # 清理
└── skills/                      # 技能定义
    ├── bt-schema/SKILL.md       # BT 树结构定义
    └── cdp-automation/SKILL.md  # CDP 自动化技能

playground/                      # 测试靶场（纯场景服务器）
├── server/                      # Express.js 后端
│   ├── index.js                 # 入口（启动 HTTP 服务）
│   ├── app.js                   # Express 应用配置
│   ├── routes/                  # 路由模块
│   │   ├── pages.js             # 场景页面服务
│   │   ├── verify.js            # 验证端点
│   │   ├── scenarios.js         # 场景元数据 API
│   │   └── admin.js             # 管理端点（重置等）
│   ├── store/
│   │   └── memory-store.js      # 内存状态存储
│   └── scenarios/               # 5 级难度场景（.js + .html）
│       ├── registry.js          # 场景注册表
│       ├── level1-direct/       # 直接行动（3 个场景）
│       ├── level2-context/      # 上下文理解（4 个场景）
│       ├── level3-reasoning/    # 推理（4 个场景）
│       ├── level4-planning/     # 多步规划（4 个场景）
│       └── level5-exception/    # 异常处理（4 个场景）
├── public/                      # 静态资源
│   ├── css/main.css             # 共享样式
│   └── js/playground-client.js  # 前端脚本
├── bt_project/
│   └── trees/                   # 20 棵行为树（19 场景 + 1 测试树 l1_form）
└── package.json
```

---

## 4. 场景定义格式

每个场景是一个 JS 模块，导出标准化对象：

```javascript
// server/scenarios/level1-direct/click-button.js
module.exports = {
  id: 'l1-click-button',
  level: 1,
  levelName: 'Direct Action',
  title: 'Click the Submit Button',
  description: 'Click the Submit button.',
  route: '/scenarios/l1-click-button',
  initialState: { formSubmitted: false, submissionCount: 0 },
  endpoints: {
    'POST /api/l1-click-button/submit': (store, body) => {
      store.set('formSubmitted', true);
      store.set('submissionCount', store.get('submissionCount') + 1);
      return { success: true, message: 'Form submitted!' };
    },
  },
  verify: (store) => {
    const passed = store.get('formSubmitted') === true;
    return {
      passed,
      message: passed
        ? 'Form was submitted successfully.'
        : 'Form has not been submitted yet.',
      details: {
        formSubmitted: store.get('formSubmitted'),
        submissionCount: store.get('submissionCount'),
      },
    };
  },
  template: 'click-button.html',
};
```

---

## 5. 五级认知难度场景设计

### Level 1: 直接行动 — 目标明确，单步交互

| ID | 场景 | 任务描述 | 验证条件 |
|----|------|----------|----------|
| l1-click-button | 点击提交按钮 | "Click the Submit button." | 服务端记录 `formSubmitted === true` |
| l1-type-search | 搜索框输入 | "Type 'wireless headphones' into the search box and click Search." | `store.get('lastSearch') === 'wireless headphones'` |
| l1-toggle-checkbox | 勾选 checkbox | "Check the 'Auto-save' checkbox." | `store.get('autosave') === true` |

**共 3 个场景，19 个场景总计（L1: 3 + L2: 4 + L3: 4 + L4: 4 + L5: 4）。**

**AI 认知要求**：定位目标元素，执行单一操作。

### Level 2: 上下文理解 — 需要阅读理解页面内容

| ID | 场景 | 任务描述 | 验证条件 | AI 认知要求 |
|----|------|----------|----------|------------|
| l2-fill-from-instructions | 按指令卡填表 | "Read the instructions on the page and fill out the form accordingly." | 三个字段值匹配指令卡内容 | 阅读指令文本 → 映射到表单字段 |
| l2-select-best-value | 选择最佳商品 | "Add the best value product to your cart." | 正确商品被加入购物车 | 识别"Best Value"标记或比较价格 |
| l2-answer-from-page | 从数据中提取答案 | "What is the temperature in Tokyo? Type it into the answer field and submit." | 提交的答案匹配东京温度 | 从仪表盘数据中定位并提取 |
| l2-navigate-dropdown | 下拉菜单导航 | "Navigate to the Headphones category page using the navigation menu." | 通过下拉菜单导航（非直接 URL） | 理解菜单结构 + 多步 hover/click |

### Level 3: 推理 — 需要比较、评估、逻辑判断

| ID | 场景 | 任务描述 | 验证条件 | AI 认知要求 |
|----|------|----------|----------|------------|
| l3-price-compare | 预算内选最优 | "Find the best laptop within the $800 budget and add it to your cart. Best means highest specs for the price." | 选中笔记本在预算内且性价比最高 | 价格过滤 → 规格比较 → 选择 |
| l3-filter-sort | 筛选排序 | "Show Electronics with 4+ stars, sort by price (low to high), then add the top result to your cart." | 加入购物车的商品符合条件 | 多步 UI 操作 + 条件理解 |
| l3-conditional-action | 按状态操作 | "Cancel the order that is still being processed." | 仅取消"Processing"状态的订单 | 读取状态 → 条件判断 → 定向操作 |
| l3-form-validation | 生成合规密码 | "Create a valid account with username 'testuser' and a compliant password." | 提交的密码通过服务端验证规则 | 理解规则 → 推理生成合规值 |

### Level 4: 多步规划 — 需要规划行动序列、跨页面保持状态

| ID | 场景 | 任务描述 | 验证条件 | AI 认知要求 |
|----|------|----------|----------|------------|
| l4-checkout-flow | 完整购物流程 | "Add a wireless mouse to cart, fill in shipping details, and complete the order." | `cartItem === 'Wireless Mouse'` + 收货信息完整 + 订单已提交 | 多步流程 + 跨页状态保持 |
| l4-account-setup | 账户设置流程 | "Register an account with username 'johndoe', set up your profile, and configure preferences." | `username === 'johndoe'` + bio + theme 已设置 | 3 步工作流：注册→资料→偏好 |
| l4-data-entry | 名片数据录入 | "Copy all contact information from the business card on the left into the form on the right." | 5 个字段与名片匹配（name/title/company/email/phone） | 单页数据读取 + 表单填写 |
| l4-file-management | 文件整理 | "Create folders named 'Documents' and 'Images', then move files into the correct folders based on their extension." | `Documents` + `Images` 文件夹创建 + 6 个文件按扩展名归类 | 指令解析 + 操作序列规划 |

### Level 5: 异常处理 — 需要处理错误、等待、恢复

| ID | 场景 | 任务描述 | 验证条件 | AI 认知要求 |
|----|------|----------|----------|------------|
| l5-form-errors | 处理验证错误 | "Fill out the contact form. The server will reject the first submission — read the errors, fix them, and resubmit until it's accepted." | `submitted === true` + `attempts >= 2` | 提交 → 读错误 → 纠正 → 重试 |
| l5-disappearing-elements | 定时出现元素 | "Wait for the 'Claim Reward' button to appear, then click it before it vanishes." | `rewardClaimed === true` | 理解元素时序 → 等待策略 |
| l5-server-errors | 间歇性服务端错误 | "Submit the form. The server may return errors — keep retrying until it succeeds." | `submitted === true` + `attempts >= 2`（随机失败 2-5 次后成功） | 错误识别 → 重试策略 |
| l5-dynamic-price | 动态价格购买 | "Wait until the price drops below $30, then click Buy." | `purchased === true` + `purchasePrice < 30` | 条件监控 → 时机判断 |

---

## 6. 验证 API 设计

### 核心端点

```
GET /verify/:scenarioId
```

响应：
```json
{
  "scenarioId": "l1-click-button",
  "passed": true,
  "message": "Form was submitted successfully.",
  "details": { "formSubmitted": true, "submissionCount": 1 },
  "timestamp": "2026-05-22T10:30:00.000Z"
}
```

### 辅助端点

| 方法 | 路径 | 用途 |
|------|------|------|
| GET | `/api/scenarios` | 列出所有可用场景 |
| GET | `/api/scenarios/:id` | 获取场景元数据 + 任务描述 |
| POST | `/api/admin/reset` | 重置所有场景状态 |
| POST | `/api/admin/reset/:id` | 重置指定场景 |

### 验证原理

验证端点检查**服务端状态**，不是 DOM。状态仅由页面事件处理器通过 API 调用更新。这确保：
1. 行为树必须通过 CDP 真正完成浏览器交互
2. 不能通过直接执行 JS 伪造结果
3. 镜像真实世界的端到端测试模式

---

## 7. bernardx 集成

### BT 脚本节点约束（已验证）

以下约束通过实际开发测试确认，实施时必须遵守：

1. **BT 引擎创建独立 LuaRuntime** — `StartLoop` 创建新的 Lua 运行时，通过 `InheritFrom()` 继承主运行时的 C++ 库（json、http、bt）
2. **黑板在 `bt.run()` 时被清空** — `Load()` 调用 `blackboard_.Clear()`。所有初始化必须在 BT 树内的 Script 节点中完成（如 init_cdp.lua）
3. **黑板支持 Lua table** — `PopLuaValue` 已支持 table/function/userdata 类型的 LuaRef 存储
4. **Wrapper 节点内的 Script 会被初始化** — Repeat/RetryUntilSuccessful 的子节点递归初始化
5. **Script 节点返回 "success" 才会继续 Sequence** — 返回 "running" 会阻塞后续节点
6. **Decorator 不包装 Tick 返回值** — ForceSuccess 等装饰器仅用于条件判断，不改变节点返回值
7. **`tool_choice` 必须用对象格式** — `{ type = "auto" }`，不是字符串 `"auto"`

### BT 树模式（已验证）

> 注意：场景 ID 使用连字符（如 `l1-click-button`），但 BT 树目录名使用下划线（如 `l1_click_button`）。`main.lua` 中的 `tree_map` 负责映射。
> BT 树存放在 `playground/bt_project/trees/` 目录下，通过 `PROJECT_PATH` 环境变量指定路径。

```
Sequence (根节点)
├── Script: init_cdp              # 初始化 CDP + AI 客户端，导航到场景页面
├── Script: observe               # 初始 DOM 信息提取
├── Repeat(N)                     # 最多 N 轮
│   └── Selector                  # 循环退出检查
│       ├── Script: check_done    #   task_done=true → success → 退出循环
│       └── Sequence              #   否则执行一步
│           ├── Script: ai_decide #     AI 分析 DOM → 工具调用，返回 success
│           ├── Script: execute   #     执行 CDP 操作，返回 success
│           ├── Script: observe   #     重新提取 DOM 信息
│           └── Script: verify    #     记录结果，返回 success
└── Script: cleanup               # 关闭 CDP 连接
```

### AI 感知方式

AI 通过 DOM 节点信息文本感知页面，不使用截图。observe.lua 通过 CDP `evaluate` 执行 JS，提取：
- 页面标题和 URL
- 页面文本内容（h1-h3, p, label 等）
- 交互元素列表（button, input, select, textarea 等）及其 CSS 选择器、文本、值

输出格式：
```
Page: BernardX Test Page
URL: http://localhost:3000/
Content:
  BernardX Playground
  Enter your name:
Elements:
  1. input[text] placeholder="Type here..." -> #name
  2. button[submit] "Submit" -> #submit-btn
```

### AI 工具定义

```lua
local ai_tools = {
    ai.tool({ name = "click", ... input_schema = ... }),
    ai.tool({ name = "type", ... }),
    ai.tool({ name = "done", ... }),
}
```

### AI 配置

```bash
ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic  # 或 https://api.anthropic.com
ANTHROPIC_AUTH_TOKEN=your-token
ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5-turbo                 # 或 claude-sonnet-4-20250514
```

---

## 8. 已修复的框架问题

以下 bernardx 框架问题在开发过程中发现并修复：

| 问题 | 根因 | 修复 |
|------|------|------|
| BT 脚本无法 `require('json')` | `StartLoop` 创建空 LuaRuntime，不继承 C++ 库 | 添加 `InheritFrom()` 方法传递库引用 |
| 黑板无法存 Lua table | `PopLuaValue` 不处理 table/function 类型 | 添加 LuaRef 支持 |
| Repeat 内的 Script 不初始化 | `InitScriptNodesRecursiveAsync` 只遍历 Composite | 添加 Repeat/RetryUntilSuccessful 遍历 |

---

## 9. 实施阶段

### Phase 1: 基础设施 ✅ 已完成

**目标**：可运行的服务器 + 1 个完整场景

1. ✅ 初始化 Node.js 项目，安装 Express
2. ✅ 实现场景注册系统（自动发现 `server/scenarios/` 下模块）
3. ✅ 实现内存状态存储（按场景命名空间隔离）
4. ✅ 实现核心路由（场景列表、页面服务、验证）
5. ✅ 实现 **L1-1: click-button** 作为第一个完整场景
6. ✅ 手动测试：浏览器访问 → 点击 → 调用 verify 端点确认

### Phase 2: Level 1 + BT 集成 ✅ 已完成

**目标**：Level 1 全部场景 + bernardx 完整闭环

7. ✅ 实现 L1-2（type-search）和 L1-3（toggle-checkbox）
8. ✅ 构建共享 CSS（拟真的表单/页面样式）
9. ✅ 为每个 Level 1 场景创建 BT 树
10. ✅ 打通完整闭环：bernardx → Chrome → CDP → AI → 验证通过

### Phase 3: Level 2-3 ✅ 已完成

11. ✅ 实现 Level 2 的 4 个场景（上下文理解）
12. ✅ 实现 Level 3 的 4 个场景（推理）
13. ✅ 构建对应 BT 树

### Phase 4: Level 4-5 ✅ 已完成

14. ✅ 实现 Level 4 的 4 个场景（多步规划）
15. ✅ 实现 Level 5 的 4 个场景（异常处理）
16. ✅ 为所有场景创建 BT 树（共 19 棵 + 1 棵测试树 l1_form）

### Phase 5: E2E 测试 + Docker + 文档

17. ✅ `tests/lib/common.sh` 日志、计时、退出码
18. ✅ `tests/lib/services.sh` 前置检查、场景重置/验证、agent 执行封装
19. ✅ `tests/run_scenario.sh` 单场景运行器（支持 --retry、--log-dir）
20. ✅ `tests/run_batch.sh` 批量运行器（按 level 选择、汇总报告、results.json）
21. ✅ `tests/run_explore.sh` + `tests/run_explore_batch.sh` explore 模式测试
22. ✅ 修复 `l1_click_button` 和 `l1_form` BT 树中硬编码的 URL
23. ⬜ 编写 Dockerfile
24. ⬜ 编写 docker-compose（playground + headless Chrome）
25. ⬜ README + 使用说明
26. ⬜ `.env.example` 环境变量示例

---

## 10. Docker 启动方案（待实现）

### docker-compose.yml 计划结构

```yaml
services:
  playground:
    build: .
    ports: ["3000:3000"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/scenarios"]

  chrome:
    image: chromedp/headless-shell:latest
    ports: ["9222:9222"]
    command: --remote-debugging-port=9222 --remote-debugging-address=0.0.0.0 --disable-gpu --no-sandbox
    depends_on:
      playground: { condition: service_healthy }
```

### 开发模式（当前使用方式）

```bash
# 终端 1：启动 playground
cd playground && npm install && npm start

# 终端 2：启动 Chrome
chromium --headless --no-sandbox --disable-gpu --remote-debugging-port=9222 about:blank

# 终端 3：运行 agent（run 模式）
SCENARIO_ID=l1-click-button \
PLAYGROUND_URL=http://localhost:3000 \
PROJECT_PATH=/workspaces/example/playground/bt_project \
ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic \
ANTHROPIC_AUTH_TOKEN=your-token \
ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5-turbo \
bernardx --dir=/workspaces/example/bernardx-agent

# 终端 3：运行 agent（explore 模式，未来）
MODE=explore \
TARGET_URL=http://localhost:3000/scenarios/l1-click-button \
TASK="Click the Submit button" \
bernardx --dir=/workspaces/example/bernardx-agent
```

---

## 11. 验证方式

1. **单场景手动测试**：启动 playground + Chrome，手动完成场景，调用 verify 端点确认通过
2. **BT 自动化测试**：运行 bernardx 的 BT 树，检查验证结果
3. **批量测试**：`run_scenario.sh --all` 顺序执行所有场景，输出通过/失败报告
4. **跨难度验证**：确认 Level 1 通过率高 → Level 5 通过率低（验证难度梯度有效）
