# Documentation Instructions

## Scope

本文件适用于 `docs/` 下的全部内容.

## Required rules

- 创建或移动文档前先阅读 `standards/documentation.md`.
- 除 `README.md` 和 `AGENTS.md` 外, 正式 Markdown 文档必须包含规定的 front matter.
- 文件名使用 lowercase kebab-case. `adr/` 和 `reviews/` 分别使用规定的编号或日期前缀.
- 每份文档只承担一种职责. 不得创建 `misc`, `notes`, `tmp`, `new` 或 `final` 等含糊目录或文件名.
- 文档状态必须使用受控值. `superseded` 文档必须链接替代文档, `archived` 文档不得继续承载当前操作指引.
- 文档中的命令和代码必须使用 English, 并保持可复制执行. 不得包含真实凭据, 用户绝对路径或仅在作者机器成立的隐式前提.
- 所有内部链接使用相对路径. 新文档必须加入 `README.md` 导航.
- 修改实现契约时, 同步更新 architecture, operations, development 或 decision 文档中受影响的部分.

## Review checklist

- 标题, status, owner 和 last_updated 完整.
- 事实与当前实现一致, 未来计划明确标记为 draft.
- 命令说明包含前置条件, 预期结果和失败处理.
- 安全相关操作包含凭据, 回滚和不可逆影响说明.
- 重复内容通过链接引用, 不复制形成多个事实源.
