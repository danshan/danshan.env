:     # hammerspoon-config

> Spectacle Window Manager Keybindings For Hammerspoon

Hammerspoon-config is an easily configurable and extendible Hammerspoon package that implements all of the Spectacle keybindings.

## Installation and updates

此目录由本仓库的 Stow package 管理, Hammerspoon 应用由根目录 `Brewfile` 管理. 在仓库根目录执行:

```bash
bash install.sh apply
```

完成后, 在 Hammerspoon 菜单中选择 Reload Config. 修改快捷键后再次 Reload Config 即可. 配置随本仓库更新, 不再把 `~/.hammerspoon` 作为独立 Git 仓库更新. 旧独立 checkout 会被 Stow 识别为冲突, 需先比较并保留其本地改动.

## Default Keybindings

Hammerspoon-config comes with a set of default keybindings. See installation for more on altering and disabling default keybindings.

* Application Launcher

| Application Name | Chord | Activator |
| -----------------|:-----:|:---------:|
| `iTerm` | <kbd>⌥</kbd> | <kbd>~</kbd> |
| `Notion` | <kbd>⌥</kbd> | <kbd>,</kbd> |
| `Postman` | <kbd>⌥</kbd> | <kbd>.</kbd> |
| `Finder` | <kbd>⌥</kbd> | <kbd>/</kbd> |
| `Preview` | <kbd>⌥</kbd> | <kbd>;</kbd> |
| `Microsoft Edge` | <kbd>⌥</kbd> | <kbd>1</kbd> |
| `Safari` | <kbd>⌥</kbd> | <kbd>2</kbd> |
| `Feishu / Lark` | <kbd>⌥</kbd> | <kbd>3</kbd> |
| `WeChat` | <kbd>⌥</kbd> | <kbd>4</kbd> |
| `iStatistica Pro` | <kbd>⌥</kbd> | <kbd>A</kbd> |
| `WebStome` | <kbd>⌥</kbd> | <kbd>D</kbd> |
| `Sublime Text` | <kbd>⌥</kbd> | <kbd>E</kbd> |
| `Telegram` | <kbd>⌥</kbd> | <kbd>N</kbd> |
| `Reminders` | <kbd>⌥</kbd> | <kbd>R</kbd> |
| `IntelliJ IDEA` | <kbd>⌥</kbd> | <kbd>S</kbd> |
| `Tweetbot` | <kbd>⌥</kbd> | <kbd>T</kbd> |
| `Visual Studio` | <kbd>⌥</kbd> | <kbd>V</kbd> |
| `Strongbox` | <kbd>⌥</kbd> | <kbd>W</kbd> |

* Relead hammerspoon config

| Action | Chord | Activator |
| -----------------|:-----:|:---------:|
| Reload config | <kbd>⌥</kbd> | <kbd>B</kbd> |


* Window Resize

| Action | Chord | Activator |
| -----------------|:-----:|:---------:|
| `maximize` | <kbd>⌥</kbd> <kbd>⌘</kbd> | <kbd>M</kbd> |
| `smaller` | <kbd>⌥</kbd> <kbd>⌘</kbd> | <kbd>-</kbd> |
| `larger` | <kbd>⌥</kbd> <kbd>⌘</kbd> | <kbd>=</kbd> |
| `left half` | <kbd>⌥</kbd> <kbd>⌘</kbd> | <kbd>←</kbd> |
| `right half` | <kbd>⌥</kbd> <kbd>⌘</kbd> | <kbd>→</kbd> |
| `up half` | <kbd>⌥</kbd> <kbd>⌘</kbd> | <kbd>↑</kbd> |
| `down half` | <kbd>⌥</kbd> <kbd>⌘</kbd> | <kbd>↓</kbd> |

* Window Movement

| Application Name | Chord | Activator |
| -----------------|:-----:|:---------:|
| move to the `left` screen | <kbd>⌥</kbd><kbd>⌃</kbd> | <kbd>H</kbd> |
| move to the `right` screen | <kbd>⌥</kbd><kbd>⌃</kbd> | <kbd>L</kbd> |
| move to the `up` screen | <kbd>⌥</kbd><kbd>⌃</kbd> | <kbd>K</kbd> |
| move to the `down` screen | <kbd>⌥</kbd><kbd>⌃</kbd> | <kbd>J</kbd> |

## Contribution

Feel free to submit an issue/feature request/pull request.
