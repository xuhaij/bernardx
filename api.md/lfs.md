# lfs 模块 **[共享]**

文件系统操作（兼容 LuaFileSystem API）。

### `lfs.attributes(path [, name])` -> table | value

获取文件属性。不指定 `name` 时返回 `{mode, size, modification}`。

```lua
local attrs = lfs.attributes("/path/to/file")
-- attrs.mode == "file"|"directory"|"link"|"other"
-- attrs.size == 12345
-- attrs.modification == 1709123456

local mode = lfs.attributes("/path/to/file", "mode")
local size = lfs.attributes("/path/to/file", "size")
local mtime = lfs.attributes("/path/to/file", "modification")
```

### `lfs.symlinkattributes(path [, name])` -> string

获取符号链接属性（不跟随链接）。

```lua
local mode = lfs.symlinkattributes("/path/to/link", "mode")  -- "link"
```

### `lfs.currentdir()` -> string

获取当前工作目录。

### `lfs.chdir(path)` -> boolean, err?

切换工作目录。

```lua
local ok, err = lfs.chdir("/tmp")
```

### `lfs.mkdir(path)` -> boolean, err?

创建目录。

```lua
local ok, err = lfs.mkdir("/tmp/mydir")
```

### `lfs.rmdir(path)` -> boolean, err?

删除目录。

```lua
local ok, err = lfs.rmdir("/tmp/mydir")
```

### `lfs.dir(path)` -> iterator

返回目录遍历迭代器。

```lua
for name in lfs.dir("/tmp") do
    print(name)
end
```

### `lfs.touch(path)` -> boolean, err?

创建文件或更新最后修改时间。

```lua
local ok, err = lfs.touch("/tmp/newfile.txt")
```
