# resource 模块 **[共享]**

资源加载（需要 ResourceProvider）。所有操作异步 yield。

### `resource.ls([path])` -> table

列出资源目录内容。返回数组，每个元素为 `{name, is_dir}`。

```lua
local entries = resource.ls("images")
for _, e in ipairs(entries) do
    print(e.name, e.is_dir)
end
```

### `resource.load(path)` -> string | nil

加载资源文件内容。

```lua
local data = resource.load("images/icon.png")
```
