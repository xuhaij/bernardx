# BernardX Playground

AI + 行为树浏览器自动化测试靶场。通过 5 级认知难度的网页场景，系统化评估 AI+行为树框架的能力边界。

## 项目结构

```
example/
├── bernardx/                    # C++20 + Lua 5.4 异步运行时引擎
│   ├── src/
│   │   ├── lua/                 # Lua 运行时（LuaContext, LuaRuntime, 库绑定）
│   │   └── bt/                  # 行为树引擎（节点, 解析器, 黑板）
│   ├── docs/                    # 引擎文档
│   └── CMakeLists.txt
│
├── bernardx-agent/              # Lua 脚本 — AI Agent 层
│   ├── src/main.lua             # 入口（run / explore 模式）
│   ├── agents/                  # 子 agent 定义（.md frontmatter）
│   │   ├── tree-generator.md    # 生成确定性行为树
│   │   └── selector-finder.md  # CSS 选择器分析
│   ├── skills/                  # 技能定义
│   │   ├── bt-schema/SKILL.md  # BT 节点类型与树模式
│   │   └── cdp-automation/SKILL.md  # CDP 交互模式
│   ├── libs/                    # 库模块
│   │   ├── cdp/                 # Chrome DevTools Protocol 客户端
│   │   ├── ai/                  # AI API 封装（Anthropic/OpenAI）
│   │   └── agent/               # Agent harness（循环, 子agent, 压缩, 记忆）
│   └── scripts/common/         # BT 公共脚本
│       ├── init_cdp.lua         # 初始化 CDP + 可选 AI 客户端
│       ├── execute_step.lua     # 确定性操作执行器（click/type/check/...）
│       ├── observe.lua          # DOM 信息提取
│       ├── ai_decide.lua        # AI 决策（循环模式）
│       ├── execute_action.lua   # 执行 AI 决策的操作
│       ├── check_done.lua       # 循环退出检查
│       ├── verify.lua           # Playground API 验证
│       └── cleanup.lua          # 关闭 CDP 连接
│
├── playground/                  # Node.js 测试靶场
│   ├── server/
│   │   ├── index.js             # HTTP 服务入口
│   │   ├── app.js               # Express 配置
│   │   ├── routes/              # 路由（pages, verify, scenarios, admin）
│   │   ├── store/               # 内存状态存储
│   │   └── scenarios/           # 19 个场景（5 级难度）
│   │       ├── level1-direct/   # 直接行动（3 个）
│   │       ├── level2-context/  # 上下文理解（4 个）
│   │       ├── level3-reasoning/# 推理（4 个）
│   │       ├── level4-planning/ # 多步规划（4 个）
│   │       └── level5-exception/# 异常处理（4 个）
│   ├── bt_project/trees/       # 20 棵手写行为树（run 模式用）
│   ├── tests/                   # E2E 测试脚本
│   │   ├── run_scenario.sh     # 单场景运行
│   │   ├── run_batch.sh        # 批量运行（按 level）
│   │   ├── run_explore.sh      # 单场景 explore
│   │   ├── run_explore_batch.sh# 批量 explore
│   │   └── lib/                # 测试工具库
│   └── package.json
│
└── plan.md                      # 项目计划与设计文档
```

## 快速开始

### 1. 构建引擎

```bash
cd bernardx
cmake -B build
cmake --build build
```

### 2. 启动 Playground 服务

```bash
cd playground
npm install
npm start
# 服务运行在 http://localhost:3000
```

### 3. 启动 Chrome（headless）

```bash
chromium --headless --no-sandbox --disable-gpu \
  --remote-debugging-port=9222 about:blank
```

### 4. 环境变量

以下环境变量需提前配置：

| 变量 | 用途 | 必需 |
|------|------|------|
| `ANTHROPIC_BASE_URL` | AI API 地址 | explore 模式 |
| `ANTHROPIC_AUTH_TOKEN` | AI API 密钥 | explore 模式 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | 模型名称 | explore 模式 |

