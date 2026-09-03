---
title: Bootstrap Hardening Design
status: active
owner: repository-maintainers
last_updated: 2026-09-04
related:
  - ../adr/0001-bash-bootstrap-and-state-reconciliation.md
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
| Missing, App absent | `brew install` |
| Missing, App present, `preserve` | 保留外部 App 并 skip Homebrew adoption |
| Missing, App present, `adopt` | `brew install --cask --adopt` |
| Installed and outdated | `brew upgrade` |
| Installed and current | Skip with an explicit log message |

Tap-qualified 名称比较时使用末段 token 的 lowercase 规范化形式, 避免已安装的 tap package 被重复识别为 missing. Cask 的 Homebrew ownership 以 inventory 为准, App availability 由 manifest 中的 App 名称辅助判断. Manifest 第三列是既有 App 策略, 默认 `preserve`; 只有显式声明 `adopt` 的条目才允许 Homebrew 接管既有 artifact. App 不存在时始终执行普通 install. Adoption 校验或 post-install metadata 写入失败时保持失败, 不允许通过 `--force` 覆盖用户已有 App.

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
- 重试安装前先修复失败原因, 再重新执行顶层入口. 已满足步骤会自动跳过.

## Verification

测试使用临时 `HOME` 和 stub commands, 不访问网络, 不调用真实 Homebrew, 不修改用户配置. 关键覆盖包括:

- Formula/Cask 的 missing, current 和 outdated 分流.
- Formula/Cask trust 的 missing, current 和 command failure 分流, 以及 whole-tap bypass policy.
- 任一阶段失败时顶层非零退出且不输出完成提示.
- Git 更新使用正确工作目录和 fast-forward-only 参数.
- mise 配置全部使用显式 global scope.
- 无 staged changes 时 `gtest` 不消费已有 stash.
