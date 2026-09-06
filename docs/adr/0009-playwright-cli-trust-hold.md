---
title: Playwright CLI Trust Hold
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - ../development/testing.md
  - 0007-reviewed-npm-trust-policy-exception.md
---

# ADR 0009: Playwright CLI Trust Hold

## Context

Mise 2026.9.1 的 Aube backend 拒绝安装 `npm:@playwright/cli@latest`, 当时原生 lockfile 解析为 `0.1.19`. `trustPolicy=no-downgrade` 指出早期 `0.1.0` 带有 trusted publisher, 目标版本没有同等级证据. 核对日期为 2026-09-06.

## Evidence

- npm 官方 [0.1.19 metadata](https://registry.npmjs.org/@playwright%2fcli/0.1.19) 的 publisher 是 `microsoft1es`, email 为 `npmjs@microsoft.com`, 发布时间为 `2026-09-01T16:19:56.878Z`. 其中没有 `trustedPublisher`, `dist.attestations` 或 `gitHead`. 官方 registry 自身缺少这些字段, 因而不能仅归因于代理丢失 metadata.
- npm 官方 [0.1.18 metadata](https://registry.npmjs.org/@playwright%2fcli/0.1.18) 的 publisher 是 GitHub Actions, 包含 GitHub OIDC trusted publisher 和 SLSA provenance, 发布时间为 `2026-08-06T00:15:41.805Z`.
- 该版本精确依赖的 [playwright](https://registry.npmjs.org/playwright/1.63.0-alpha-2026-08-05) 和 [playwright-core](https://registry.npmjs.org/playwright-core/1.63.0-alpha-2026-08-05) 同样具有 GitHub OIDC trusted publisher 与 provenance metadata; 两者的 `gitHead` 都为 `5f58876dc84d69008907e75d818baf55b0f78dc1`. 传递的可选 `fsevents@2.3.2` 继续交给 Aube 原生策略处理, 不增加例外.
- 两个 tarball 的 SHA-512 都与各自 `dist.integrity` 相符. 使用 npm 官方 [registry 公钥](https://registry.npmjs.org/-/npm/v1/keys) 对 `name@version:integrity` 验证 ECDSA registry signature, 两者均通过. Registry signature 证明 registry 中的内容绑定, 不等同于发布工作流 provenance.
- 两版 tarball 中的 `playwright-cli.js`, `skillCheck.js` 和 `package.json` 均与 Microsoft 官方源码逐字节一致. 对应 commit 为 [0.1.18](https://github.com/microsoft/playwright-cli/commit/ca196c297169a494ee5517584883eada60dc8d0e) 和 [0.1.19](https://github.com/microsoft/playwright-cli/commit/397ee39c83a651e1314cfb010b94e8a3aac11261), GitHub API 将两者标记为 verified. 检查过程没有执行 tarball 内容.
- [0.1.18 attestation](https://registry.npmjs.org/-/npm/v1/attestations/@playwright%2fcli@0.1.18) 的 provenance statement 指向 `microsoft/playwright-cli`, `.github/workflows/publish.yml`, tag `v0.1.18`, GitHub-hosted runner 和上述 `ca196c2` commit. Publish 与 provenance statement 的 subject SHA-512 都匹配下载内容. 此处核对的是 registry 提供的 statement 字段和 subject digest, 未独立完成 Sigstore certificate chain 与 transparency log 的密码学验证; 安装时继续保留 Aube 原生信任检查.

`0.1.18` tarball 的 SHA-512:

```text
82035f6181fe1ac65319488110bf1fe8de63d2c798114139daff9f216a8afc0dfa406dfa70bd0427bf6a5935d83b6b9931453bbe6fa3937c747ca08f2fa52e23
```

上述结果支持 `0.1.19` 内容与官方源码一致, 但不能补回该版本缺失的 trusted publishing evidence, 也不意味着已证明或发现供应链入侵.

## Decision

- 将 `npm:@playwright/cli` 的 Version Selector 明确固定为 `0.1.18`, 使用原生 `mise lock` 同步解析结果.
- 保留 Aube `no-downgrade`, 不新增 Playwright trust exception, 不启用 `npm.shell_out=true`, 不扩大 ADR 0007 的例外.
- 普通 lockfile refresh 保留该精确 pin. 只有在核对后续 release 的 publisher, provenance, source 和 artifact 后才可解除 Trust Hold.
- 同步安全约束测试, 防止仅刷新 lockfile 或恢复 `latest` 时静默解除 Hold.

## Consequences and alternatives

固定上一版暂时放弃 `0.1.19` 对应的新 Playwright dependency, 换取完整的既有发布信任证据. 传递依赖继续受 Aube 检查, 该选择不保证未来所有 dependency resolution 都成功. NPM 原生 Mise lockfile 仍只记录其支持的版本字段, 不手写 checksum 或 dependency graph.

另一选择是独立审查后为 `@playwright/cli@0.1.19` 增加精确例外. 当前已有具备 trusted publisher 与 provenance 的可用版本, 因而优先采用不扩大信任边界的 Hold. 永久豁免 package 或切换 installer 会扩大未审查范围, 不采用.

解除 Hold 时追加后续 ADR, 保留本次证据, 并同步 config, 原生 lockfile, 测试和 runbook. 上游发布身份与 provenance 的不一致应由维护者处理; 本次修复不自动向外部维护者发送消息.