Run 模式执行 explore 生成的确定性树时不需要这些变量。

## 运行模式

### Run 模式 — 执行预定义行为树

执行 `playground/bt_project/trees/` 下的手写行为树，使用 AI 在循环中决策：

```bash
cd /workspaces/example

SCENARIO_ID=l1-click-button \
PROJECT_PATH=/workspaces/example/playground/bt_project \
TREE_DIR=l1_click_button \
PLAYGROUND_URL=http://localhost:3000 \
CDP_PORT=9222 \
TASK="Fill in the form with a name and click the Submit button" \
bernardx/build/bernardx --dir=/workspaces/example/bernardx-agent
```

### Explore 模式 — AI 探索并生成确定性树

AI 自主探索页面完成任务，然后委托 tree-generator 子 agent 生成不依赖 AI 的确定性行为树：

```bash
MODE=explore \
TARGET_URL=http://localhost:3000/scenarios/l1-click-button \
TASK="Fill in a name and click Submit" \
OUTPUT_DIR=/tmp/bt_explore_l1-click-button \
CDP_PORT=9222 \
bernardx/build/bernardx --dir=/workspaces/example/bernardx-agent
```

生成的树在 `OUTPUT_DIR/trees/` 下，可直接用 run 模式运行，**不需要 AI API key**：

```bash
# 无需 ANTHROPIC_AUTH_TOKEN
env -u ANTHROPIC_AUTH_TOKEN \
MODE=run SCENARIO_ID=l1-click-button \
TREE_DIR=l1-click-button \
PROJECT_PATH=/tmp/bt_explore_l1-click-button \
PLAYGROUND_URL=http://localhost:3000 \
CDP_PORT=9222 \
bernardx/build/bernardx --dir=/workspaces/example/bernardx-agent
```

## E2E 测试

### 前提条件

- Playground 服务运行在 `http://localhost:3000`
- Chrome CDP 运行在 `localhost:9222`
- `bernardx/build/bernardx` 可执行
- 环境变量已配置（仅 run 模式和 explore 模式需要）

### Run 模式测试

```bash
cd playground/tests

# 单场景
./run_scenario.sh l1-click-button

# 按 level 批量
./run_batch.sh 1
./run_batch.sh 1 2 3
./run_batch.sh all
```

### Explore 模式测试

```bash
cd playground/tests

# 单场景 explore
./run_explore.sh l1-click-button "Fill in a name and click Submit"

# 按 level 批量 explore
./run_explore_batch.sh 1
./run_explore_batch.sh all
```

### 环境变量覆盖

```bash
PLAYGROUND_URL=http://localhost:3000  # Playground 地址
CDP_PORT=9222                         # Chrome CDP 端口
BERNARDX_BIN=/path/to/bernardx        # 引擎二进制路径
STOP_ON_FAIL=1                        # 首个失败即停止
LOG_DIR=/path/to/logs                 # 日志目录
```

## 场景一览

### Level 1: 直接行动

| ID | 场景 | 验证条件 |
|----|------|----------|
| l1-click-button | 填写表单并点击提交 | `formSubmitted === true` |
| l1-type-search | 输入搜索词并搜索 | `lastSearch === 'wireless headphones'` |
| l1-toggle-checkbox | 勾选 Auto-save 复选框 | `autosave === true` |

### Level 2: 上下文理解

| ID | 场景 | AI 认知要求 |
|----|------|------------|
| l2-fill-from-instructions | 按指令卡填表 | 阅读指令 → 映射字段 |
| l2-select-best-value | 选择最佳商品 | 识别 "Best Value" 标记 |
| l2-answer-from-page | 从数据中提取答案 | 定位并提取仪表盘数据 |
| l2-navigate-dropdown | 下拉菜单导航 | 理解菜单结构 + 多步操作 |

### Level 3: 推理

