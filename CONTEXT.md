# Environment Bootstrap

本上下文定义项目统一语言. 命令和具体布局见当前架构与运维文档.

## Language

**Bootstrap**: 从未配置或部分配置的主机建立声明环境的过程.

**Desired State**: 原生清单和部署配置中声明的工具, 版本, 文件及其关系.

**Observed State**: 从包管理器 inventory, Git worktree 或目标文件读取的当前事实.

**Managed Resource**: 清单明确声明由本仓库及其 Tool Owner 持续管理的资源.

**Tool Owner**: 对工具安装, 版本选择和更新承担唯一职责的管理器. Homebrew 管理主机工具与 Cask, Mise 管理 runtime 与开发 CLI.

**Installation Backend**: Mise 获取工具的上游 transport, 例如 NPM 或 Aqua. Backend 不构成第二个 Tool Owner.

**Reconciliation**: 原生管理器或部署模块把 Observed State 收敛到 Desired State 的过程.

**Satisfied Resource**: 已满足声明状态, 可以跳过变更的资源.

**Missing Resource**: 声明要求但当前不存在的资源.

**Outdated Resource**: 已存在但需要按 owner 的版本规则更新的资源.

**Platform Constraint**: 原生清单对当前主机启用资源的条件. 不满足条件时不声明该资源, 不能通过忽略任意安装错误替代判断.

**Compatibility Cask**: 为旧平台保留的固定版本 Homebrew Cask. 定义在仓库 `Casks/` 中, 原生 Local Tap 消费已提交版本, Brewfile 决定平台选择与包级 trust.

**Local Tap**: Homebrew 从当前 Bootstrap Git 仓库创建的独立 tap clone. 它只读取已提交的 Cask 定义, 不与源工作树共享 checkout, 不授予整个 tap 信任.

**Version Selector**: 配置中的版本意图, 可以是固定版本或开发 CLI 的 `latest`.

**Trust Hold**: 因候选 release 的发布信任证据下降, 将工具明确固定到经过核验的版本. 不豁免原生信任检查, 解除前必须重新核对发布证据并同步 ADR 和 Lockfile.

**Lockfile**: 原生管理器保存的具体解析结果. URL, checksum 和 dependency graph 的锁定能力取决于 backend, 不能统一推断.

**Bootstrap Stage**: 有独立职责和失败边界的阶段, 例如 Homebrew, Git dependency, Stow 或 Mise 部署.

**Preflight**: 变更前的平台, 声明格式和已有 Git identity 检查. 原生配置由对应管理器继续验证.

**Check**: 禁止文件写入和网络访问的本地状态检查. UNKNOWN 表示缺少管理器或证据, 不能视为已满足. 不等同于完整安装计划或远端版本检查.

**Migration Allowlist**: 对精确既有 App, 字体或受支持旧配置的显式接管许可, 与日常安装清单分开维护.

**Ownership Migration**: 由显式命令启动, 将外部 artifact 转移给 Tool Owner 的 transaction.

**Migration Snapshot**: 接管前创建并持续保留的原件, 精确目标 manifest 和 transaction state.

**Rollback**: 失败时先保留替换产物, 撤销本 transaction 的新安装, 再从 snapshot 恢复原状态. 不撤销之前已经 completed 的其他 transaction.

**Migration Lock**: 保护 Bootstrap 变更的内核互斥锁. 锁文件 inode 持续保留, 活跃持有者退出后锁释放.

**Interrupted Migration**: 在 snapshot 建立后但最终状态写入前退出的 transaction. 只有显式 Recover 才处理可识别的中断.

**Recover**: 验证已有 snapshot 并恢复中断 transaction 的操作. 不根据文件看起来可用而猜测未知状态已完成.

**External Action**: 需要仓库之外权限或人工核实的动作, 例如撤销已泄漏 credential 或解决不明 ownership.
