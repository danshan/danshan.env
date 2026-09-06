# Environment Bootstrap

本上下文描述个人开发环境如何从主机现状收敛到仓库声明的目标状态. 它只定义项目语言, 不记录具体命令或实现选择.

## Language

**Bootstrap**:
从一台未配置或部分配置的主机开始, 建立完整目标环境的过程.
_Avoid_: Installer, setup script

**Desired State**:
仓库声明并负责维护的工具, 版本, 配置和关系集合.
_Avoid_: Install list, expected setup

**Observed State**:
执行开始时从主机读取到的资源和版本事实.
_Avoid_: Existing setup, local state

**Reconciliation**:
比较 Desired State 与 Observed State, 并只执行使两者一致所需变更的过程.
_Avoid_: Reinstall, setup

**Satisfied Resource**:
已经符合 Desired State, 因而必须跳过变更的资源.
_Avoid_: Latest item, existing item

**Missing Resource**:
Desired State 要求但 Observed State 中不存在的资源.
_Avoid_: New item

**Outdated Resource**:
Observed State 中存在, 但版本低于 Desired State 或受信 metadata 所声明当前版本的资源.
_Avoid_: Old item, update candidate

**Platform Constraint**:
Managed Resource 成为当前主机 Desired State 所必须满足的操作系统版本条件. 不满足时资源应明确 skip, 而不是尝试变更后忽略失败.
_Avoid_: Install workaround, ignored error

**Managed Resource**:
所有权和更新策略由本仓库明确声明的资源. 自动变更只允许作用于 Managed Resource.
_Avoid_: Config file, installed thing

**Migration Snapshot**:
在改变外部 artifact 所有权之前, 按精确目标清单创建并持续保留的可恢复副本和状态记录.
_Avoid_: Temp backup, copied files

**Ownership Migration**:
通过显式 policy 将外部 artifact 转换为 Managed Resource 的 transaction. 必须先创建 Migration Snapshot, 再执行 install, verify 和必要的 Rollback.
_Avoid_: Force install, overwrite

**Rollback**:
批次 reconciliation 失败后, 撤销本批次新建的 Managed Resource, 保留失败产物, 并从 Migration Snapshot 恢复先前 Observed State 的过程.
_Avoid_: Cleanup, retry

**Bootstrap Stage**:
具有独立前置条件, reconciliation 范围和失败边界的一组操作.
_Avoid_: Step, script

**Preflight**:
在任何 mutation 前验证平台, manifest, Shell 和配置来源的只读阶段.
_Avoid_: Setup check, best-effort validation

**Execution Plan**:
只读计算并展示 Reconciliation 预计动作的执行模式, 不改变 Managed State.
_Avoid_: Dry install, partial apply

**Tool Owner**:
对工具的安装位置, 版本选择, 更新和卸载承担唯一责任的 package manager 或仓库层.
_Avoid_: Preferred installer, available manager

**Installation Backend**:
Mise 为获取某类工具调用的上游 package transport. Backend 不取得 Tool Owner 身份.
_Avoid_: Package owner, second manager

**Migration Lock**:
保护 Cask Ownership Migration 的单主机互斥记录. 活跃 owner 阻止并发执行, stale owner 可在验证后恢复.
_Avoid_: Temp directory, process marker

**Interrupted Migration**:
进程在 Migration Snapshot 已建立但尚未进入终态时退出所留下的可恢复 transaction.
_Avoid_: Failed install, incomplete backup

**External Action**:
需要仓库权限边界之外的服务端权限, 协作者协调或破坏性确认才能完成的动作.
_Avoid_: Manual fix, follow-up
