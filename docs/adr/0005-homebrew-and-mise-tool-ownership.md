---
title: Homebrew and Mise Tool Ownership
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../design/bootstrap-hardening.md
  - ../operations/installation.md
  - 0001-bash-bootstrap-and-state-reconciliation.md
---

# ADR 0005: Homebrew and Mise Tool Ownership

## Context

同一类 CLI 曾分散在 Homebrew, Mise 和 Bun global package 中. 这会产生重复的 Node.js runtime, PATH 优先级不确定, 版本检查逻辑重复, 并使卸载与升级 ownership 不清晰. `agent-browser` 的 Homebrew Formula 还会引入 Homebrew Node.js, 即使开发环境已经由 Mise 管理 Node.js.

项目需要区分 host-level package, version-sensitive development tool 与 project dependency, 同时保持新主机和重复执行的一致结果.

## Decision

- Homebrew 是 macOS system package, Shell integration dependency 和 GUI Cask 的唯一 Tool Owner.
- Mise 是 language runtime 与固定版本 global CLI 的唯一 Tool Owner.
- Java, Maven, Node.js, Python, Bun, uv, Starship 和 agent CLI 全部声明在 repository-managed Mise global config.
- Aqua 和 NPM 只作为 Mise Installation Backend. Bootstrap 不再直接执行 Bun 或 NPM global install.
- Bun 与 NPM 仅管理具体项目 dependency, 由对应项目的 manifest 和 lockfile 负责.
- Mise config 使用精确版本. `mise.lock` 对支持 locking 的 backend 固定 platform artifact 与 checksum; NPM backend 保留精确版本但不声明 artifact checksum guarantee.
- Homebrew installer 与 pinned Git dependency revision 继续位于独立 version manifest, 因为它们是 Mise 可用之前的 Bootstrap dependency.
- 旧 Bootstrap 生成的 Mise global config 在内容可证明是新 config 子集时, 通过 retained snapshot 和 Rollback-capable Stow transaction 转移 ownership. 不使用 `stow --adopt`.

## Consequences

优点:

- 每个 tool 只有一个安装, 更新和卸载 owner, PATH 结果可预测.
- Version-sensitive CLI 与 runtime 共同由 Mise 收敛, 不再维护额外的 Bun global inventory logic.
- 避免仅为 global CLI 引入另一套 Homebrew Node.js.
- 支持 lock 的 backend 获得 platform artifact checksum verification.

代价:

- Mise NPM backend 必须先有 Node.js tool, 初次 reconciliation 顺序由 Mise toolset resolution 负责.
- NPM backend 的 lock 强度低于 Aqua artifact lock, registry compromise 仍超出 repository lockfile 的完整性边界.
- 升级 CLI 需要同时更新 config, lockfile 和测试 contract.

## Alternatives considered

### Homebrew owns every global tool

操作方式统一, 但 runtime 与 fast-moving CLI 无法稳定固定到 repository version, 并可能引入重复 runtime dependency.

### Bun owns every JavaScript CLI

安装速度快, 但需要自建 global inventory, version reconciliation 和 PATH contract, 与 Mise 已有能力重复.

### Split global CLI between Mise and direct NPM or Bun

局部改动最少, 但同类资源仍存在多 owner, 无法从 manifest 判断真正的升级和卸载入口.
