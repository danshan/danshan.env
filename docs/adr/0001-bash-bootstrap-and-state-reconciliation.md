---
title: Bash Bootstrap and State Reconciliation
status: active
owner: repository-maintainers
last_updated: 2026-09-03
related:
  - ../design/bootstrap-hardening.md
  - ../architecture/bootstrap.md
---

# ADR 0001: Bash Bootstrap and State Reconciliation

## Context

原安装入口混合 Zsh, Bash 和 `sh` 语义, 通过 `source` 共享隐式状态, 并无条件重复执行 package installation. 失败可能被后续成功命令覆盖, 新机器和已配置机器的行为也不一致.

## Decision

- Bootstrap 统一使用 macOS 自带 Bash 3.2 可支持的语法.
- 顶层以独立子进程运行 Bootstrap Stage, 各 Stage 自行建立 Homebrew 和 mise 环境.
- Managed Resource 使用 inspect, classify, reconcile, verify 模型.
- Homebrew 使用批量 Observed State inventory, Satisfied Resource 明确跳过.
- Homebrew 管理的系统 package 跟随 metadata, runtime 和 global CLI 使用 repository-managed Mise config 固定.
- Git repository update 使用显式 `git -C` 和 `--ff-only`.

## Consequences

优点:

- Bootstrap Stage 失败不会被掩盖, 重复执行成本显著降低.
- 不再依赖调用者 Shell 类型, 当前目录或已加载的 profile.
- 测试可以通过 stub executable 隔离每个 Stage.

代价:

- Bash 3.2 限制了 associative array 和 nameref 等新语法, 状态集合需要兼容实现.
- Homebrew metadata refresh 仍可能访问网络, 但每次完整执行最多集中刷新一次.
- 固定 CLI version 需要维护者显式升级 manifest.

## Alternatives considered

### POSIX sh

可移植性更高, 但数组和可靠的测试辅助逻辑更复杂. 项目本身面向 macOS, 收益不足以抵消维护成本.

### Zsh

与主要交互 Shell 一致, 但 Homebrew 安装前不应假设用户默认 Shell 或配置状态. Bash 3.2 在目标系统上具有更稳定的 Bootstrap 基线.

### Unconditional brew install

实现最短, 但会重复解析和尝试升级 Satisfied Resource, 日志无法区分 Observed State, 不符合 reconciliation 和执行效率要求.
