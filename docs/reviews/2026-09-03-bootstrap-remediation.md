---
title: Bootstrap Code Review Remediation
status: active
owner: repository-maintainers
last_updated: 2026-09-04
related:
  - ../design/bootstrap-hardening.md
  - ../architecture/bootstrap.md
  - ../operations/installation.md
---

# Bootstrap Code Review Remediation

## Scope

本记录对应 2026-09-03 对 Bootstrap, dotfiles 和 Shell helper 的 code review. 它记录发现如何被关闭, 但不替代当前 architecture 和 operations 文档.

## Remediation status

| Finding | Resolution | Status |
|---|---|---|
| Plaintext token in Fish config | 从工作树和远程 `master` 全部可达历史删除, 增加 ignored local-secret convention | Repository cleanup complete, external revocation required |
| Failures masked by success output | 独立 strict-mode stages, top-level error trap | Complete |
| Brew repeated installation | Batch installed/outdated inventory and three-state reconciliation | Complete |
| Homebrew repeatedly warns about untrusted taps | Exact Formula/Cask trust allowlist, one trust inventory, trust-before-package ordering | Complete |
| `brew shellenv` follows caller Fish shell inside Bash stage | Force Bash-formatted shell environment during Homebrew activation | Complete |
| Global Codex Hook exits with code 127 | Remove orphan `.superset` Hook and all Superpowers plugin, Skill, Hook, override, and cache state | Complete |
| Invalid `adsf` package | 从 Formula manifest 删除 | Complete |
| Stow and mise ordering | Formula stage precedes shell/dotfiles, explicit mise activation | Complete |
| Oh My Zsh `.zshrc` conflict | 移除 remote installer, 使用 pinned repository checkout | Complete |
| Wrong Neovim and Zed `git pull` directory | Neovim 归属 stow, Zed 使用 verified explicit repository path | Complete |
| Ambient Mise project mutation | Runtime 与 global CLI 使用 repository-managed global config | Superseded by ADR 0005 |
| Mutable remote installers and `@latest` | 工具迁移到 Homebrew 或固定 package version, Homebrew installer 固定 commit | Complete |
| `gtest` pops unrelated stash | 使用 detached temporary worktree 执行 staged snapshot, 不操作 caller stash | Superseded by ADR 0006 |
| Remote branch deleted before replacement push | 先 push replacement, 再删除旧 remote branch | Complete |
| Hard-coded user and ChatGPT paths | 使用 `${HOME}` 并修复 `.app` bundle path | Complete |
| Permission-bypass aliases are implicit | 重命名为显式 `*-unsafe` aliases | Complete |
| Missing automated checks | 增加 isolated test runner and policy checks | Complete |

## Residual external actions

1. 在 Skill Hub 服务端撤销旧 token 并生成新 token.
2. 将新 token 只写入 ignored local-secret file 或外部 secret manager.
3. 通知其他 clone 不得 merge 旧 history, 并根据 repository 暴露范围检查 fork 和平台 cache.

Repository history rewrite 已单独完成. 剩余外部动作不能由普通代码补丁安全完成, 不应伪装成已修复.
