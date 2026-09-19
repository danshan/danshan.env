---
title: Thaw Platform Upper Bound
status: active
owner: repository-maintainers
last_updated: 2026-09-19
related:
  - 0010-local-compatibility-casks.md
  - ../operations/installation.md
  - ../development/testing.md
---

# ADR 0014: Thaw Platform Upper Bound

维护者明确要求 macOS major >= 27 时不安装 Thaw. Brewfile 仅在 macOS 26 声明官方 `thaw`, 在 14 至 25 声明固定版本 `danshan/env/thaw@1` 及其 Local Tap, 其他系统均不声明这些资源. 这是仓库安装策略, 不推断上游兼容性.

此决策局部替代 [ADR 0010](0010-local-compatibility-casks.md) 中 macOS 26 及以上均使用官方 Thaw 的范围, 保留其固定版本, Local Tap 和包级 trust 依据. 平台选择集中在 Brewfile, 不增加安装脚本分支. 已安装的 Thaw 不会自动卸载; 未来需要支持更高系统版本时, 必须显式修改平台范围并同步边界测试.
