---
title: Reviewed NPM Trust Policy Exception
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - 0008-native-package-managers-and-explicit-migrations.md
---

# ADR 0007: Reviewed NPM Trust Policy Exception

## Context

Mise 2026.9.1 使用 Aube 安装 `npm:oh-my-openagent@4.19.1` 时, `trustPolicy=no-downgrade` 拒绝 `effect@4.0.0-beta.66`. 先前比较基线 `effect@3.19.10` 由 GitHub Actions OIDC publisher 发布自 `Effect-TS/effect`, 而目标 beta 由 `effect-bot` 发布自 `Effect-TS/effect-smol`. 这是 publisher 和 repository trust transition, 不能按普通 dependency-resolution failure 忽略.

Dependency chain 为 `oh-my-openagent@4.19.1` 到 `@opencode-ai/plugin@1.15.13`, 再到精确 `effect@4.0.0-beta.66`.

## Evidence

- npm registry 为目标版本提供 package signature, publish attestation 和 SLSA provenance attestation.
- Provenance 指向 Effect-TS 官方组织的 `effect-smol` repository, `.github/workflows/release.yml`, GitHub-hosted runner 和 commit `4c9e697866eb1eff77aa44946dd044763e040ea8`.
- GitHub 将该 commit 标记为 valid verified signature; commit package manifest 的 name/version 为 `effect@4.0.0-beta.66`, 并启用 provenance publish.
- Attestation subject SHA-512 为 `e1aac4afad9cce215af010550d4c090892666957a95dffe4460ecab42d21f3e6ee7e782c72b1dbc16161afd73e1e89f0385fb7d54de20f7c54266c3d2b35fb0f`, 与 npm `dist.integrity` 解码结果一致.
- npm package signature key ID 与 registry metadata 一致.

Primary evidence:

- `https://registry.npmjs.org/-/npm/v1/attestations/effect@4.0.0-beta.66`
- `https://github.com/Effect-TS/effect-smol/commit/4c9e697866eb1eff77aa44946dd044763e040ea8`
- `https://raw.githubusercontent.com/Effect-TS/effect-smol/4c9e697866eb1eff77aa44946dd044763e040ea8/packages/effect/package.json`

## Decision

- 在 `npm:oh-my-openagent` tool declaration 中加入 `trust_policy_excludes = ["effect@4.0.0-beta.66"]`.
- 保持 top-level tool version 固定为 `4.19.1`.
- 不使用 bare `effect` exception, 不设置 `npm.shell_out=true`, 不切换到绕过 Aube policy 的 installer.
- 保留 Aube 对其他 dependency 和其他版本的 `no-downgrade` enforcement.
- 当 dependency graph 不再选择该精确 effect version 时删除 exception.

## Consequences

该选择允许经过独立核验的 Effect 4 beta release 通过, 同时把信任扩张限制在一个 top-level tool 的单一 transitive version. 未来 `effect` version, publisher, repository, workflow 或 digest 变化仍会重新触发审查, 不会被当前 exception 静默接受.

维护成本是每次升级 `oh-my-openagent` 或 `@opencode-ai/plugin` 时必须重新检查 dependency graph, 并优先移除已失效的 exception.

## Alternatives considered

### Disable Aube through the npm CLI

`npm.shell_out=true` 会绕过整个 Aube policy, 信任扩张远大于当前单一 dependency version, 因此拒绝.

### Exempt the effect package without a version

Bare package exception 会接受未来尚未审查的 release, 不符合最小权限原则.

### Remove oh-my-openagent

这是最严格的选择, 但现有 provenance, official repository, signed commit 和 digest evidence 足以支持狭窄 exception. 若任何 evidence 无法再次验证, 应回退到移除该 tool.
