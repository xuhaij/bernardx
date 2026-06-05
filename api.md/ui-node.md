# UI 节点驱动 API **[主引擎]**

## Nd

| 方法 | 说明 |
|------|------|
| `Nd.connect(count)` -> boolean | 连接无障碍服务 |
| `Nd.disconnect()` | 断开连接 |
| `Nd.dumpNodeInfo()` -> string | 节点信息 XML |
| `Nd.clearNodeCache()` | 清除节点缓存 |
| `Nd.findNode(filter)` -> node/nil | 查找单个节点 |
| `Nd.findNodes(filter [, count])` -> table/nil | 查找多个节点 |
| `Nd.findOtherWindows(enabled)` | 设置是否查找其他窗口 |

---

## By（过滤器构建）

**文本:** `By.text(text)` / `By.textContains(text)` / `By.textStartsWith(text)` / `By.textEndsWith(text)` / `By.textRegex(pattern)`

**描述:** `By.desc(desc)` / `By.descContains(text)` / `By.descStartsWith(text)` / `By.descEndsWith(text)` / `By.descRegex(pattern)`

**类名:** `By.clz(class_name)` / `By.clzContains(class_name)` / `By.clzStartsWith(class_name)` / `By.clzEndsWith(class_name)` / `By.clzRegex(pattern)`

**XPath:** `By.xpath(expression)` — 使用 XPath 表达式匹配节点

```lua
local node = By.xpath("//android.widget.Button[@text='确定']"):find()
```

**其他:** `By.pkg(package)` / `By.res(resource_id)` / `By.resRegex(pattern)` / `By.depth(depth)` / `By.index(index)`

**状态:** `By.clickable(bool)` / `By.longClickable(bool)` / `By.checkable(bool)` / `By.checked(bool)` / `By.scrollable(bool)` / `By.enabled(bool)` / `By.focusable(bool)` / `By.focused(bool)` / `By.selected(bool)` / `By.visible(bool)` / `By.visibleX(bool)`

**关系:** `By.parent(filter [, min, max])` / `By.child(filter [, min, max])` / `By.bro(filter [, min, max])`

```lua
local node = By.textContains("确定"):clickable(true):find()
```

---

## Node 对象

**属性:** `clz()` / `text()` / `desc()` / `pkg()` / `res()` / `depth()` / `index()` / `bounds()` / `visibleBounds()` / `childCount()`

**状态:** `clickable()` / `checked()` / `selected()` / `checkable()` / `enabled()` / `focusable()` / `focused()` / `longClickable()` / `scrollable()` / `visible()` / `visibleX()`

**导航:** `parent()` / `child(index)` / `bro(index)`

**操作:** `setText(text)` / `click()` / `longClick()` / `select()` / `copy()` / `paste()` / `cut()` / `scrollForward()` / `scrollBackward()`

```lua
-- 查找并点击按钮
local btn = By.text("确定"):clickable(true):find()
if btn then btn:click() end

-- 获取节点信息
local node = By.textContains("标题"):find()
if node then
    local left, top, right, bottom = node:bounds()
    logi("bounds:", left, top, right, bottom)
end
```
