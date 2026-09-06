---
title: Native Package Managers and Explicit Migrations
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - ../development/testing.md
  - 0007-reviewed-npm-trust-policy-exception.md
---

# ADR 0008: Native Package Managers and Explicit Migrations

## Context

旧 Bootstrap 为 Homebrew 的 inventory, 版本, App detection, trust 和平台条件建立了并行模型, 并在日常安装中混入 ownership migration. 同一功能分布在清单, 入口和大型共享脚本中, 新增工具时经常需要修改流程代码. 用户批准以更直接的设计重整模块, 并允许开发工具采用 latest.

Review 同时发现 Mise global config override 不能独立排除 cwd 配置, PID lock 的创建竞态, snapshot 失败窗口和恢复路径校验不足. 这些问题需要明确边界, 而不是继续添加 package-specific 分支.

## Decision

采用 [当前架构](../architecture/bootstrap.md) 的 owner 划分和原生配置. Homebrew 使用 Brewfile, 普通安装/升级/检查由 Bundle 处理; Mise 使用原生 config 和 lockfile. Bash 3.2 只负责跨模块顺序, 声明数据校验, Git/Stow 部署和不可由原生工具保证的迁移恢复.

开发 CLI 可使用 `latest`, 日常安装使用已提交 lockfile. 版本刷新使用原生 `mise lock --global --bump`, 不在每次安装时自动更新仓库 lock. runtime 保留明确版本. ADR 0007 的 `oh-my-openagent@4.19.1` 例外保持精确, 不扩展到未来版本.

Brewfile 中的 Cask 表示 Homebrew ownership, 接受 Bundle 默认的原生 adoption. Homebrew 的判断可能依据 App bundle 版本或内容比较, 不应描述成仓库承诺的逐字节一致性. 不再提供默认 preserve 的第二套普通安装模型; 需要保持外部管理的 App 应移出 Brewfile. 不满足原生 adoption 条件时, 只有显式迁移许可加 `migrate` 命令才能替换 artifact.

公开操作调整为 `apply/check/migrate/recover`, 删除 `plan/status` 和旧 stage 名称. `check` 使用 macOS Seatbelt 阻止写入和网络访问, 因为原生查询也可能触发内部迁移. 使用系统 `lockf` 保证互斥, 保留原子状态和历史 snapshot 恢复. Package inventory 和 migration allowlist 分开, 前者定义持续管理, 后者定义一次性接管许可.

## Alternatives

继续拆分旧 reconciliation engine 可以保留 preserve 和旧接口, 但仍需同步 Homebrew 规则与自定义状态模型, 新增工具的维护成本没有根本下降.

完全只使用 Brewfile 和 Mise 最简洁, 但无法保证既有 App, 字体和旧配置接管失败后的原件恢复. 因此保留独立, 显式且按精确路径工作的 migration adapter.

## Consequences

普通资源扩展通过修改配置完成. 定制实现集中于确有数据恢复需求的边界. 兼容性代价是命令, stage 名称和 Cask 默认 ownership 语义发生变化, 迁移步骤见 runbook. 原生 Bundle 不提供整个安装过程的事务保证, 已完成资源不会因后续失败而整体撤销.

Seatbelt 是 macOS 专用系统接口; 外层受限执行环境可能禁止建立子沙箱, 此时 check 必须失败. 测试应在允许该接口的进程中运行, 使用临时 HOME 和 stub, 不解除被检查命令的只读边界.

本 ADR 替代 ADR 0001 至 0006 中的旧编排, 清单和默认自动迁移设计. 经维护者批准, 已删除这些过期 ADR 和旧 hardening 方案, 历史版本保留于 Git, 编号不复用. Bash 3.2, 精确目标, 快照保留, 失败传播和最小信任原则继续有效. ADR 0007 仍有效.

## Sources

已在 2026-09-06 对照本机 Homebrew/Mise 实现与官方资料核对:

- [Homebrew Bundle and Brewfile](https://docs.brew.sh/Brew-Bundle-and-Brewfile).
- [Mise Configuration](https://mise.jdx.dev/configuration.html).
- [Mise lock](https://mise.jdx.dev/cli/lock.html).
- [Mise startup migration implementation](https://github.com/jdx/mise/blob/main/src/migrate.rs).
- macOS 本机 `man lockf` 和 `man sandbox-exec`.
