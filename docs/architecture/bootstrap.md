---
title: Native Bootstrap Architecture
status: active
owner: repository-maintainers
last_updated: 2026-09-07
related:
  - ../adr/0008-native-package-managers-and-explicit-migrations.md
  - ../adr/0011-perl-flock-helper.md
  - ../operations/installation.md
  - ../development/testing.md
---

# Native Bootstrap Architecture

## Ownership and declarations

| Owner | 职责 | 唯一清单 |
|---|---|---|
| Homebrew | 主机 CLI, Shell 组件, App, 字体, 包级 trust | 根目录 `Brewfile` |
| Mise | runtime, 构建工具, 开发 CLI, 包括 NPM/Aqua backend | `dotfiles/mise/.config/mise/config.toml` 和相邻 `mise.lock` |
| Bun / NPM | 具体项目的 dependency | 各项目 manifest 和 lockfile |
| Stow | 从仓库部署 dotfiles | `config/dotfiles.tsv` |
| Git | dotfiles 使用的外部配置和插件仓库 | `config/repositories.tsv` |
| Bootstrap | 跨阶段顺序, 精确链接, 显式 ownership migration | `config/links.tsv`, `config/migrations.txt` |

Starship 属于主机 Shell 工具, 由 Homebrew 管理. `1password-cli` 使用 Cask. 开发 CLI 可以声明 `latest`, runtime 保留明确版本; 解析结果提交到 `mise.lock`. NPM backend 的原生 lock 记录版本和选项, 不提供与二进制 backend 相同的跨平台 URL/checksum 锁定强度.

候选 NPM release 触发 trust downgrade 时保持失败传播, 不自动修改 `trust_policy_excludes` 或 installer. 已有可信版本可通过明确 Version Selector 建立 Trust Hold, 并同步原生 lockfile, 安全约束测试和 ADR. 当前 Playwright 的固定版本与解除条件见 [ADR 0009](../adr/0009-playwright-cli-trust-hold.md).

## Modules

- `install.sh`: 公开命令入口, 为 `check` 建立 macOS 只读沙箱.
- `scripts/bootstrap.sh`: 参数, Preflight, 互斥锁, 阶段顺序和失败传播.
- `scripts/homebrew.sh`: Homebrew 激活及原生 Bundle 调用; 首次安装委托给 `setup_homebrew.sh`.
- `scripts/repositories.sh` 和 `scripts/lib/git.sh`: 读取仓库/链接清单, 验证 identity, clone 或 fast-forward.
- `scripts/dotfiles.sh`: 读取 package 清单并调用 Stow.
- `scripts/mise.sh`: 隔离配置发现, 验证 Stow 来源, 调用原生安装与查询.
- `scripts/migrations/runner.sh`: 显式迁移许可和 pending snapshot 检查.
- `scripts/migrations/casks.sh`: App transaction 和字体 batch transaction.
- `scripts/migrations/legacy-mise.sh`: 旧 Mise global config 的单一兼容适配器.
- `scripts/migrations/transaction.sh`: 原子状态, 锁, artifact 保留, 校验和恢复.
- `scripts/lib/core.sh`: 路径, 日志和数据格式的基础函数.

共享代码按职责归属模块. 不保留旧 `common.sh` facade, 不复制包管理器的普通 inventory, outdated 或升级调度逻辑.

## Execution

`apply` 依次执行 `homebrew`, `repositories`, `dotfiles`, `mise`. Preflight 在变更前验证 macOS, Shell, 必需文件, 表格结构和已有 Git identity; 原生配置由对应管理器解析. `recover` 不依赖普通安装清单的有效性, 只处理已有 snapshot.

Homebrew stage 显式刷新 metadata, 然后执行 `brew bundle install --verbose` 和 `brew bundle check --verbose`. Bundle 使用明确的 `--file`, 清除调用者的 Bundle skip/upgrade override, Cask options 和 trust bypass. 第三方信任声明在 Brewfile 的具体 `brew/cask` 行中, 不信任整个 tap. 平台条件使用 Brewfile 原生 Ruby DSL. Thaw 在 macOS 14 至 25 使用 `danshan/env/thaw@1`, macOS 26 及以上使用官方 `thaw`; 更旧系统不声明. 不通过吞掉安装错误推断平台兼容性.

Compatibility Cask 定义位于 `Casks/`, 固定 upstream version, URL 和 SHA-256. 旧平台的 Brewfile 通过原生 `tap` 从当前仓库创建 `danshan/env` 独立 clone, 再对具体 Cask 声明 trust. Homebrew 只消费源 Git 仓库中的已提交内容, 更新仍由原生 `brew update` 完成. Bootstrap 不复制 Cask 文件, 不链接源工作树为 tap, 不增加 package 安装分支. 维护与版本切换约束见 [ADR 0010](../adr/0010-local-compatibility-casks.md).

