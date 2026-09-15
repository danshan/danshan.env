# Context

## Terms

- Config root: `~/.hammerspoon` 指向的本目录.
- Entry point: Hammerspoon 自动加载的 `init.lua`.
- Application hotkey: 使用 `option` 启动或聚焦应用的快捷键.
- Window hotkey: 调整窗口 frame 或跨 screen 移动窗口的快捷键.
- Unit rect: Hammerspoon 使用 `x`, `y`, `w`, `h` 表示的屏幕相对矩形.

## Boundaries

配置只管理快捷键和窗口行为. 自动布局, URL event 和第三方 Spoon 当前不属于运行范围.
