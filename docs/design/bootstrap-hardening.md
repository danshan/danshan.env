---
title: Bootstrap Hardening Design
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../adr/0001-bash-bootstrap-and-state-reconciliation.md
  - ../adr/0002-transactional-homebrew-font-migration.md
  - ../adr/0003-platform-gated-homebrew-casks.md
  - ../adr/0004-transactional-homebrew-app-migration.md
  - ../standards/documentation.md
---

# Bootstrap Hardening Design

## Goal

将安装过程从命令列表改造成可重复执行的状态收敛流程. 每个阶段先检查当前状态, 再执行最小变更, 最后由顶层统一传播失败.

## Non-goals

- 不在安装脚本中自动重写 Git 历史.
- 不自动撤销第三方服务中的凭据.
- 不保证 Homebrew 仓库快照级重现. Formula 和 Cask 跟随刷新后的 Homebrew metadata, 但不会重复安装已满足项.

## Execution model

顶层入口使用 Bash 3.2, 每个阶段作为独立进程运行. 阶段之间不依赖隐式 Shell 状态, 所需 PATH 和配置必须在各阶段内显式建立.

执行顺序如下:

1. Install or activate Homebrew, then refresh metadata once.
2. Reconcile explicit package-level trust grants for third-party Homebrew sources.
3. Reconcile required formulae, including `stow`, `mise`, and `uv`.
4. Reconcile casks.
5. Install pinned shell frameworks without creating unmanaged dotfiles.
6. Apply stow packages and update managed Git repositories with explicit working directories.
7. Activate mise in the current stage, reconcile pinned runtimes, then install pinned global CLI packages.

顶层只有在全部阶段成功后才输出完成提示. 任一阶段失败立即返回非零状态.

## Homebrew reconciliation

Third-party trust 是 installation inventory 的前置状态. `defaults/brew_trust.txt` 逐项声明 `formula|fully-qualified-name` 或 `cask|fully-qualified-name`. Bootstrap 读取一次 `brew trust --json=v1`, 已存在的 grant 明确 skip, 只写入 missing grant. Whole-tap trust 和禁用 trust check 不属于允许状态.

每类资源只读取两份批量状态:

- Installed Formulae or Casks.
- Outdated Formulae or Casks.

Manifest 中的每个条目按以下规则处理:

| State | Action |
|---|---|
| Platform Constraint not satisfied | Skip before mutation |
| Missing, App absent | `brew install` |
| Missing, App present, `preserve` | 保留外部 App 并 skip Homebrew adoption |
| Missing, App present, `adopt` | `brew install --cask --adopt` |
| Missing, App present, `migrate` | 进入 per-cask snapshot, install, verify transaction |
| Missing, font cask, `migrate` | 进入 batch snapshot, install, verify transaction |
| Installed and outdated | `brew upgrade` |
| Installed and current | Skip with an explicit log message |

Tap-qualified 名称比较时使用末段 token 的 lowercase 规范化形式, 避免已安装的 tap package 被重复识别为 missing. Cask 的 Homebrew ownership 以 inventory 为准, App availability 由 manifest 中的 App 名称辅助判断. Manifest 第三列是 existing artifact policy, 默认 `preserve`; `adopt` 只允许 Homebrew 接管内容相同的既有 App artifact, `migrate` 则显式授权可恢复的 ownership transition. Adoption failure 不会自动升级为 migration, 且所有 policy 都禁止通过 `--force` 覆盖用户已有 App.

Manifest 第四列是 optional `minimum_macos_major`. Bootstrap 在 Cask stage 读取一次 numeric product-version major. 空值表示没有额外 gate; 正整数表示当前 major 必须大于或等于该值. 不兼容项计入 skip, 不执行 install, upgrade, adoption 或 migration. 非数字, 0, 缺失 `sw_vers` 或读取失败属于 invalid Observed/Desired State, 必须在 Cask mutation 前终止. Homebrew command failure 不得被重新分类为 platform skip.