`scripts/homebrew.sh` 的步骤包装器直接调用命令, 继承 stdout/stderr 和 TTY, 仅在调用前后输出状态和耗时, 并保留命令退出码. Bundle 的 `--verbose` 启用子命令实时输出; metadata update 和迁移 Cask install 不使用 `--quiet`. 不捕获后集中打印安装日志, 不解析下载文本或模拟百分比. 动态下载进度由 Homebrew 按实际终端条件呈现, Bootstrap 验证成功后才报告整体完成.

Git pinned checkout 只允许向目标 commit 的前向更新. Tracking checkout 使用 upstream 的 `pull --ff-only`; dirty tracking checkout 保留并报告跳过. 所有 existing target 必须是精确 worktree root, 并匹配 origin. Stow 只部署登录 Shell 对应的 package 和 `all` package; 不覆盖冲突文件.

Mise 命令在仓库的真实路径执行, 清除调用者 `MISE_*`, 设置仓库 global config, 空 system TOML 和目录搜索 ceiling, 禁用自动环境选择, idiomatic version files 和自动安装. 安装前验证部署的 config 和 lockfile 都指向仓库来源, 包括 Stow directory folding. Shell 日常使用 Mise 原生项目发现功能, Bootstrap 的隔离不改变项目内的配置优先级.

## Check boundary

公开的 `install.sh check` 用 `config/check.sb` 禁止本进程树写入文件和访问网络, 仅允许 `/dev/null` 输出. 该边界覆盖 package manager 的隐式 cache/迁移写入, 不依赖命令名称是否包含 dry-run. 沙箱不可用时返回失败, 不退回非隔离执行. `scripts/bootstrap.sh` 和模块是内部实现, 不作为绕过公开入口的运行方式.

`check` 使用 Homebrew Bundle check, Stow simulate, Mise 当前状态和 `install --dry-run-code`. 缺失管理器报告 UNKNOWN, 普通资源问题汇总到剩余阶段; Preflight 或锁错误立即失败. Git tracking 只报告本地状态, 不判断远端新提交. Homebrew 使用本地 metadata, Mise 使用仓库 lockfile, 因而此命令不证明远端版本或下载可用性.

## Migration boundary

只有 `migrate` 才读取迁移许可并启动 transaction. 所有 Cask 先确认属于当前平台有效的 Brewfile; 第三方包需已有精确 trust. 已由 Homebrew 管理的 Cask 跳过. App/旧配置按清单顺序迁移, 所有 eligible font Cask 构成最后的一个 batch. 各 transaction 独立提交, 后续 transaction 失败不撤销先前已完成的 transaction.

App target 是 `/Applications/<name>.app`; font target 只接受 Homebrew metadata 中 `${HOME}/Library/Fonts` 的直接 `.ttf/.otf` 文件, 拒绝混合 artifact, 重复 target 和路径穿越. Snapshot 移动要求原件和备份父目录处于同一 filesystem, 以保持 rename 的原子性; 跨卷目标在移动前拒绝. App bundle 和字体先移入 snapshot, 安装后验证 inventory 和精确 target. 回滚先复制失败产物, 再卸载本次已登记 Cask, 最后复制恢复原件. 原件始终保留在 snapshot, 使恢复中再次中断时仍有依据.

旧 Mise config 仅接受一个 `[tools]` section 中简单 key/version 赋值的可验证子集, 拒绝未知配置. 显式迁移保留旧配置和原 lockfile ownership, 再由 Stow 接管 config 与 lockfile. 回滚不覆盖执行期间出现的未知文件.

变更操作通过同一个内核 `flock(2)` 锁串行化. 仓库 Perl helper 对 Bash 已打开并继承的文件描述符非阻塞加锁, 锁竞争与 helper 故障使用不同退出状态. `check` 只读持有已存在的锁文件, 首次检查不创建锁文件. 锁文件 inode 保留, 锁由继承的文件描述符持有, 随进程树退出释放. 旧 PID lock 中可验证的活跃 owner 仍阻止操作; 无 PID 或结构异常的旧 lock fail closed. 兼容性决策见 [ADR 0011](../adr/0011-perl-flock-helper.md).

Snapshot 使用 `format=2`, `manifest.txt` 和原子更新的 `state`. 已存在的格式 1 snapshot 继续接受严格路径验证. 无 state 的旧字体 snapshot 只有在清单, 精确 target, 保留原件和 Homebrew ownership 均有效时才只读认可为已完成. `rollback-incomplete` 和未知状态需要人工处理. `apply/check` 仅报告 pending, `recover` 才恢复可识别的中断.
