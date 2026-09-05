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
- 既有字体迁移只能由 Cask manifest 的显式 `migrate` policy 启用. 必须从 Homebrew metadata 读取精确 font target, 且只允许 `${HOME}/Library/Fonts` 的直接 `.ttf` 或 `.otf` 子项.
- 字体迁移必须先创建 Migration Snapshot, 再按 batch 安装并验证全部 Cask. 任一 install 或 verify 失败时必须整体 Rollback, 保留失败产物和状态记录, 不得使用 `--force`, 宽泛 glob 或不可恢复删除.
- 成功的 Migration Snapshot 必须保留在 `${HOME}/Library/Application Support/danshan.env/font-backups`, 不得由 Bootstrap 自动清理.
- 既有 App bundle 只有在 Cask manifest 显式声明 `migrate` 时才允许转移 ownership. 必须先将精确 `/Applications/<name>.app` target 移入 Migration Snapshot, 再执行普通 Cask install 和 ownership verification; 任一失败必须隔离新 artifact 并恢复原 App.
- `adopt` 只能用于 Homebrew 判定为 identical 的既有 artifact. 不得在 `adopt` 失败后隐式升级为 `migrate`, 也不得使用 `--force` 绕过版本或内容差异.
- Cask 的平台限制必须在 manifest 第四列显式声明为正整数 `minimum_macos_major`. Cask stage 只读取一次 `sw_vers -productVersion`, 并在 install, upgrade 或 migration 前 skip 不兼容资源; 不得通过捕获任意 Homebrew failure 推断平台不兼容.

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
- 新增 migration transaction 时, 必须覆盖 success, repeat execution, install failure, verify failure, artifact preservation, Rollback 和 rollback-incomplete contract.
- 修改字体迁移时, 还必须覆盖 exact target validation, batch success, repeat execution, partial install failure, Rollback 和 backup state marker.
- 修改 Cask 平台 gating 时, 必须覆盖 below-minimum, at-minimum, installed, outdated, invalid manifest value 和 `sw_vers` command failure.
- 提交前确认工作树中不存在凭据, 临时文件或未登记文档.
