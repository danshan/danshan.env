---
title: Bootstrap Architecture
status: active
owner: repository-maintainers
last_updated: 2026-09-04
related:
  - ../design/bootstrap-hardening.md
  - ../adr/0001-bash-bootstrap-and-state-reconciliation.md
  - ../operations/installation.md
---

# Bootstrap Architecture

## Scope

本项目将 macOS 开发环境描述为三个可收敛层次: Homebrew package, repository-managed dotfiles, 以及 mise runtime 和全局 CLI. `install.sh` 是唯一完整入口.

## Components

| Component | Responsibility |
|---|---|
| `install.sh` | 固定阶段顺序, 隔离子进程, 传播失败, 最终成功输出 |
| `scripts/common.sh` | 日志, Homebrew activation, package reconciliation, Git 和 symlink 安全辅助函数 |
| `scripts/setup_homebrew.sh` | Homebrew Bootstrap 和单次 metadata refresh |
| `scripts/setup_brew_trust.sh` | 第三方 Formula/Cask 的 exact package trust 收敛 |
| `scripts/install_brew_pkgs.sh` | Formula inventory 和三态收敛 |
| `scripts/install_brew_casks.sh` | Cask inventory 和三态收敛 |
| `scripts/setup_shell.sh` | 固定 revision 的 Oh My Zsh 和 oh-my-tmux |
| `scripts/setup_dotfiles.sh` | Stow package 和 Zed config repository |
| `scripts/setup_devenv.sh` | Mise runtime 和固定版本的全局 CLI |
| `defaults/*.txt` | Homebrew desired state manifests |
| `defaults/tool_versions.env` | Runtime, Git dependency 和 CLI version pins |

## Execution flow

每个阶段由顶层通过新的 Bash 进程启动. 阶段不得依赖前一个进程导出的 PATH, 当前目录或 Shell function. `activate_homebrew` 和 mise activation 因此在需要它们的阶段中显式执行. Homebrew activation 固定请求 Bash 格式的 `shellenv`, 不受调用者登录 Shell 为 Fish 或 Zsh 的影响.

Homebrew metadata 只在 `setup_homebrew.sh` 刷新一次. `setup_brew_trust.sh` 随后读取一次 JSON trust state, 并且只为 `defaults/brew_trust.txt` 中缺失的 exact Formula/Cask grant 执行 `brew trust`. Formula 和 Cask inventory 在 trust 收敛后执行, 分别读取一次 installed inventory 和一次 outdated inventory. Manifest reconciliation 不执行逐项 `brew info`.

## State ownership

- Homebrew 是 Formula 和 Cask installation state 的事实源.
- `defaults/brew_trust.txt` 是第三方 Homebrew package trust 的显式 allowlist. 不从 package manifest 自动推导授权.
- 本仓库是 Neovim 和其他 stow package 的事实源.
- `~/.config/zed` 是独立 Git repository, 仅允许从预期 origin fast-forward.
- Oh My Zsh 和 oh-my-tmux 使用 `defaults/tool_versions.env` 中的固定 commit.
- Mise global config 是语言 runtime 的事实源, 安装脚本不会修改调用目录的 `mise.toml`.
- Bun global package metadata 用于判断固定版本是否已经满足.

## Failure semantics

所有阶段启用 strict mode. 缺失依赖, network failure, dirty pinned repository, unexpected Git origin, stow conflict 或 package manager failure 都会阻止后续阶段和最终完成提示.

安装过程不自动覆盖普通文件, 不自动采用现有 dotfile, 不自动处理 dirty Git worktree. 这些状态需要操作者先确认所有权并解决冲突.

## Security boundaries

- 唯一的远程 Shell Bootstrap 是固定 commit 的 Homebrew 官方 installer. 脚本先下载到独立临时目录, 再执行本地文件.
- 其他系统工具通过 Homebrew 安装, runtime 通过 mise 固定版本安装, JavaScript CLI 使用精确 package version.
- 第三方 Homebrew source 只获得 exact Formula/Cask trust. Bootstrap 不信任整个 tap, 也不关闭 trust checks.
- Machine-local secrets 不属于 repository state, 只能存入被忽略的 local 文件或外部 secret manager.
- Git 历史重写不属于 Bootstrap 行为.
