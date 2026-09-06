---
title: Recoverable Bootstrap Execution
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../design/bootstrap-hardening.md
  - ../operations/installation.md
  - 0002-transactional-homebrew-font-migration.md
  - 0004-transactional-homebrew-app-migration.md
---

# ADR 0006: Recoverable Bootstrap Execution

## Context

Fail-fast 可以处理 command failure, 但无法处理进程在移动 original artifact 后被 signal, crash 或终端退出中断. 仅有 Rollback function 不足以保证下次执行能够识别 non-terminal snapshot. 同时运行两个 Cask stage 还可能操作同一 App, font target 或 backup state.

完整 Bootstrap 缺少无 mutation 的 preflight, plan 和 status boundary, 使操作者只能通过实际 apply 发现 manifest 或 stage selection 问题.

## Decision

- 顶层在任何 mutable Stage 前执行 preflight, 验证 host, manifests, login Shell 和 Mise config source.
- 提供 `apply`, `plan` 和 `status` mode. 后两者不得修改 Managed State.
- 提供 `--stage` 与 `--from` 选择执行边界, preflight 始终保留.
- Cask migration 使用 PID-based Migration Lock 串行化. Live owner 阻止并发, exact stale lock 可以恢复, malformed lock fail closed.
- Migration state 使用 same-directory temporary file 和 atomic rename 写入.
- 新 transaction 前扫描 snapshot. 已知 non-terminal state 自动进入既有 Rollback; terminal state 不重复处理.
- 无 state marker 的 legacy font snapshot 只有在三列 manifest, exact target, retained backup 和 Homebrew ownership 全部验证通过时才分类为历史完成状态, 且不改写 snapshot.
- `rollback-incomplete` 与 unknown state 必须停止, 不允许猜测恢复动作.
- 顶层错误报告包含 Stage 和 exit code, 只有全部 Stage 成功时才输出完成提示.

## Consequences

优点:

- 可在 mutation 前发现 invalid Desired State, 并预览预计动作.
- Crash 或 signal 后的下一次执行能够恢复已知 migration phase.
- 并发 Bootstrap 不会同时改变同一 Cask ownership boundary.
- Stage-level timing 和 error context 缩短故障定位路径.

代价:

- State machine, lock ownership 和 recovery path 增加实现与测试复杂度.
- `status` 反映当前 local metadata, 不主动刷新 Homebrew, 因而不承诺远端 latest status.
- Unknown or manually modified snapshot 会 fail closed, 需要操作者检查.

## Alternatives considered

### Rely on process traps only

Trap 可以处理部分 signal, 但不能覆盖 power loss, forced termination 或 process crash, 也不能为下次执行提供完整 evidence.

### Delete stale snapshots and retry

实现简单, 但可能删除唯一 original artifact, 违反可恢复 ownership migration contract.

### Allow concurrent Cask reconciliation

普通 inventory read 可以并行, 但 migration target 与 Homebrew install state 是共享 mutable state. 性能收益不足以抵消竞态风险.
