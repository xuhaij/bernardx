# 简单视觉库 API (slv) **[主引擎]**

简单的颜色和图像查找功能。

## 颜色操作

| 方法 | 说明 |
|------|------|
| `bitmap:getColor(x, y)` -> integer | 获取像素颜色 |
| `bitmap:getColorCount(x1, y1, x2, y2, color [, similarity])` -> integer | 统计颜色数量 |
| `bitmap:isColor(x, y, color [, similarity])` -> boolean | 颜色匹配 |
| `bitmap:whichColor(x, y, color [, similarity])` -> integer | 颜色匹配（1/0） |
| `bitmap:findColor(x, y, x1, y1, color [, similarity, order])` -> x, y | 查找颜色 |

```lua
local color = Display:getColor(100, 200)
local found_x, found_y = Display:findColor(0, 0, -1, -1, 0xFF0000, 0.9)
```

---

## 特征和图像查找

| 方法 | 说明 |
|------|------|
| `bitmap:isFeature(feature [, similarity])` -> boolean | 特征匹配 |
| `bitmap:findFeature(x, y, x1, y1, feature [, similarity, order])` -> x, y | 查找特征 |
| `bitmap:isImage(x, y, image [, similarity])` -> boolean | 图像匹配 |
| `bitmap:whichImage(x, y, images [, similarity])` -> integer | 多图匹配索引 |
| `bitmap:findImage(x, y, x1, y1, images [, similarity, order])` -> x, y, idx | 查找图像 |

```lua
-- 查找单个图像
local x, y, idx = Display:findImage(0, 0, -1, -1, "/sdcard/target.png", 0.9)
if x ~= -1 then tap(x, y) end

-- 查找多个图像
local x, y, idx = Display:findImage(0, 0, -1, -1, "/sdcard/a.png|/sdcard/b.png", 0.9)
```

---

## 图像操作

| 方法 | 说明 |
|------|------|
| `loadImage(path)` -> bitmap/nil | 加载图像（全局） |
| `slv.loadImage(path)` -> bitmap/nil | 加载图像 |
| `slv.saveImage(bitmap, path)` / `bitmap:save(path)` -> ok, err? | 保存 PNG |
| `slv.cloneImage(bitmap [, x1, y1, x2, y2])` / `bitmap:clone(...)` -> bitmap | 克隆/裁剪 |
| `slv.getImageSize(bitmap)` / `bitmap:getSize()` -> w, h | 获取尺寸 |

---

## 搜索顺序常量

`READ_ORDER` 或 `slv.READ_ORDER`：

| 常量 | 值 | 说明 |
|------|-----|------|
| `UP_DOWN_LEFT_RIGHT` | 1 | 从上到下，从左到右 |
| `UP_DOWN_RIGHT_LEFT` | 2 | 从上到下，从右到左 |
| `DOWN_UP_LEFT_RIGHT` | 3 | 从下到上，从左到右 |
| `DOWN_UP_RIGHT_LEFT` | 4 | 从下到上，从右到左 |
| `LEFT_RIGHT_UP_DOWN` | 5 | 从左到右，从上到下 |
| `LEFT_RIGHT_DOWN_UP` | 6 | 从左到右，从下到上 |
| `RIGHT_LEFT_UP_DOWN` | 7 | 从右到左，从上到下 |
| `RIGHT_LEFT_DOWN_UP` | 8 | 从右到左，从下到上 |