### Transactional font migration

无 App name 的 `migrate` 适用于纯 font cask. 所有 missing font `migrate` 条目形成单一 transaction:

1. Inspect Homebrew JSON metadata, 验证每个 artifact 都是 user Fonts directory 的直接 font target.
2. Classify 每个 exact target 为 present 或 absent, 将清单写入 Migration Snapshot.
3. Move present target 到 snapshot, 然后以普通 `brew install --cask` 安装全部 missing font cask.
4. Verify 全部 cask inventory 和全部 target.
5. 成功时保留 snapshot 并标记 `completed`; 失败时卸载本批次 cask, 隔离新 artifact, 恢复 present target.

Transaction 不使用 filename glob 推导 ownership, 不删除 snapshot, 不使用 `--force`, 也不把普通 App cask 隐式升级为 migration policy. `rolled-back` 表示先前 Observed State 已恢复; `rollback-incomplete` 要求操作者检查 snapshot 后再继续 Bootstrap.

### Transactional application migration

带 App name 的 `migrate` 是单 Cask transaction. Bootstrap 只处理 manifest 声明的精确 `/Applications/<name>.app`, 并按以下顺序收敛:

1. Validate App name, 创建唯一 snapshot 并记录 package, target 与原始 presence.
2. Move 原 bundle 到 snapshot, 再以普通 `brew install --cask` 安装当前 Cask.
3. Verify Homebrew inventory 已登记且 App target directory 已存在.
4. 成功时保留 snapshot; 失败时卸载已登记 Cask, 隔离新 artifact, 恢复原 bundle.

该 transaction 不迁移 App 外部的 preferences, caches 或 user data, 因为这些内容不属于 Cask App artifact. 每个 App 独立提交或回滚, 不与 font family 的 batch atomicity 合并.

## Tool pinning

Runtime 和全局 CLI 版本集中保存在 `defaults/tool_versions.env`. 脚本不得使用 `@latest`. 更新版本时必须同时更新 operations 文档和 remediation review.

Homebrew package 版本由 Homebrew metadata 管理. 这是有意选择的滚动更新边界, 与固定版本的语言 runtime 和 agent CLI 分离.

## Credential boundary

仓库不保存凭据. Fish 的机器本地凭据放入被忽略的 `dotfiles/fish/.config/fish/conf.d/*.local.fish`, 由 Fish 自动加载. 示例文件只能包含占位符.

已经进入 Git 历史的凭据必须先在服务端撤销. 历史清理是需要协调的独立破坏性操作, 不由普通安装流程触发.

## Failure and recovery

- 网络, package manager, Git 或 stow 失败必须终止当前阶段.
- Git 更新只允许 fast-forward, 避免安装脚本隐式创建 merge commit.
- 已存在但不是 Git worktree 的目标目录必须 fail closed.
- 已存在且未由 stow 管理的目标文件必须报告冲突, 不自动覆盖.
- App 或 font migration failure 必须在当前 Cask stage 内完成 Rollback; Rollback 不完整时报告 snapshot path 并停止.
- 重试安装前先修复失败原因, 再重新执行顶层入口. 已满足步骤会自动跳过.

## Verification

测试使用临时 `HOME` 和 stub commands, 不访问网络, 不调用真实 Homebrew, 不修改用户配置. 关键覆盖包括:

- Formula/Cask 的 missing, current 和 outdated 分流.
- Existing App 的 `preserve`, identical `adopt` 与 differing `migrate` 分流, 以及 App migration 的 install/verify failure Rollback.
- Formula/Cask trust 的 missing, current 和 command failure 分流, 以及 whole-tap bypass policy.
- 任一阶段失败时顶层非零退出且不输出完成提示.
- Git 更新使用正确工作目录和 fast-forward-only 参数.
- mise 配置全部使用显式 global scope.
- 无 staged changes 时 `gtest` 不消费已有 stash.
