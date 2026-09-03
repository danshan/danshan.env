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

**Managed Resource**:
所有权和更新策略由本仓库明确声明的资源. 自动变更只允许作用于 Managed Resource.
_Avoid_: Config file, installed thing

**Bootstrap Stage**:
具有独立前置条件, reconciliation 范围和失败边界的一组操作.
_Avoid_: Step, script

**External Action**:
需要仓库权限边界之外的服务端权限, 协作者协调或破坏性确认才能完成的动作.
_Avoid_: Manual fix, follow-up