| ID | 场景 | AI 认知要求 |
|----|------|------------|
| l3-price-compare | 预算内选最优 | 价格过滤 → 规格比较 |
| l3-filter-sort | 筛选排序 | 多步 UI 操作 + 条件理解 |
| l3-conditional-action | 按状态操作 | 读取状态 → 条件判断 |
| l3-form-validation | 生成合规密码 | 理解规则 → 推理生成 |

### Level 4: 多步规划

| ID | 场景 | AI 认知要求 |
|----|------|------------|
| l4-checkout-flow | 完整购物流程 | 多步流程 + 跨页状态 |
| l4-account-setup | 账户设置流程 | 3 步工作流 |
| l4-data-entry | 名片数据录入 | 数据读取 + 表单填写 |
| l4-file-management | 文件整理 | 操作序列规划 |

### Level 5: 异常处理

| ID | 场景 | AI 认知要求 |
|----|------|------------|
| l5-form-errors | 处理验证错误 | 提交 → 读错误 → 纠正 → 重试 |
| l5-disappearing-elements | 定时出现元素 | 等待策略 |
| l5-server-errors | 间歇性服务端错误 | 重试策略 |
| l5-dynamic-price | 动态价格购买 | 条件监控 → 时机判断 |

## 验证 API

### 核心端点

```
GET /verify/:scenarioId    — 检查场景是否通过
GET /api/scenarios         — 列出所有场景
GET /api/scenarios/:id     — 获取场景元数据
POST /api/admin/reset      — 重置所有场景
POST /api/admin/reset/:id  — 重置指定场景
```

验证检查**服务端状态**而非 DOM，确保行为树必须通过 CDP 真正完成浏览器交互。

## 子 Agent 系统

子 agent 定义在 `bernardx-agent/agents/` 目录，使用 Markdown frontmatter 格式：

```markdown
---
name: tree-generator
description: Generates deterministic behavior trees
tools: [observe, save_tree, list_scripts]
max_turns: 5
no_done: true
---
系统提示词内容...
```

主 agent 通过 `task(agent='tree-generator', description='...')` 调用子 agent。

### 添加新子 agent

1. 在 `bernardx-agent/agents/` 创建 `.md` 文件
2. 定义 frontmatter：`name`, `description`, `tools`, `max_turns`
3. 编写系统提示词作为正文
4. 重启 bernardx — 自动发现并注册

## 确定性行为树模式

Explore 模式生成的树使用 `execute_step.lua` 编码精确操作，运行时**不需要 AI**：

```json
{
  "type": "Sequence",
  "children": [
    { "type": "Script", "path": "scripts/common/init_cdp.lua", "args": { "ai": false } },
    { "type": "Script", "path": "scripts/common/execute_step.lua",
      "args": { "action": "type", "selector": "#name", "text": "John" } },
    { "type": "Script", "path": "scripts/common/execute_step.lua",
      "args": { "action": "click", "selector": "#submit-btn" } },
    { "type": "Wait", "ms": 1000 },
    { "type": "Script", "path": "scripts/common/verify.lua" },
    { "type": "Script", "path": "scripts/common/cleanup.lua" }
  ]
}
```

### execute_step 支持的操作

| Action | 字段 | 说明 |
|--------|------|------|
| `click` | `selector` | 点击元素 |
| `type` | `selector`, `text` | 清空并输入文本 |
| `check` | `selector` | 勾选 checkbox |
| `select` | `selector`, `value` | 选择下拉选项 |
| `navigate` | `url` | 导航到 URL |
| `wait` | `ms` | 等待毫秒数 |
| `evaluate` | `js` | 执行 JavaScript |

## 技术栈

- **C++20** + CMake — 行为树引擎
- **Lua 5.4** + async_simple — 脚本运行时与异步调度
- **Chrome DevTools Protocol** — 浏览器自动化
- **Anthropic API** — AI 推理（支持兼容 API）
- **Express.js** — 测试靶场服务
- **Bash** — E2E 测试框架
