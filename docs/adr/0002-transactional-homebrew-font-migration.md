---
title: Transactional Homebrew Font Migration
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../design/bootstrap-hardening.md
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - 0003-platform-gated-homebrew-casks.md
  - 0004-transactional-homebrew-app-migration.md
---

# ADR 0002: Transactional Homebrew Font Migration

## Context

当 Nerd Font 文件已存在于 `${HOME}/Library/Fonts`, 但对应 Cask 不在 Homebrew inventory 中时, `brew install --cask` 会拒绝同名冲突. `--adopt` 只能接管 byte-identical artifact, 因此无法处理文件名相同但内容不同的旧版 Nerd Font. `--force` 会破坏现有 ownership 边界, 本项目禁止使用.

Bootstrap 必须在无需反复手动删除字体的前提下, 收敛这些显式管理的 font families, 同时保留迁移前状态, 并避免 multi-cask 批次停留在部分成功状态.

## Decision

- 无 App name 的纯 font cask 使用显式 `migrate` existing artifact policy, 并由 font-specific batch transaction 处理.
- 从当前 `brew info --cask --json=v2` metadata 读取精确 font targets, 并使用 macOS `plutil` 解析.
- 只接受 `${HOME}/Library/Fonts` 直属目录下的 `.ttf` 或 `.otf` target.
- 将所有兼容且 missing 的 `migrate` cask 纳入同一个 transaction, platform gate 必须先于 migration selection.
- 安装前把 target 是否存在及其原始文件持久化到唯一 Migration Snapshot.
- 不使用 `--adopt` 或 `--force` 安装, 随后同时验证 Homebrew inventory 和每个 target.
- 失败时卸载本 transaction 注册的 cask, 保留 replacement artifact, 并恢复迁移前 snapshot.
- 成功和失败的 snapshot 都持续保留, Bootstrap 不自动删除.

## Consequences

优点:

- 旧版本或不同 build 的外部字体可以自动迁移到 Homebrew ownership.
- Batch failure 不会静默留下部分字体 family 已迁移的状态.
- Snapshot, manifest 和 state marker 提供明确恢复证据.
- Exact metadata target 避免宽泛 glob 影响无关字体.

代价:

- Missing `migrate` cask 需要额外读取一次 Homebrew JSON metadata.
- 成功 snapshot 持续占用磁盘, 清理由操作者显式决定.
- Font cask artifact schema 若改变为非 font target, Bootstrap 会 fail closed, 需要先评审 policy.

## Alternatives considered

### Adopt every missing font cask

内容完全相同时有效, 但旧版本同名文件会失败, 无法实现自动迁移.

### Force installation

实现简单, 但会覆盖未备份的外部 artifact, 无法证明 Rollback, 不符合仓库安全边界.

### Preserve external fonts and skip Homebrew

不会改变本机文件, 但 Desired State 无法统一 ownership 和升级路径. 该方案适合未声明 `migrate` 的资源, 不适合仓库明确管理的 Nerd Font families.
