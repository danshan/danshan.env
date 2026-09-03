---
title: Installation Runbook
status: active
owner: repository-maintainers
last_updated: 2026-09-04
related:
  - ../architecture/bootstrap.md
  - ../adr/0001-bash-bootstrap-and-state-reconciliation.md
  - ../reviews/2026-09-03-bootstrap-remediation.md
---

# Installation Runbook

## Preconditions

- macOS.
- Command Line Tools 提供的 Git, Curl 和 Bash.
- 对 Homebrew, GitHub 和所需 package registry 的网络访问.
- 目标 dotfile 不存在, 或已经由本仓库的 stow symlink 管理.

## Install or update

```bash
git clone git@github.com:danshan/danshan.env.git "$HOME/.config/danshan.env"
cd "$HOME/.config/danshan.env"
bash install.sh
```

重复执行相同命令即可更新. Homebrew reconciliation 行为如下:

- 已授权的第三方 Formula/Cask: 输出 skip, 不重复写入 trust state.
- 未授权但出现在 `defaults/brew_trust.txt` 的第三方 Formula/Cask: 仅授予该 package trust.
- 已安装且不是 outdated: 输出 skip, 不下载或重装.
- 已安装且 outdated: 执行 upgrade.
- 未安装且 App 不存在: 执行 install.
- 未安装但 App 已存在: 默认保留外部安装并 skip; 只有 manifest 显式声明 `adopt` 时才请求 Homebrew 接管.

完整执行只刷新一次 Homebrew metadata. 在离线诊断或明确接受本地 metadata 可能过期时, 可以跳过刷新:

```bash
DANSHAN_SKIP_BREW_UPDATE=1 bash install.sh
```

跳过 refresh 会降低 latest 判断的时效性, 不应作为常规默认值.

若 Homebrew 报告 untrusted tap, 不要设置 `HOMEBREW_NO_REQUIRE_TAP_TRUST` 或执行 whole-tap trust. 将需要的 fully-qualified package 以正确类型加入 `defaults/brew_trust.txt`, 然后重试. 可用以下命令审计当前授权:

```bash
brew trust --json=v1
```

正常情况下, `muxy-app/tap/muxy` 只出现在 `casks` 数组中. Trust stage 必须早于 Formula/Cask inventory, 因而后续批量状态读取不会重复产生同一 tap warning.

Context7 的交互配置默认不在 Bootstrap 中运行. 需要时显式启用:

```bash
DANSHAN_RUN_CONTEXT7_SETUP=1 bash install.sh
```

## Local secrets

复制示例文件并只在本机填写凭据:

```bash
cp \
  dotfiles/fish/.config/fish/conf.d/secrets.local.fish.example \
  dotfiles/fish/.config/fish/conf.d/secrets.local.fish
chmod 600 dotfiles/fish/.config/fish/conf.d/secrets.local.fish
```

`secrets.local.fish` 已被 Git ignore, Fish 会从 stow 后的 `conf.d` 自动加载. 不得对真实文件使用 `git add -f`.

## Conflict handling

Stow 遇到普通文件或指向其他来源的 symlink 时会失败. 安装脚本不会自动覆盖. 处理前先确认内容和所有权, 将旧文件移动到明确的备份路径, 然后重新执行安装.

Homebrew inventory 中缺失的 App Cask 若已存在于 `/Applications`, Bootstrap 默认保留现有 App, 不尝试修改其 ownership 或 metadata. `defaults/brew_casks.txt` 第三列可显式设为 `adopt`; 此时 Homebrew 可能执行 bundle 比较和 `xattr` metadata 写入. 任一步失败都会终止安装且不覆盖 App. 应先确认 App 来源, macOS App Management 权限和数据备份, 不要使用 `--force` 绕过检查.

Pinned Git dependency 存在未提交修改时会失败. 应先提交, stash 或明确丢弃这些修改, 再重试. 安装脚本不会替操作者清理 worktree.

Zed config path 存在但 origin 不匹配时会失败. 应人工确认正确 repository, 不得直接修改脚本绕过 origin 验证.

## Codex hook ownership

本仓库不安装或管理全局 Codex Hook. 若未来需要 Hook, 必须放入 repository-local `.codex/hooks.json`, 并调用仓库内可执行文件. Hook 不得依赖 interactive Shell 才存在的 alias 或 PATH, 也不得引用用户绝对路径.

`Hook failed` 且 exit code 为 `127` 表示 Hook command 或其子命令不存在. 应先检查 active Hook command 的目标是否存在且可执行, 再检查非交互环境的 PATH. 2026-09-04 已删除指向不存在 `.superset/hooks/notify.sh` 的旧全局 Hook 配置, 并移除 Superpowers plugin, Skills, Hook 和 cache.

## Credential incident

旧的 `SKILL_HUB_TOKEN` 曾进入 Git 历史. 2026-09-04 已从远程唯一 advertised branch `master` 的全部可达历史中删除, 远程 tip 从 `a445d8a` 改写为 `a8090d6`.

历史清理不等于 credential revocation. 旧 token 必须在对应服务端撤销且永不复用, 新 token 只能写入 ignored local-secret file 或外部 secret manager. 若该 repository 曾公开, 还应检查 fork, pull request ref 和平台 cache 的残留风险.

历史清理改变了全部受影响 commit ID. 其他 clone 不应把旧 history merge 回来. 最安全的恢复方式是先备份尚未提交的工作树, 然后重新 clone repository, 再以 patch 形式重新应用仍需要的本地修改.

## Failure recovery

顶层显示 `Installation failed` 时, 使用第一个失败阶段的日志定位问题. 修复外部状态后重新运行完整入口. 已满足的 Homebrew package, pinned repository 和 global CLI 会跳过, 不需要手工从中断阶段继续.
