# 屏幕显示 API **[主引擎]**

## Display

| 方法 | 说明 |
|------|------|
| `Display.save(path [, x, y, x1, y1, format, quality])` -> integer | 截屏保存，0=成功 |
| `Display.getBaseSize()` -> width, height | 基础屏幕尺寸 |
| `Display.getSize()` -> width, height | 当前屏幕尺寸 |
| `Display.getDirection()` -> integer | 当前屏幕方向 |
| `Display.getBaseDirection()` -> integer | 基础屏幕方向 |
| `Display.getRotation()` -> integer | 屏幕旋转角度 |
| `Display.update()` | 更新屏幕缓冲区 |
| `Display.initialize(width, height)` -> boolean | 初始化显示服务 |

```lua
Display.save("/sdcard/screenshot.jpg")
Display.save("/sdcard/region.png", 0, 0, 500, 500, 1, 90)
local w, h = Display.getSize()
```
