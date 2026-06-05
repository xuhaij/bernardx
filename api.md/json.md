# json 模块 **[共享]**

JSON 编解码。

### `json.decode(str)` -> value

解析 JSON 字符串为 Lua 值（table/number/string/boolean/nil）。

```lua
local data = json.decode('{"name": "test", "items": [1, 2]}')
-- data.name == "test", data.items[1] == 1
```

### `json.encode(value [, indent])` -> string

将 Lua 值编码为 JSON 字符串。`indent` 为缩进空格数，默认紧凑输出。

```lua
local s = json.encode({a = 1, b = "hello"})
local pretty = json.encode({a = 1}, 2)
```
