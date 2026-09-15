# 文档规范

## 目标

文档记录当前行为和长期约定, 不保存临时讨论. 内容应能够由代码, 命令或官方资料验证.

## 路径与命名

- 根 `README.md` 是用户入口.
- `docs/README.md` 是维护文档索引.
- 通用规则放在 `docs/standards/`.
- 时间点审查放在 `docs/reviews/`, 文件名使用 `YYYY-MM-DD-topic.md`.
- 其他文件名使用 lowercase kebab-case, 不创建只有一个文件的多层目录.

## 写作

- 标题准确描述主题, 每个文件只承担一个主要目的.
- 中文正文使用 English punctuation, 中英文之间保留空格.
- Code, comments, identifiers, commands, paths, and code blocks use English.
- 外部 API 结论使用官方链接, 并注明核对日期.
- 行为变化必须在同一变更中同步根 `README.md`, 相关详细文档和 `CONTEXT.md` 术语.

## 维护

新增文档时更新 `docs/README.md`. 被替代的文档应标记 `Superseded`, 并链接替代文档; 只有在清理全部引用后才删除.
