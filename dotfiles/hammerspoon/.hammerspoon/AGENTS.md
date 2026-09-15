# Repository Instructions

## Scope

本文件适用于当前 Hammerspoon 配置目录. 上层仓库规则继续生效.

## Architecture

- `init.lua` 是唯一运行入口, 只负责全局设置, 模块加载和加载成功提示.
- `keybind.lua` 只负责快捷键声明与绑定.
- 可复用行为放在 `modules/`, 每个模块返回局部 table, 不创建隐式全局变量.
- `Spoons/` 只存放明确选择的第三方 Spoon. 不提交自动下载产物.

## Lua conventions

- Code, comments, identifiers, log messages, and alerts use English.
- Prefer local variables and standard Lua control flow. Do not add a dependency for a small helper.
- Guard Hammerspoon APIs that may return `nil`, especially focused windows and application lookup.
- Keep hotkey declarations data-driven. Do not bind the same chord in multiple files.
- Do not add watchers or timers unless the behavior requires them. Retain long-lived objects and stop them during reload when they are introduced.

## Documentation

- 中文正文使用 English punctuation, 并在中英文之间保留空格. Code blocks remain English-only.
- 根 `README.md` 只保留使用方式, 快捷键和文档入口.
- 详细说明放在 `docs/`, 文件名使用 lowercase kebab-case. 新文档必须登记到 `docs/README.md`.
- API 结论链接到 Hammerspoon 官方文档, 并注明核对日期.

## Verification

- 修改 Lua 后运行 `tests/run.sh`.
- 行为变更后重新加载 Hammerspoon, 检查 Console 无错误, 并人工验证受影响快捷键.
- 不在测试中启动应用, 移动真实窗口或修改用户环境.
