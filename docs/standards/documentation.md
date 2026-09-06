---
title: Documentation Standard
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../README.md
---

# Documentation Standard

## 1. Purpose

本规范定义 `docs/` 的信息架构, 文件命名, 元数据, 生命周期和变更联动规则. 目标是让每份文档有唯一职责, 可被稳定引用, 并能随实现持续演进.

## 2. Directory contract

| Directory | Allowed content | Forbidden content |
|---|---|---|
| `standards/` | 仓库级规范和检查规则 | 单个功能设计 |
| `architecture/` | 已实现系统的组件, 边界, 数据流和约束 | 尚未批准的提案 |
| `design/` | 功能方案, 权衡, 接口和迁移设计 | 日常操作手册 |
| `adr/` | 已接受或已废弃的 ADR | 可随意改写的工作笔记 |
| `development/` | 开发环境, 测试策略和贡献流程 | 生产运维步骤 |
| `operations/` | 安装, 升级, 回滚和故障处理 | 未落地的设计提案 |
| `reviews/` | 带日期的审查发现, remediation 和验证结论 | 当前架构事实的唯一副本 |
| `archive/` | 已退出当前导航的历史材料 | 仍然有效的操作指引 |
| `assets/` | 文档引用的图片和静态附件 | 可执行脚本和源代码 |

不得新增 `misc/`, `notes/`, `temp/`, `drafts/` 等逃逸分类. 无法归类通常意味着文档职责尚未明确.

## 3. Naming

- 普通文档使用 `lowercase-kebab-case.md`.
- ADR 使用 `NNNN-lowercase-kebab-case.md`, 编号四位且只增不复用.
- Review 使用 `YYYY-MM-DD-lowercase-kebab-case.md`.
- 静态资源使用 `lowercase-kebab-case.ext`, 并放在 `assets/<document-name>/`.
- 禁止使用 `v2`, `new`, `latest`, `final`, 作者名或无语义缩写区分版本. 版本关系由 Git 和文档状态表达.

## 4. Required metadata

除目录入口 `README.md` 和约束文件 `AGENTS.md` 外, Markdown 文档必须包含以下 front matter:

```yaml
---
title: Human Readable Title
status: draft
owner: repository-maintainers
last_updated: YYYY-MM-DD
related:
  - relative/path.md
---
```

`status` 只能使用以下值:

- `draft`: 尚未成为实现或操作契约.
- `active`: 当前有效且必须与实现同步.
- `superseded`: 已被新文档替代, 必须在 `related` 中链接替代文档.
- `archived`: 仅保留历史证据, 不得作为当前操作依据.

`owner` 表示维护责任, 不是作者署名. `last_updated` 必须在行为或结论发生变化时更新, 纯格式调整无需修改.

## 5. Document responsibilities

- Architecture 描述现在是什么, 不承载候选方案讨论.
- Design 描述准备如何改变系统, 包含目标, 非目标, 约束, 方案, 风险和验证.
- ADR 记录为什么选择某个难以逆转的决策, 接受后只允许修正事实错误或追加 superseded 状态.
- Development 描述贡献者如何安全地修改和验证项目.
- Operations 描述操作者如何执行, 判断成功, 处理失败和回滚.
- Review 记录某个时间点的发现和证据, 修复完成后链接当前事实源.

## 6. Change coupling

| Change | Required documentation update |
|---|---|
| Bootstrap stage or dependency order | `architecture/` and `operations/` |
| Command, flag, environment variable or default | `operations/` and root `README.md` |
| Testing strategy or test command | `development/` |
| Security boundary or credential handling | `operations/` and, when architectural, `adr/` |
| Long-lived implementation choice | `adr/` |
| Review remediation | Original `reviews/` record and affected current-state docs |

## 7. Links and duplication

- `docs/README.md` 必须能导航到全部 active 文档.
- 内部链接使用相对路径, 不使用本机绝对路径.
- 同一事实只保留一个权威描述. 其他文档通过链接引用, 并只补充各自上下文.
- 外部链接应指向官方或原始来源, 并在行为依赖外部版本时记录访问日期或固定版本.

## 8. Security and examples

- 示例不得包含真实 token, host credential, private repository URL 中的凭据或个人绝对路径.
- 凭据示例使用明显占位符, 并优先说明从环境变量或被忽略的 local 文件加载.
- 破坏性操作必须说明影响范围, 备份或恢复路径, 并要求显式确认.
- 从网络下载并执行的内容必须记录版本固定和完整性策略.

## 9. Lifecycle

1. 在 `design/` 创建 `draft` 文档并加入导航.
2. 方案接受后, 必要时创建 ADR, 然后实现代码和测试.
3. 实现完成时, 将当前事实写入 architecture, development 和 operations 文档.
4. 被替代文档改为 `superseded`, 双向链接替代文档.
5. 仅当文档不再参与当前导航且只具有历史价值时移动到 `archive/`.

维护者明确批准清理过期文档时, 可以删除已被替代的设计或 ADR, 并同步移除全部入站链接. 被删除 ADR 的编号不得复用, 历史由 Git 保留. 仍有效的信任例外和安全事件证据应继续保留或归档.

文档移动必须同时更新入站链接. 不得仅复制后删除, 以免形成两个并行事实源.

## 10. Review checklist

- 目录和文件名符合本规范.
- Metadata 完整且状态准确.
- 文档职责单一, 没有与其他 active 文档复制事实源.
- 示例可复制, 不含凭据或用户专属路径.
- 行为变化已覆盖 change coupling 表中的全部文档.
- `docs/README.md` 导航和链接有效.
