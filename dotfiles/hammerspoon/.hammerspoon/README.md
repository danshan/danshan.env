# Hammerspoon Configuration

这是 Honghao 的个人 Hammerspoon 配置. 当前代码由 [danshan/hammerspoon-config](https://github.com/danshan/hammerspoon-config) 的 `56f95bf` 版本迁入, 并在本仓库中维护.

## 使用

前置条件是已安装并启动 [Hammerspoon](https://www.hammerspoon.org/), 且 `~/.hammerspoon` 指向本目录. 修改配置后, 使用 `option+b` 重新加载.

窗口快捷键如下.

| 操作 | 快捷键 |
| --- | --- |
| 最大化 | `option+shift+m` |
| 左半屏 | `option+shift+left` 或 `option+shift+h` |
| 右半屏 | `option+shift+right` 或 `option+shift+l` |
| 上半屏 | `option+shift+up` 或 `option+shift+k` |
| 下半屏 | `option+shift+down` 或 `option+shift+j` |
| 缩小 | `option+shift+-` |
| 放大 | `option+shift+=` |
| 移到相邻屏幕 | `option+control+h/j/k/l` |

应用启动快捷键统一使用 `option`, 映射集中在 `keybind.lua` 中维护.

## 开发

- `init.lua`: Hammerspoon 唯一入口和全局运行参数.
- `keybind.lua`: 应用与窗口快捷键声明.
- `modules/windows.lua`: 窗口操作及无聚焦窗口保护.
- `tests/run.sh`: 通过 `hs.ipc` 使用正在运行的 Hammerspoon 执行语法与行为检查.
- `docs/`: 架构, 开发和文档约定.

运行检查:

```bash
tests/run.sh
```

文档入口见 [docs/README.md](docs/README.md). Hammerspoon API 以 [官方文档](https://www.hammerspoon.org/docs/) 为准.
