# http 模块 **[共享]**

HTTP 客户端（异步，基于 cinatra）。所有请求异步 yield。

## HTTP 请求

### `http.get(url [, headers])` -> status, body, err

```lua
local status, body, err = http.get("https://api.example.com/data")
local status, body, err = http.get("https://api.example.com/data", {
    ["Authorization"] = "Bearer xxx"
})
```

### `http.post(url [, body, content_type, headers])` -> status, body, err

`content_type` 可选值: `"json"`, `"text"`, `"html"`, `"xml"`, `"form"`, `"octet"`。

```lua
local status, body, err = http.post(
    "https://api.example.com/users",
    '{"name":"test"}',
    "json"
)
```

### `http.put(url [, body, content_type, headers])` -> status, body, err

```lua
local status, body, err = http.put(
    "https://api.example.com/users/1",
    '{"name":"updated"}',
    "json"
)
```

### `http.del(url [, headers])` -> status, body, err

```lua
local status, body, err = http.del("https://api.example.com/users/1")
```

---

## WebSocket

### `http.ws_create(url)` -> ws

创建 WebSocket 连接对象。

```lua
local ws = http.ws_create("ws://localhost:8080/ws")
ws.onmessage = function(msg) logi("received:", msg) end
ws.onclose = function() logi("closed") end
local ok, err = ws:connect()
if ok then
    ws:send("hello")
    ws:close()
end
```

### WebSocket 对象方法

| 方法 | 说明 |
|------|------|
| `ws:connect()` -> ok, err | 连接（异步 yield） |
| `ws:send(msg [, mode])` -> ok, err | 发送消息，`mode` 可选 `"text"`/`"binary"` |
| `ws:close()` -> ok | 关闭连接 |

### WebSocket 回调属性

| 属性 | 说明 |
|------|------|
| `ws.onmessage` | 收到消息回调 `fn(msg)` |
| `ws.onclose` | 连接关闭回调 `fn()` |
| `ws.onerror` | 错误回调 `fn(err)` |
