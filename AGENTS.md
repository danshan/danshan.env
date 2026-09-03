# Repository Instructions

## Scope

本文件适用于整个仓库. 子目录中的 `AGENTS.md` 可以增加更具体的约束, 但不得降低这里的安全性和验证要求.

## Project contract

- 本项目面向 macOS, Bootstrap 脚本统一使用 Bash 3.2 兼容语法.
- 所有脚本必须支持重复执行. 已满足的状态应明确跳过, 仅对缺失或过期状态执行变更.
- 不得把 token, password, private key 或其他凭据提交到仓库. 本地凭据只能放入已忽略的 `*.local.*` 文件或外部凭据管理器.
- 不得直接执行未经固定版本或完整性校验的远程脚本. 唯一例外必须记录在 `docs/adr/`, 并说明信任边界和替代方案.
- 任何步骤失败时, 顶层安装命令必须返回非零状态, 并且不得输出完成提示.
- 涉及 Git 更新时必须显式指定工作目录, 使用 fast-forward-only 策略, 并在变更前验证目标是 Git worktree.
- 不得隐式修改调用者当前目录中的配置. 所有持久化写入必须指定明确的目标路径或 global scope.
- Codex Hook 只能作为 repository-local 配置加入 `.codex/hooks.json`. 不得创建或修改全局 `~/.codex/hooks.json`, 也不得引用用户绝对路径中的 executable.

## Documentation

- 所有正式文档遵循 `docs/standards/documentation.md`.
- 代码, 配置, 安装行为或运维步骤发生变化时, 必须在同一变更中更新对应文档.
- 新增文档后必须更新 `docs/README.md` 导航.
- 架构决策和不可逆兼容性选择必须在 `docs/adr/` 新增 ADR, 不得只记录在 commit message 中.
- 项目术语以根目录 `CONTEXT.md` 为准. 新增或改变领域术语时必须同步更新 glossary.

## Implementation style

- Shell 代码, 注释, 标识符和输出消息使用 English.
- 对路径和变量展开使用双引号, 对未设置变量保持 `set -u` 安全.
- 共享行为放入 `scripts/common.sh`, 不复制状态判断或错误处理逻辑.
- 优先使用状态收敛模型: inspect, classify, reconcile, verify.

## Verification

- 修改 Shell 脚本时, 至少执行语法检查和 `tests/run.sh`.
- 测试必须使用临时 `HOME` 和 stub executable, 禁止真实安装软件或修改用户环境.
- 新增分支逻辑时, 至少覆盖 missing, current, outdated 和 command failure.
- 提交前确认工作树中不存在凭据, 临时文件或未登记文档.
