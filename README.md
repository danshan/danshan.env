# danshan.env

个人 macOS 开发环境的 Bootstrap 和 dotfiles 仓库. Homebrew 管理主机工具, App 和字体, Mise 管理语言 runtime 与开发 CLI, Stow 部署配置.

## Get started

在受 Homebrew 支持的 macOS 上准备 Command Line Tools 和 Git, 然后执行:

```bash
git clone git@github.com:danshan/danshan.env.git "$HOME/.config/danshan.env"
cd "$HOME/.config/danshan.env"
bash install.sh check
bash install.sh apply
```

`check` 在首次安装时返回非零是正常结果, 表示资源缺失, 冲突或工具状态无法查询. 它禁止文件写入和网络访问. `apply` 按 `homebrew → shell → repositories → dotfiles → mise` 执行, 安装 fish 后将其登记并设为默认登录 Shell, 再部署 fish 配置. 任一步失败都会停止并返回非零.

Homebrew 安装按单并发下载以保持当前 artifact 的原生进度可见, 并报告各步骤的开始, 完成或失败及耗时. 重定向输出时保留实时日志, 见 [安装输出说明](docs/operations/installation.md#installation-output).

## Configuration

| 维护内容 | 配置位置 |
|---|---|
| 主机 CLI, App, 字体, 第三方包信任和平台条件 | [Brewfile](Brewfile) |
| 旧平台的固定版本 Compatibility Cask | [Casks/](Casks/) |
| runtime 和开发 CLI | [Mise config](dotfiles/mise/.config/mise/config.toml) |
| Mise 每个工具的自动更新策略 | [Mise policies](config/mise-policy.tsv) |
| 开发工具解析后的版本 | [mise.lock](dotfiles/mise/.config/mise/mise.lock) |
| Stow package, Git dependency, 附加链接, 迁移许可 | [config/](config/) |

软件可以独立选择 `latest` 或 `installed`: 前者在每次 `apply` 时更新, 后者只补装缺失资源. Homebrew 在 Brewfile 的每条声明后配置 `update_policy`, Mise 在策略表中逐行配置. 当前 Formula 和未固定版本的 Mise 开发 CLI 使用 `latest`, 多数 Cask 与固定版本工具使用 `installed`; ChatGPT 和 Muxy Cask 使用 `latest`. Mise 的 `installed` 仍要求锁文件选定版本, 其他已安装版本不能替代它. 示例和边界见 [逐软件更新策略](docs/operations/installation.md#per-package-update-policies).

Homebrew 分组策略由脚本内部传递, 无需设置 Shell 环境变量. 使用 `install.sh` 执行分组, 直接调用 `brew bundle` 不应用混合更新策略.

`config/` 每个文件头部包含完整格式和维护示例. Mise `apply` 自动刷新选中工具的锁文件, 保留 runtime pin 和 Trust Hold, 更新后应审查并提交原生 lockfile 及生成的配套文件. 需要在安装前单独审查更新时执行:

```bash
bash scripts/update_mise_lock.sh
git diff -- dotfiles/mise/.config/mise/mise.lock
bash install.sh apply --stage mise
```

Gemini CLI, OpenCode 和 Oh My OpenAgent 当前已从 Mise 管理清单停用, 对应更新策略同步停用, 锁文件不再包含它们. 重新启用 Oh My OpenAgent 时, 仍须遵守 [ADR 0007](docs/adr/0007-reviewed-npm-trust-policy-exception.md) 的精确版本与信任审查边界.

Thaw 在 macOS 14 至 25 使用固定的 1.2.0 Compatibility Cask, macOS 26 及以上使用官方当前版本. 本地 tap 读取本仓库已提交的 `Casks/` 内容; 修改 Cask 后需先提交再执行 Homebrew 阶段, 见 [兼容版本维护](docs/operations/installation.md#compatibility-casks).

`@playwright/cli` 因新版本缺少此前的发布信任证据, 固定为 `0.1.18`, 保留 Aube 信任检查, 见 [ADR 0009](docs/adr/0009-playwright-cli-trust-hold.md). Mise 阶段失败后, 修复配置并执行 `bash install.sh apply --stage mise` 可继续该阶段.

## Existing environments

Brewfile 中的 Cask 表示由 Homebrew 管理. Bundle 默认尝试原生 adoption; 不满足 Homebrew 接管条件的既有 artifact 会报错. 比较并确认 [迁移清单](config/migrations.txt) 后, 显式执行:

```bash
bash install.sh migrate
bash install.sh apply
```

`migrate` 可能替换清单中已存在的 App 或字体, 会保留原件并在失败时回滚. 中断恢复使用 `bash install.sh recover`; 日常 `apply/check` 不自动迁移或恢复. 不使用 `--force` 或自动清理未声明的软件.

更新仓库时使用 `git -C "$HOME/.config/danshan.env" pull --ff-only`, 然后重新执行 `apply`. 原 `plan/status` 命令已替换为 `check`, 原 stage 名称也已调整. `--stage NAME` 执行单个阶段, `--from NAME` 从指定阶段继续, 详见 [Installation Runbook](docs/operations/installation.md).

## Documentation

- [完整文档导航](docs/README.md).
- [项目术语](CONTEXT.md).
- [当前架构](docs/architecture/bootstrap.md).
- [开发与测试](docs/development/testing.md).
- [文档规范](docs/standards/documentation.md).
