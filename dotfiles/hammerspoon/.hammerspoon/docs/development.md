# 开发约定

## 模块边界

运行顺序固定为 `init.lua` 加载运行参数, 再加载 `keybind.lua`. 窗口操作集中在 `modules/windows.lua`. 新模块必须有独立职责和至少两个实际调用点, 否则保留在现有文件中.

所有状态默认使用 `local`. 只有 Hammerspoon 提供的 `hs` 是预期全局变量. 对 `hs.window.focusedWindow()` 等可能返回 `nil` 的调用, 必须在共享入口统一保护.

## 快捷键

应用映射和窗口映射分别保持为 table. 修改快捷键时同步根 `README.md`, 并检查 chord 是否重复. 默认使用 macOS 中的实际应用名称; 名称不是 English 时使用从应用 `Info.plist` 读取的 bundle ID.

## 验证

先启动 Hammerspoon, 再执行:

```bash
tests/run.sh
```

脚本只做 Lua 编译检查和隔离的窗口模块行为检查, 不启动应用或移动真实窗口. 通过后使用 `option+b` 重新加载, 检查 Hammerspoon Console, 再人工验证修改涉及的快捷键.

## 官方资料

以下 API 于 2026-09-15 核对:

- [hs.hotkey](https://www.hammerspoon.org/docs/hs.hotkey.html)
- [hs.application](https://www.hammerspoon.org/docs/hs.application.html)
- [hs.ipc](https://www.hammerspoon.org/docs/hs.ipc.html)
- [hs.window](https://www.hammerspoon.org/docs/hs.window.html)
