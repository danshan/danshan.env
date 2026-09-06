---
title: Bootstrap Architecture
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../design/bootstrap-hardening.md
  - ../adr/0001-bash-bootstrap-and-state-reconciliation.md
  - ../adr/0002-transactional-homebrew-font-migration.md
  - ../adr/0003-platform-gated-homebrew-casks.md
  - ../adr/0004-transactional-homebrew-app-migration.md
  - ../adr/0005-homebrew-and-mise-tool-ownership.md
  - ../adr/0006-recoverable-bootstrap-execution.md
  - ../adr/0007-reviewed-npm-trust-policy-exception.md
  - ../operations/installation.md
---

# Bootstrap Architecture

## Scope

本项目将 macOS 开发环境描述为三个可收敛层次: Homebrew system package 和 Cask, repository-managed dotfiles, 以及 Mise runtime 和固定版本的 global CLI. `install.sh` 是唯一完整入口. Bun 和 NPM 只属于具体项目的 dependency boundary.

## Components

| Component | Responsibility |
|---|---|
| `install.sh` | Mode 和 stage selection, 固定顺序, 隔离子进程, 传播失败, elapsed summary |
| `scripts/preflight.sh` | 在 mutation 前验证平台, manifest, Shell, Mise 配置来源和既有 Zed repository identity |
| `scripts/common.sh` | 加载 shared library, 提供 Homebrew reconciliation facade |
| `scripts/lib/*.sh` | Core logging, manifest validation, Git, runtime 和 migration state primitives |
| `scripts/setup_homebrew.sh` | Homebrew Bootstrap 和单次 metadata refresh |
| `scripts/setup_brew_trust.sh` | 第三方 Formula/Cask 的 exact package trust 收敛 |
| `scripts/install_brew_pkgs.sh` | Formula inventory 和三态收敛 |
| `scripts/install_brew_casks.sh` | Cask inventory, missing font migration batch 和三态收敛 |
| `scripts/setup_shell.sh` | 固定 revision 的 Oh My Zsh 和 oh-my-tmux |
| `scripts/setup_dotfiles.sh` | Stow package 和 Zed config repository |
| `scripts/setup_devenv.sh` | Mise runtime 和固定版本的全局 CLI |
| `defaults/brew_*.txt` | Homebrew Desired State 和 trust manifest |
| `defaults/dotfile_pkgs.txt` | Stow package Desired State |
| `defaults/tool_versions.env` | Remote Bootstrap 和 pinned Git dependency revisions |
| `dotfiles/mise/.config/mise/config.toml` | Runtime 和 global CLI Desired State |
| `dotfiles/mise/.config/mise/mise.lock` | 支持 backend 的 platform URL 与 checksum lock |

## Execution flow

Preflight 总是先执行. 后续阶段顺序为 `base`, `homebrew`, `trust`, `formulae`, `casks`, `shell`, `dotfiles`, `devenv`. `apply` 执行 reconciliation, `plan` 展示预计动作, `status` 读取当前状态. `--stage` 选择单一阶段, `--from` 从指定阶段继续; 两者不改变 preflight 要求.

每个阶段由顶层通过新的 Bash 进程启动. 阶段不得依赖前一个进程导出的 PATH, 当前目录或 Shell function. `activate_homebrew` 和 Mise activation 因此在需要它们的阶段中显式执行. Homebrew activation 固定请求 Bash 格式的 `shellenv`, 不受调用者登录 Shell 为 Fish 或 Zsh 的影响.

旧 Bootstrap 直接写入的 `~/.config/mise/config.toml` 是 Stow ownership transition 的唯一自动兼容入口. 只有当既有文件仅包含 `[tools]`, 且每个 key/version 都是 repository config 的子集时才允许迁移. 原文件先进入 `${HOME}/Library/Application Support/danshan.env/dotfile-backups`, 随后执行 Stow 并验证 target symlink 与内容. Failure 会删除本 package 创建的链接并恢复原文件; unrecognized content 保持普通 conflict 并 fail closed.

Homebrew metadata 只在 `setup_homebrew.sh` 刷新一次. `setup_brew_trust.sh` 随后读取一次 JSON trust state, 并且只为 `defaults/brew_trust.txt` 中缺失的 exact Formula/Cask grant 执行 `brew trust`. Formula 和 Cask inventory 在 trust 收敛后执行, 分别读取一次 installed inventory 和一次 outdated inventory. Cask stage 额外读取一次 `sw_vers -productVersion`, 将 major 保存为本次执行稳定的 platform Observed State. 普通 manifest reconciliation 不执行逐项 `brew info`; 只有 missing 且显式声明 `migrate` 的 font cask 会读取 JSON metadata, 以得到权威 artifact target.

`defaults/brew_casks.txt` 的字段依次是 package, App name, existing artifact policy 和 optional minimum macOS major. 第四列必须为空或正整数. 不满足 Platform Constraint 的 Cask 在 ownership 和 outdated classification 之前明确 skip, 因而不会 install, upgrade 或进入 migration. 默认 `preserve` 只在声明了 App 名称且 `/Applications` 中存在对应 bundle 时跳过. `adopt` 对 missing App cask 执行 `brew install --cask --adopt`, 且只接管内容相同的 artifact. `migrate` 根据 App name 分流: 非空时执行单 Cask App transaction, 为空时执行 font batch transaction.

## Application migration transaction

Missing Cask 声明 App name 与 `migrate`, 且精确 `/Applications/<name>.app` target 已存在时, Bootstrap 在 `${HOME}/Library/Application Support/danshan.env/app-backups` 创建唯一 Migration Snapshot. 原 bundle 先移动到 `originals`, 随后执行普通 `brew install --cask`, 并验证 Homebrew inventory 与 App target directory. 成功后 snapshot 标记为 `completed` 并持续保留.

