# 系统、守护进程与 UI 服务 API **[主引擎]**

---

## System

| 方法 | 说明 |
|------|------|
| `System.startService(pkg, service [, action, isForeground])` | 启动服务 |
| `System.getPackageName()` -> string/nil | 当前前台包名 |
| `System.getActivity()` -> string/nil | 当前前台 Activity |
| `System.scanFile(path)` | 扫描媒体文件 |
| `System.getClipboardText()` -> string/nil | 获取剪贴板 |
| `System.setClipboardText(text)` | 设置剪贴板 |

---

## Guardian

| 方法 | 说明 |
|------|------|
| `Guardian.start()` | 启动守护进程 |
| `Guardian.stop()` | 停止守护进程 |
| `Guardian.version()` -> integer | 版本号 |
| `Guardian.upgradeEngine(url, pkg, service_name)` | 升级引擎 |

---

## SUI

### Toast 和日志

- `SUI.toast(message)` — 显示 Toast
- `SUI.showLogView()` / `SUI.hideLogView()` / `SUI.logViewIsShow()` -> boolean
- `SUI.moveLogView(x, y)` / `SUI.resetLogViewSize(width, height)` / `SUI.setLogViewTitle(title)`
- `SUI.log(level, message)` — 推送日志到视图

### 闪烁提示

- `SUI.startGlint(interval)` / `SUI.stopGlint()`

### 对话框

- `SUI.showDialog(title, message [, timeout, buttons])` -> integer — 返回按钮索引（1-based），超时返回 0
- `SUI.dismissDialog()`
- `SUI.setDialogConfig(config)` — 配置 `{x, y, width, height, msgFontSize, titleFontSize, btnFontSize}`

```lua
local result = SUI.showDialog("确认", "是否继续？", -1, {"取消", "确定"})
if result == 2 then logi("confirmed") end
```

---

## 其他

### exit([stopGuardian])

退出脚本。`stopGuardian` 为 true 时同时停止守护进程。

```lua
exit()
exit(true)
```
