# settings 模块 **[共享]**

配置管理（需要 ConfigureProvider）。所有操作异步 yield。

### `settings.get(key [, level])` -> value

获取配置值。

| level | 值 | 说明 |
|-------|-----|------|
| Worker | 0 | Worker 级别（默认） |
| Team | 1 | Team 级别 |
| Task | 2 | Task 级别 |

```lua
local value = settings.get("my_config")
local value = settings.get("my_config", 2)  -- Task level
```

### `settings.set(key, value [, level])` -> boolean

设置配置值。`value` 支持 nil/boolean/integer/number/string。level 同上，默认 0。

```lua
local ok = settings.set("my_config", "value")
local ok = settings.set("my_number", 123, 2)  -- Task level
```