Install 或 verify 失败时, Rollback 卸载本 transaction 已登记的 Cask, 把新 target 隔离到 `failed-install-artifact`, 再恢复 original bundle. 完整恢复写入 `rolled-back`; 任一步无法恢复写入 `rollback-incomplete` 并停止 Bootstrap. App target 不存在时不需要 ownership transition, 直接走普通 missing install. 已由 Homebrew 管理的 current 或 outdated Cask 仍分别 skip 或 upgrade, 不重复 migration.

## Font migration transaction

满足 Platform Constraint 的 missing `migrate` cask 在普通 reconciliation 之前统一处理. Bootstrap 从 `brew info --cask --json=v2` 读取全部 artifact, 要求每项都是 `${HOME}/Library/Fonts` 的直接 `.ttf` 或 `.otf` target. 通过 preflight 后, 当前存在的精确 target 被移动到 `${HOME}/Library/Application Support/danshan.env/font-backups/<timestamp>-<pid>/originals`, 完整 target 和初始 presence 写入 `manifest.txt`.

全部 missing font cask 作为一个 batch 安装. Verify 同时要求 Homebrew inventory 登记成功和每个 target 为 regular file. 全部通过后写入 `state=completed`, 将 cask 加入当前进程的 reconciled set 并准确增加 install count. 任一 snapshot, install 或 verify 失败时, Rollback 卸载本批次已登记的 cask, 将残留新字体移动到 `failed-install-artifacts`, 恢复 original snapshot, 并写入 `rolled-back` 或 `rollback-incomplete`. 成功 snapshot 不自动删除.

## Migration serialization and recovery

Cask stage 在 inspect migration state 前获取 `${HOME}/Library/Application Support/danshan.env/locks/cask-migration.lock`. Lock 中只保存 PID. 活跃 PID 阻止并发执行; 已退出 PID 对应的精确 lock 可以移除; 结构异常的 lock fail closed. Trap 在正常或异常退出时只释放当前进程拥有的 lock.

Migration state 通过同目录 temporary file 和 atomic rename 更新. 新 transaction 开始前扫描 App, font 和 Stow ownership snapshot. 已知 non-terminal state 沿用对应 transaction 的 Rollback 或完成验证. `completed` 和 `rolled-back` 是终态; `rollback-incomplete` 和未知 state 必须停止 Bootstrap, 由操作者检查 snapshot.

引入 state marker 之前创建的 font snapshot 使用三列 legacy manifest. 无 `state` 的目录只有在每个 target, backup path, retained original 和 Homebrew Cask ownership 全部验证通过时才能分类为历史已完成 snapshot, 且不会被改写. 无法证明完整性的 stateless snapshot 继续 fail closed.

## State ownership

- Homebrew 是 Formula 和 Cask installation state 的事实源.
- Manifest App name 是 App migration 精确 target 的事实源; Homebrew JSON metadata 是 font migration 精确 target 的事实源; Migration Snapshot 是迁移前内容和恢复关系的事实源.
- `defaults/brew_trust.txt` 是第三方 Homebrew package trust 的显式 allowlist. 不从 package manifest 自动推导授权.
- 本仓库是 Neovim 和其他 stow package 的事实源.
- `~/.config/zed` 是独立 Git repository, 仅允许从预期 origin fast-forward.
- Oh My Zsh 和 oh-my-tmux 使用 `defaults/tool_versions.env` 中的固定 commit.
- Stow 安装到 `~/.config/mise/config.toml` 的 repository config 是 runtime 和 global CLI 的事实源, 不读取调用目录的 `mise.toml`.
- Mise 是这些工具的唯一 Tool Owner. Aqua 和 NPM 仅作为 Mise Installation Backend; 不允许直接执行 Bun 或 NPM global install.
- Mise lock 对 Aqua 等支持的 backend 固定 platform artifact 和 checksum. NPM backend 仍由精确 package version 与 registry integrity 共同约束.
- Aube trust-policy exception 必须绑定到单一 top-level tool 和精确 transitive package version, 并由 ADR 保存 publisher, repository, provenance, commit 和 digest review evidence. 不允许 bare package exception 或全局 installer bypass.

## Failure semantics

所有阶段启用 strict mode. 缺失依赖, network failure, dirty pinned dependency repository, unexpected Git origin, stow conflict, unrecoverable migration 或 package manager failure 都会阻止后续阶段和最终完成提示. 失败消息包含 stage 和 exit code. Zed 是 tracking repository: dirty worktree 被保留并跳过 remote update, 不阻止其他 Managed Resource 收敛.

安装过程不自动覆盖普通文件, 不使用 `stow --adopt`, 不自动处理 dirty Git worktree. 唯一自动 dotfile transition 是可证明由旧 Bootstrap 生成且被新 Desired State 完整包含的 Mise config; 其他冲突需要操作者确认所有权.

## Security boundaries

- 唯一的远程 Shell Bootstrap 是固定 commit 的 Homebrew 官方 installer. 脚本先下载到独立临时目录, 再执行本地文件.
- 其他系统工具和 App 通过 Homebrew 安装. Runtime 与 global CLI 通过 Mise 固定版本安装, JavaScript CLI 由 Mise NPM backend 解析精确 package version.
- 第三方 Homebrew source 只获得 exact Formula/Cask trust. Bootstrap 不信任整个 tap, 也不关闭 trust checks.
- Machine-local secrets 不属于 repository state, 只能存入被忽略的 local 文件或外部 secret manager.
- Git 历史重写不属于 Bootstrap 行为.
