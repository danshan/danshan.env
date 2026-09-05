---
title: Transactional Homebrew Application Migration
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../design/bootstrap-hardening.md
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - 0002-transactional-homebrew-font-migration.md
  - 0003-platform-gated-homebrew-casks.md
---

# ADR 0004: Transactional Homebrew Application Migration

## Context

当外部安装的 App bundle 已存在, 但对应 Cask 不在 Homebrew inventory 中时, `--adopt` 只允许接管 bundle version 或递归内容相同的 artifact. LocalSend 1.17.0 与 Cask 1.18.2 的版本不同, 因而 adoption 按 Homebrew contract 失败.

该状态不是普通 install failure, 也不能通过 `--force` 安全解决. Bootstrap 需要一种显式、通用且可恢复的 ownership transition, 同时必须避免把所有 existing App 自动替换.

## Decision

- 将 `migrate` 定义为通用 existing artifact ownership policy, 但按 artifact type 使用独立 transaction.
- 带 App name 的 missing Cask 只操作精确 `/Applications/<name>.app` target.
- App target 存在时, 先写入 manifest 与 state, 再把原 bundle 移入唯一 Migration Snapshot.
- 使用普通 `brew install --cask`, 不使用 `--adopt` 或 `--force`.
- Verify 同时要求 Homebrew inventory 登记成功与 App target directory 存在.
- Install 或 verify 失败时, 卸载本 transaction 已登记的 Cask, 隔离新 artifact, 并恢复 original bundle.
- App target 不存在时走普通 missing install; current 与 outdated Cask 继续走正常 skip 或 upgrade.
- 成功与失败 snapshot 都持续保留, 只允许操作者在确认无需恢复后显式清理.

## Consequences

优点:

- 不同版本的 external App 可以自动迁移到 Homebrew ownership.
- 普通 Homebrew failure 不会被忽略, 旧 App 在失败时自动恢复.
- Policy 为 opt-in, 不改变其他 existing App 的默认 `preserve` 行为.
- Snapshot, manifest, state 与 failed artifact 提供完整恢复证据.

代价:

- 成功 migration 会持续占用一个完整 App bundle 的额外磁盘空间.
- Snapshot 只包含 App artifact, 不复制 preferences, caches 或 user data.
- 每个 App 独立 transaction, 多个 App migration 不提供跨 Cask batch atomicity.

## Alternatives considered

### Retry with adopt

Homebrew 明确拒绝 version 或内容不同的 artifact, 重试不会改变结果.

### Install with force

该方案会绕过 ownership conflict 并覆盖既有 App, 但没有可验证 snapshot 与 Rollback, 不符合仓库安全边界.

### Encode a LocalSend-only workaround

单点 workaround 无法处理后续相同状态, 并会把 transaction 语义散落到 package-specific 分支中, 不利于维护与测试.
