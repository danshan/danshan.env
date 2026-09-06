# Repository Instructions

## Scope

本文件适用于整个仓库. 子目录中的 `AGENTS.md` 可增加具体约束, 不得降低安全性和验证要求.

## Project contract

- 本项目面向 macOS, Bootstrap 使用 Bash 3.2 兼容语法.
- 日常资源按原生管理器规则收敛, 可重复执行. 已满足状态应跳过, 任何失败必须传播为非零, 且不得输出完成提示.
- Homebrew 通过 `Brewfile` 管理主机 CLI, Shell 组件, App 和字体. Mise 通过原生 config/lockfile 管理 runtime 与开发 CLI. Bun/NPM 只直接管理项目 dependency, 不执行 global install.
- 开发 CLI 可以声明 `latest`, 日常安装使用已提交的原生 lockfile. runtime 保留明确版本. 不手写上游 backend 不支持的 checksum 或 dependency lock.
- ADR 0007 的精确信任例外只适用于其绑定版本和依赖, 不得因 latest 策略扩大例外.
- NPM trust downgrade 不得自动添加例外或切换 installer. 可依据发布证据将工具固定在可信版本, 同步原生 lockfile 与 ADR; ADR 0009 的 Playwright Trust Hold 需重新审查后才可解除.
- 不得复制 Homebrew 普通 inventory/outdated/upgrade 状态机, 不为新增普通 package 添加专用安装分支.
- Homebrew 安装必须实时透传 stdout/stderr 并保留 TTY, 下载进度由原生工具呈现. 步骤状态和耗时不得掩盖失败或提前报告整体完成.
- 包级 trust 与平台条件写在 Brewfile. 不信任整个 tap, 不关闭 trust 检查, 不使用 `--force`, 不自动清理未声明软件.
- Bundle adoption 采用 Homebrew 原生规则, 不宣称仓库保证逐字节一致. adoption 失败不得自动升级为 ownership migration.
- 公开入口为 `install.sh apply/check/migrate/recover`. `check` 必须使用仓库 Seatbelt profile 禁止文件写入与网络访问, 包括隐式 cache 和迁移写入; 沙箱不可用则失败, 不回退为非隔离执行.
- 所有 mutation 使用 repository-defined `lockf` 锁. 不删除活跃锁文件 inode, 不用 PID 文件替代内核互斥.
- `apply/check` 仅检查 pending snapshot, 不自动迁移或恢复. 新 transaction 前必须没有未解决 snapshot; 恢复只由显式 `recover` 执行.
- 接管必须由 `config/migrations.txt` 显式许可. App 只允许精确 `/Applications/<name>.app`; 字体从 Homebrew metadata 读取精确 target, 只允许 `${HOME}/Library/Fonts` 直接 `.ttf/.otf` 子项.
- 字体迁移按 batch 安装并验证. App/字体必须先保存原件, 任一 install 或 verify 失败时先保留失败产物, 再卸载本次安装并恢复原件. 拒绝宽泛 glob, symlinked parent, 路径穿越和覆盖未知文件.
- Snapshot 移动必须验证原件和备份位于同一 filesystem, 禁止将跨卷 copy/delete 当作原子 rename.
- Snapshot 和原件持续保留在 `${HOME}/Library/Application Support/danshan.env` 对应 backups 目录, Bootstrap 不自动清理. state 原子更新, `rollback-incomplete` 必须 fail closed.
- 保留可识别的旧 snapshot 恢复兼容. 无 state 的 legacy font snapshot 只有在 manifest, exact target, retained backup 和 Homebrew ownership 全部验证后才可只读认可 completed.
- 旧 Mise global config 仅当 `[tools]` 简单赋值是 repository config 的可验证子集时才可迁移为 Stow ownership. 必须保留 snapshot 和原 lockfile ownership, 未知内容拒绝自动接管.
- Git mutation 必须使用显式 `git -C`, 验证精确 worktree root 与 origin, 只允许 fast-forward. Pinned dirty worktree 失败, tracking dirty worktree 保留并明确报告 skip.
- 不隐式修改调用者 cwd 配置. Mise Bootstrap 配置发现必须隔离 cwd, 祖先, system, 外部 global 和调用者环境设置.
- 清单由配置文件管理. `config/` 文件头部必须完整说明用途, 格式, 字段, 允许值, 分隔符, 注释规则和维护示例; 示例和代码注释使用 English.
- 不提交 token, password 或 private key. 本地凭据仅使用已忽略的 `*.local.*` 或外部凭据管理器.
- 不直接执行未经固定版本或完整性校验的远程脚本; 例外必须记录 ADR, 信任边界和替代方案.
- Codex Hook 仅可放入 repository-local `.codex/hooks.json`, 使用仓库内 executable. 不创建或修改全局 Hook.

## Documentation

- 正式文档遵循 `docs/standards/documentation.md`.
- 代码, 配置, 安装或运维行为改变时, 同一变更中同步对应文档与 `CONTEXT.md` 术语.
- 新文档登记到 `docs/README.md`. 长期架构决策与兼容性变化必须有 ADR.
- 被替代文档标记 superseded 并链接替代文档, 或按维护者授权删除并清理引用. ADR 编号不得复用, 有效安全依据应保留. 历史 Review 不作为当前运行指引.

## Implementation style

- Shell 代码, 注释, 标识符和输出使用 English, 路径与变量展开加双引号, 保持 `set -u` 安全.
- 功能模块放在 `scripts/`, 基础函数在 `scripts/lib/`, 迁移逻辑在 `scripts/migrations/`. 不重新建立跨职责的大型 common 模块.
- 关键写入显式检查退出状态, 覆盖函数在条件上下文中被调用时 `errexit` 不生效的情况.

## Verification

- 修改 Shell 至少逐文件执行语法检查和 `tests/run.sh`.
- 测试使用临时 HOME/XDG 和 stub, 禁止真实安装或修改用户环境. 可在隔离环境调用真实只读管理器, 本地 Git, Stow 和系统锁验证行为.
- 覆盖 missing, current, outdated 与 command failure; 不把具体工具版本字符串当作通用状态机测试.
- 新增迁移覆盖 success, repeat, install/verify failure, artifact preservation, rollback, rollback-incomplete 和 interrupted recovery.
- 字体额外覆盖 exact target, batch/partial failure, 原先 absent target 和 retained state; 恢复必须覆盖异常 manifest 和原件缺失.
- 顶层模式覆盖完整隔离执行, check 无 mutation, `--stage`, `--from`, 锁冲突和失败传播.
- 配置格式变化同步校验合法与非法输入. 提交前检查凭据, 临时文件和文档导航.
