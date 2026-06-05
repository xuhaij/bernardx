# 行为树 API **[BT]**

仅在行为树 Lua 上下文中可用。BT 引擎创建独立 Lua 上下文，继承主引擎的全部共享库和扩展，并额外注入 `bt` 和 `blackboard` 模块。

---

## bt 模块

行为树控制接口。

### bt.run(json_or_path) -> ok, status_or_error

运行行为树。参数可以是 JSON 字符串或行为树目录路径。异步 yield，行为树运行期间协程挂起。

- 传入 `{` 或 `[` 开头的字符串视为 JSON
- 否则视为目录路径（相对于 `project_path`）
- 行为树成功/失败时恢复协程

**返回值:**
- 成功: `true, "success"`
- 失败: `true, "failure"`
- 错误: `false, "error message"`
- 中断: `true, "stopped"`

```lua
-- 从 JSON 运行
local ok, result = bt.run([[
{
    "type": "Sequence",
    "children": [
        {"type": "Script", "path": "scripts/check.lua"},
        {"type": "Script", "path": "scripts/action.lua"}
    ]
}
]])

-- 从目录运行
bt.set_project_path("/sdcard/my_project")
local ok, result = bt.run("trees/main_tree")
```

### bt.pause()

暂停正在运行的行为树。已执行的节点保持状态。

### bt.resume()

恢复暂停的行为树。

### bt.stop()

停止行为树，中断所有正在运行的节点。

### bt.notify(name, data)

向行为树发送事件通知。事件通过黑板键 `_event_<name>` 传递，行为树在下一个 tick 处理。

```lua
bt.notify("target_found", {x = 100, y = 200})
bt.notify("timeout", nil)
```

### bt.get_status() -> string

获取行为树当前状态。

| 返回值 | 说明 |
|--------|------|
| `"running"` | 正在运行 |
| `"paused"` | 已暂停 |
| `"stopped"` | 已停止 |

### bt.set_project_path(path)

设置行为树项目根路径。影响相对路径解析和脚本/传感器加载路径。

搜索路径（按优先级）:
1. `<project_path>/scripts/`
2. `<project_path>/sensors/`
3. `<project_path>/`
4. `<main_libs_path>/`（如果设置）

```lua
bt.set_project_path("/sdcard/my_project")
```

---

## blackboard 模块

黑板是行为树的共享键值存储，主引擎和 BT 引擎共用同一个 Blackboard 实例。

### blackboard.set(key, value)

设置黑板值。`value` 支持 nil/boolean/integer/number/string/table。

```lua
blackboard.set("target_x", 100)
blackboard.set("config", {speed = 5, mode = "auto"})
blackboard.set("active", true)
```

### blackboard.get(key) -> value

获取黑板值。键不存在时返回 nil。

```lua
local x = blackboard.get("target_x")
if x then logi("target at:", x) end
```

### blackboard.has(key) -> boolean

检查黑板中是否存在指定键。

### blackboard.remove(key)

从黑板中移除指定键。

### blackboard.clear()

清空黑板所有数据。

### blackboard.to_table() -> table

将黑板内容导出为 Lua 表。

```lua
local data = blackboard.to_table()
for k, v in pairs(data) do logi(k, "=", v) end
```

---

## 脚本节点约定

行为树的 Script 节点和 Sensor 节点通过 `require` 或 `loadfile` 加载 Lua 脚本。脚本必须返回一个 table，包含生命周期函数。

### 必需函数

#### `Tick()` -> string

每个 tick 调用。必须返回节点状态：

| 返回值 | 说明 |
|--------|------|
| `"success"` | 节点执行成功 |
| `"failure"` | 节点执行失败 |
| `"running"` | 节点仍在运行 |

### 可选函数

| 函数 | 说明 |
|------|------|
| `Enter()` | 节点首次被激活时调用 |
| `Exit()` | 节点不再活跃时调用 |
| `Abort()` | 节点被中断时调用（仅带 abort 装饰器的节点） |

### 示例

```lua
-- scripts/patrol.lua
local target = nil
local M = {}

function M:Enter()
    target = blackboard.get("patrol_target")
    logi("starting patrol to:", target)
end

function M:Tick()
    if not target then return "failure" end
    local pos = blackboard.get("position")
    if pos == target then return "success" end
    return "running"
end

function M:Exit()
    logi("patrol ended")
    target = nil
end

function M:Abort()
    logw("patrol aborted!")
    target = nil
end

return M
```

Sensor 脚本结构与普通脚本相同，但 `Tick` 由定时器驱动而非行为树 tick。

```lua
-- sensors/screen_sensor.lua
local M = {}

function M:Tick()
    local color = Display:getColor(100, 200)
    blackboard.set("screen_color", color)
    return "success"
end

return M
```
