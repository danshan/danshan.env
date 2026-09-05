---
title: Platform-Gated Homebrew Casks
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../design/bootstrap-hardening.md
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - 0002-transactional-homebrew-font-migration.md
  - 0004-transactional-homebrew-app-migration.md
---

# ADR 0003: Platform-Gated Homebrew Casks

## Context

Cask 可以继续属于仓库 Desired State, 即使它的当前 release 只支持更新的 macOS. Homebrew 会在不兼容环境中正确拒绝安装, 但执行该命令会导致整个 Bootstrap 失败, 即使当前平台客观上无法满足该资源. Thaw 2.0.1 要求 macOS 26 Tahoe 或更新版本, 而 macOS 15 Sequoia 仍是本项目支持的 Bootstrap host.

Platform incompatibility 可以在 mutation 前确定, 且不同于 network, download, integrity 或 installation failure. Bootstrap 只能跳过显式声明的平台不兼容, 不得削弱其他 failure 的全局传播.

## Decision

- 将 optional `minimum_macos_major` 新增为 Cask manifest 第四列.
- 该字段只能为空或 positive decimal integer.
- 每个 Cask stage 只读取一次 `sw_vers -productVersion`, 并将 numeric major 保存为 Observed State.
- 在 current, outdated, missing, adoption 或 migration 处理之前评估 Platform Constraint.
- 不兼容 Cask 计入 skipped, 并输出要求的 major 和当前 major.
- Malformed manifest value 或 `sw_vers` failure 必须在任何 Cask mutation 前导致失败.
- 不得通过捕获 generic Homebrew failure 推断平台不兼容.

## Consequences

优点:

- 支持范围内的 host 可以完成 Bootstrap, 同时在 Desired State 中保留仅支持更新系统的 Cask.
- Tahoe 或更新系统无需修改 manifest, 即可自动开始管理 Thaw.
- 真实 Homebrew failure 继续保持 fail-fast 语义.
- Numeric comparison 兼容 Bash 3.2, 且不需要维护 codename ordering.

代价:

- Manifest 重复声明了 upstream Homebrew metadata 中的 compatibility boundary, upstream support 变化时必须同步更新.
- 当前只建模 minimum major constraint. Maximum version, exact set 或 architecture constraint 需要另行评审 schema extension.

## Alternatives considered

### Remove Thaw from the manifest

该方案允许 Sequoia 完成 Bootstrap, 但 Tahoe host 将无法继续收敛目标 application.

### Parse compatibility for every Cask from Homebrew JSON

该方案避免重复声明, 但会增加 per-Cask metadata query, 并要求实现可解释 minimum, maximum, exact-set 和 conditional constraint 的通用解析器. 当前只有一个显式约束, 不足以证明这部分复杂度合理.

### Ignore failed Cask installations

该方案会把 network, integrity, permission 和 package defect 与 incompatibility 一并隐藏, 违反 Bootstrap failure contract.
