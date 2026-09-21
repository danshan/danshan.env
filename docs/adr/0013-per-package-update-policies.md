---
title: Per-package Update Policies
status: active
owner: repository-maintainers
last_updated: 2026-09-19
related:
  - 0008-native-package-managers-and-explicit-migrations.md
  - 0007-reviewed-npm-trust-policy-exception.md
  - 0009-playwright-cli-trust-hold.md
  - ../architecture/bootstrap.md
  - ../operations/installation.md
---

# ADR 0013: Per-package Update Policies

用户要求 Formula, Cask 和 Mise 工具分别选择每次更新或仅补装. 原先 Mise 的 `latest` 只在手工刷新锁文件时重新解析, 日常 `apply` 无法表达这种逐软件意图.

采用 `latest/installed` Update Policy. Homebrew 在同一 Brewfile 的每条原生声明上使用 Ruby 条件选择策略组, Bootstrap 分组调用原生 Bundle, `installed` 组传入 `--no-upgrade`. 不维护第二份 Homebrew inventory, 不自行判断 outdated. 包级 trust, 平台条件和迁移许可语义保留.

Mise 使用独立策略表控制自动刷新, 原生 config 继续独占版本和 backend 选项. `apply` 在同一 Bootstrap 锁内验证策略工具, 只对非空 `latest` 组执行原生 `lock --global --bump`, 随后按 lockfile 安装全部声明. 未配置策略的工具默认 `installed`, 精确 pin 和 Trust Hold 始终优先. `installed` 仍要求锁定版本, 避免跳过安装后 Shell 指向不存在的版本.

这项决策仅替代 [ADR 0008](0008-native-package-managers-and-explicit-migrations.md) 中日常安装不得自动刷新 lockfile 的限制, 其余 owner, 原生状态判断, 隔离, 失败传播和显式迁移决策继续有效. 代价是选择 `latest` 的日常运行会产生需要审查提交的原生 lock 变更, 并依赖远端 metadata. `check` 继续只读离线, 不证明远端最新状态.

未采用统一的跨管理器 package 清单, 因为它会复制 Brewfile 和 Mise config 的版本, trust, 平台等原生模型. 未通过 `brew pin` 实现仅补装, 因为用户意图是限制 Bootstrap 的更新请求, 不是修改整个主机的 pin 状态或阻止依赖更新. `greedy: true` 由需要主动更新的 Cask 显式声明.

本变更只改变仓库策略与编排, 不自动执行真实软件升级. 操作和失败处理见 [Installation Runbook](../operations/installation.md#per-package-update-policies). 原生能力于 2026-09-19 对照本机 Homebrew/Mise 实现及 [Homebrew Bundle 文档](https://docs.brew.sh/Brew-Bundle-and-Brewfile), [Mise lock 文档](https://mise.jdx.dev/cli/lock.html) 核对.
