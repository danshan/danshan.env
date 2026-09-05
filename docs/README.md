# Documentation Index

本目录是项目设计, 开发, 运维和审查记录的正式入口. 文档组织规则见 [Documentation Standard](standards/documentation.md).

项目统一语言由根目录 [CONTEXT.md](../CONTEXT.md) 定义.

## Navigation

| Area | Purpose | Index |
|---|---|---|
| `standards/` | 文档结构, 命名和生命周期规范 | [Documentation Standard](standards/documentation.md) |
| `architecture/` | 当前系统边界, 组件和执行流 | [Bootstrap Architecture](architecture/bootstrap.md) |
| `design/` | 已批准或正在评审的功能设计 | [Bootstrap Hardening](design/bootstrap-hardening.md) |
| `adr/` | 不可变更号的 Architecture Decision Records | [ADR 0001](adr/0001-bash-bootstrap-and-state-reconciliation.md), [ADR 0002](adr/0002-transactional-homebrew-font-migration.md), [ADR 0003](adr/0003-platform-gated-homebrew-casks.md), [ADR 0004](adr/0004-transactional-homebrew-app-migration.md) |
| `development/` | 本地开发, 测试和贡献流程 | [Testing Guide](development/testing.md) |
| `operations/` | 安装, 升级, 故障恢复和安全操作 | [Installation Runbook](operations/installation.md) |
| `reviews/` | 带日期的 code review 和验证记录 | [Bootstrap Remediation](reviews/2026-09-03-bootstrap-remediation.md) |
| `archive/` | 已失效但需要保留的历史文档 | 当前无文档 |
| `assets/` | 被正式文档引用的静态资源 | 当前无资源 |

## Source of truth

- 运行时行为以代码和测试为事实源.
- 设计意图以 active ADR 和 architecture 文档为事实源.
- 操作步骤以 operations 文档为事实源.
- 当实现与文档不一致时, 该变更未完成, 必须在同一工作项中修复差异.
