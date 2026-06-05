# 全局函数 **[共享]**

主引擎和 BT 引擎均可使用。

## 时间

### `now()` -> milliseconds

获取当前毫秒时间戳（LuaRuntime 内置）。

```lua
local ms = now()
```

---

## 日志

### `logv(...)` / `logd(...)` / `logi(...)` / `logw(...)` / `loge(...)`

输出不同级别的日志。`print` 是 `logd` 的别名。

```lua
logv("verbose")
logd("debug")
logi("info")
logw("warn")
loge("error")
print("same as logd")
```

### `logtag([tag])` -> tag | nil

设置或获取日志标签前缀。不传参数时返回当前标签。

```lua
logtag("MyModule")
logi("tagged message")  -- MyModule: tagged message
local cur = logtag()
```

---

## 工具

### `uuid_gen()` -> string

生成 UUID 字符串。

```lua
local id = uuid_gen()
-- "550e8400-e29b-41d4-a716-446655440000"
```

### `assert(value [, message])`

增强版 assert。条件为 true 时记录 info 日志，为 false 时抛出错误。

```lua
assert(x > 0, "x must be positive")
```

---

## 协程与定时器

### `sleep(ms)`

异步暂停当前协程指定毫秒。可被中断，中断时抛出 `"interrupt"` 错误。

```lua
sleep(1000)  -- 暂停 1 秒
```

### `setTimeout(ms, callback)` -> handle

设置定时回调，返回定时器句柄。

```lua
local h = setTimeout(5000, function()
    logi("5 seconds passed")
end)
```

### `clearTimeout(handle)`

取消 `setTimeout` 创建的定时器。

```lua
clearTimeout(h)
```

### `await(resolve_fn, reject_fn)`

等待异步回调完成。

```lua
local result = await(function(resolve, reject)
    setTimeout(1000, function()
        resolve("done")
    end)
end)
```

---

## 模块加载

### `require(name)` -> module

加载 Lua 模块（通过 CodeProvider 异步加载）。

```lua
local utils = require("utils")
```

### `loadfile(path)` -> chunk | nil

加载 Lua 文件并返回 chunk 函数（通过 CodeProvider 异步加载）。

```lua
local chunk = loadfile("scripts/helper.lua")
if chunk then chunk() end
```

---

## 清理回调

### `addCleanup(callback)` -> ref

注册脚本结束时的清理回调，返回引用 ID。

```lua
local ref = addCleanup(function()
    logi("cleaning up")
end)
```

### `cancelCleanup(ref)` -> boolean

取消已注册的清理回调。

```lua
cancelCleanup(ref)
```

### `cleanup()`

手动执行所有已注册的清理回调（通常由引擎自动调用）。

---

## 环境变量

通过 `AddEnvironment()` 注入的全局变量，在脚本中直接访问：

```lua
print(DEVICE_NAME)
print(WORKING_DIR)
print(ENGINE_VERSION)
```
