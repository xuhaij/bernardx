# 输入管理 API **[主引擎]**

---

## pointer() -> userdata

创建触摸指针对象。

```lua
local p = pointer()
p.x = 500
p.y = 800
p:sync()  -- 同步触摸状态
p:up()    -- 释放触摸
```

**Pointer 属性:**

| 属性 | 类型 | 说明 |
|------|------|------|
| `x` | number | X 坐标 |
| `y` | number | Y 坐标 |
| `major` | number | 触摸主轴大小 |
| `minor` | number | 触摸副轴大小 |
| `pressure` | number | 压力值 |
| `size` | number | 触摸大小 |

**Pointer 方法:** `sync()` -> result_code, `up()` -> result_code

---

## tap(x, y [, time])

点击屏幕。`time` 为按压时长（毫秒），默认随机 90-200ms。

```lua
tap(500, 800)       -- 快速点击
tap(500, 800, 500)  -- 长按 500ms
```

---

## swipe(x1, y1, x2, y2, time)

滑动屏幕。

```lua
swipe(500, 1500, 500, 500, 500)
```

---

## 按键操作

### keyDown(key_code) -> boolean

按下按键。

```lua
local ok = keyDown(KeyCode.HOME)
```

### keyUp(key_code) -> boolean

释放按键。

```lua
local ok = keyUp(KeyCode.HOME)
```

### keyPress(key_code [, time]) -> boolean

按下并释放按键。`time` 默认随机 140-210ms。

```lua
keyPress(KeyCode.BACK)
keyPress(KeyCode.HOME, 300)
```

---

## KeyCode 常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `KeyCode.HOME` | 3 | 主页键 |
| `KeyCode.BACK` | 4 | 返回键 |
| `KeyCode.CALL` | 5 | 呼叫键 |
| `KeyCode.END_CALL` | 6 | 结束呼叫 |
| `KeyCode.VOLUME_UP` | 24 | 音量加 |
| `KeyCode.VOLUME_DOWN` | 25 | 音量减 |
| `KeyCode.POWER` | 26 | 电源键 |
| `KeyCode.CAMERA` | 27 | 相机键 |
| `KeyCode.CLEAR` | 28 | 清除键 |
| `KeyCode.ENTER` | 66 | 回车键 |
| `KeyCode.MENU` | 67 | 菜单键 |

---

## InputMethod

| 方法 | 说明 |
|------|------|
| `InputMethod.enable()` -> boolean | 检查输入法是否可用 |
| `InputMethod.input(text [, location])` -> boolean | 输入文本 |
| `InputMethod.shown()` -> boolean | 输入法是否显示 |
| `InputMethod.performEditorAction(action)` -> boolean | 执行编辑器操作 |

```lua
if InputMethod.enable() then
    InputMethod.input("Hello World")
end
```
