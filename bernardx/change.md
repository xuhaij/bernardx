# Windows 兼容性修改记录

## 1. CMakeLists.txt:139 — `dl` 库链接添加平台判断 ✅

**问题**：`bernardx_lib` 链接 `dl`（libdl）时未用 `if(UNIX)` 保护。Windows 不存在 libdl，CMake 配置阶段直接报错。

**修改**：将 `dl` 移入 `if(UNIX)` 块。

---

## 2. 3rd/ 子模块初始化 ✅

**问题**：`3rd/` 目录下的子模块为空，导致 CMake 找不到第三方依赖源码。

**修改**：通过 `git submodule update --init --recursive` 拉取所有子模块。

---

## 3. lua_runtime.cc:165 — 绝对路径判断支持 Windows ✅

**问题**：`custom_loadfile` 中仅通过 `filename[0] == '/'` 判断绝对路径，不识别 Windows 的 `C:\...` 和 `\\server\...` 格式。

**修改**：增加 Windows 绝对路径的判断逻辑（盘符 `X:\` / `X:/` 和 UNC `\\`）。

---

## 4. OpenSSL + vcpkg 环境搭建 ✅

**问题**：Windows 无系统级 OpenSSL，`ENABLE_SSL=ON` 时 CMake 找不到 OpenSSL。

**修改**：通过 vcpkg 安装 OpenSSL。

```bash
# 安装 vcpkg（一次性）
git clone https://github.com/Microsoft/vcpkg.git C:/vcpkg
cd C:/vcpkg && ./bootstrap-vcpkg.bat

# 安装 OpenSSL
C:/vcpkg/vcpkg install openssl:x64-windows
```

**配置命令**：
```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake -DBERNARDX_BUILD_EXECUTABLE=ON -DENABLE_SSL=ON
cmake --build build
```

---

## 5. VS Code IntelliSense 找不到 gflags/gflags.h ✅

**问题**：gflags 头文件在 CMake configure 时生成到 `build/3rd/gflags/include/`，VS Code 不知道这个路径。

**修改**：创建 `.vscode/c_cpp_properties.json`，添加所有必要的 includePath（含 build 目录下的 gflags 路径）。

