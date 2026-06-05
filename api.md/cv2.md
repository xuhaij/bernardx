# 计算机视觉 API (cv2) **[主引擎]**

基于 OpenCV 的计算机视觉功能。

## 图像操作

| 方法 | 说明 |
|------|------|
| `cv2.bitmap2Mat(bitmap [, x, y, x1, y1])` -> mat | Bitmap 转 Mat |
| `cv2.cvtColor(mat [, code, out])` -> mat | 颜色空间转换 |
| `cv2.threshold(mat [, thresh, maxval, type, out])` -> mat | 二值化 |
| `cv2.findContours(mat [, mode, method])` -> contours | 轮廓检测 |
| `cv2.matchShapes(contour, contours [, method, parameter])` -> table | 形状匹配 |
| `cv2.boundingRect(contour)` -> x, y, w, h | 外接矩形 |
| `cv2.loadContour(path)` -> contour | 加载轮廓 |
| `cv2.resize(mat, w, h)` / `cv2.resize(mat, fx, fy)` -> mat | 缩放 |
| `cv2.matchTemplate(mat, template [, method, mask])` -> maxVal, x, y | 模板匹配 |
| `cv2.imread(path [, flags])` -> mat | 读取图像 |
| `cv2.inRange(mat, lower, upper [, out])` -> mat | 颜色范围过滤 |

---

## CvMat 对象

| 方法 | 说明 |
|------|------|
| `mat:clone()` -> mat | 克隆图像 |
| `mat:save(path)` | 保存图像 |
| `mat:release()` | 释放内存 |
| `mat:size()` -> width, height | 获取尺寸 |
| `mat:crop(x, y, w, h)` -> mat | 裁剪图像 |

## CvContours 对象

| 方法 | 说明 |
|------|------|
| `#contours` -> integer | 轮廓数量 |
| `contours:at(index)` -> contour | 获取指定索引的轮廓 |

## CvContour 对象

| 方法 | 说明 |
|------|------|
| `#contour` -> integer | 点数量 |
| `contour:at(index)` -> x, y | 获取指定索引的点 |

---

## 常量

```lua
-- 颜色转换
cv2.COLOR_BGR2GRAY

-- 轮廓检索模式
cv2.RETR_EXTERNAL
cv2.RETR_TREE

-- 轮廓近似方法
cv2.CHAIN_APPROX_SIMPLE

-- 轮廓匹配方法
cv2.CONTOURS_MATCH_I1

-- 阈值类型
cv2.THRESH_BINARY
cv2.THRESH_BINARY_INV
cv2.THRESH_OTSU

-- 模板匹配方法
cv2.TM_CCOEFF_NORMED

-- 图像读取标志
cv2.IMREAD_COLOR_BGR
cv2.IMREAD_GRAYSCALE
```

---

## 示例

```lua
-- 模板匹配
local screen = cv2.bitmap2Mat(Display)
local tpl = cv2.imread("/sdcard/target.png")
local maxVal, x, y = cv2.matchTemplate(screen, tpl)
if maxVal > 0.9 then
    tap(x + tpl:size() / 2, y + tpl:size() / 2)
end
screen:release()
tpl:release()
```
