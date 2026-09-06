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

`check` 在首次安装时返回非零是正常结果, 表示资源缺失, 冲突或工具状态无法查询. 它禁止文件写入和网络访问. `apply` 按 `homebrew → repositories → dotfiles → mise` 执行, 任一步失败都会停止并返回非零.

Homebrew 安装默认实时显示原生输出, 并报告各步骤的开始, 完成或失败及耗时. 终端内的下载进度由 Homebrew 原生呈现, 重定向输出时保留实时日志, 见 [安装输出说明](docs/operations/installation.md#installation-output).

## Configuration

| 维护内容 | 配置位置 |
|---|---|
| 主机 CLI, App, 字体, 第三方包信任和平台条件 | [Brewfile](Brewfile) |
| runtime 和开发 CLI | [Mise config](dotfiles/mise/.config/mise/config.toml) |
| 开发工具解析后的版本 | [mise.lock](dotfiles/mise/.config/mise/mise.lock) |
| Stow package, Git dependency, 附加链接, 迁移许可 | [config/](config/) |

`config/` 每个文件的头部包含完整格式和维护示例. 开发 CLI 默认允许 `latest`, runtime 保留明确版本. 日常安装使用锁文件, 刷新开发工具版本时执行:

```bash
bash scripts/update_mise_lock.sh
git diff -- dotfiles/mise/.config/mise/mise.lock
bash install.sh apply --stage mise
```

`oh-my-openagent` 当前保留与信任审查绑定的精确版本, 见 [ADR 0007](docs/adr/0007-reviewed-npm-trust-policy-exception.md).

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
