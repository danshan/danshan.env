---
title: Fish Default Login Shell
status: active
owner: repository-maintainers
last_updated: 2026-09-17
related:
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - ../development/testing.md
  - 0008-native-package-managers-and-explicit-migrations.md
---

# ADR 0012: Fish Default Login Shell

## Context

Fish 由 Homebrew 清单安装, fish dotfiles 由 Stow selector 部署. 旧流程不管理账户默认登录 Shell, 并依据 Bootstrap 启动时继承的 `SHELL` 选择 Git dependency 和 dotfile package. 因此从 Bash 或 Zsh 启动首次安装时不会部署 fish 配置; 仅在末尾调用 `chsh` 也无法改变当前进程已继承的 selector.

macOS 的 `chsh` 只接受 `/etc/shells` 中登记的 Shell. Homebrew 在 Apple Silicon 和 Intel 主机上的 prefix 不同, 因而不能固定写入单一路径.

## Decision

- Bootstrap 将 Homebrew fish 作为账户默认登录 Shell 的期望状态.
- 在 `homebrew` 与所有 Shell-specific resource 之间增加 `shell` stage. 它从当前 Homebrew 环境解析 fish 的绝对可执行路径, 不硬编码 prefix.
- `apply` 在缺少精确登记时通过 `sudo` 向 `/etc/shells` 追加路径, 再以 `chsh` 更新当前账户. 每次写入后重新读取并验证系统状态, 失败立即传播.
- 成功后更新当前 Bootstrap 进程的 `SHELL`, 使同一轮的 repository 和 dotfile selector 选择 fish. `check` 不写系统状态, 但使用期望路径继续检查下游 fish resource.
- `--stage` 和 `--from` 继续不自动补跑依赖. 操作者跳过 `shell` stage 时必须保证账户状态已经满足.

## Consequences and alternatives

首次切换可能产生两次终端认证提示. 如果后续阶段失败, 默认 Shell 已经切换而 fish 配置尚未完全收敛; fish 本体已经由前置 Homebrew stage 安装, 重新执行 `apply` 可幂等继续. Bootstrap 不自动回滚账户 Shell, 因为回滚会重新引入 selector 不一致, 且后续失败不撤销已成功的普通阶段.

把切换合并进 Homebrew stage 会混淆 package ownership 与账户配置. 把切换放入 dotfiles stage 则发生得太晚, repository selector 已按旧 Shell 执行. 仅输出人工命令无法保证期望状态和阶段顺序, 因此均不采用.

## Verification

隔离测试以 stub 覆盖未登记, 已登记, 旧默认 Shell, 当前 fish, 注册失败和 `chsh` 失败. 完整入口测试验证 `shell` 位于 Homebrew 之后和配置阶段之前, 重复执行保持幂等, `check` 不写临时 HOME, 失败不会输出整体完成提示.
