---
title: Testing Guide
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../standards/documentation.md
---

# Testing Guide

## Test boundary

自动化测试不得访问真实网络, 不得调用真实 Homebrew installation, 不得写入操作者 `HOME`. 每个有状态测试必须使用 `mktemp` 创建隔离目录, 并通过 trap 清理.

## Commands

执行完整测试:

```bash
tests/run.sh
```

执行 Shell syntax validation:

```bash
bash -n install.sh scripts/*.sh tests/*.sh
```

如果本机安装了 ShellCheck, 执行静态检查:

```bash
shellcheck install.sh scripts/*.sh tests/*.sh
```

## Coverage contract

| Test | Coverage |
|---|---|
| `test_brew_app_migration.sh` | Exact App target, successful ownership transition, persistent snapshot, repeat execution, absent/current/outdated routing, install and verify failure, failed artifact preservation and Rollback |
| `test_brew_font_migration.sh` | Exact target validation, batch success, persistent snapshot, repeat execution, installed/outdated routing, partial install failure, artifact preservation and Rollback |
| `test_brew_reconcile.sh` | Formula/Cask missing, current, outdated, empty inventory, external App preservation, explicit adoption, platform below/at minimum, invalid platform value, `sw_vers` failure, tap name normalization and bounded inventory calls |
| `test_brew_trust.sh` | Package-level trust missing/current/empty state, exact package qualification, error propagation |
| `test_install_failure.sh` | Stage failure propagation and success-banner suppression |
| `test_gtest_stash.sh` | No-staged-change rejection and existing stash preservation |
| `test_repository_policy.sh` | Shell syntax, Fish syntax when available, secret markers, mutable package references, remote script pipelines |

新增 Bootstrap 分支时必须扩展现有测试或增加独立 test file. 测试文件命名为 `test_<behavior>.sh`, 并由 `tests/run.sh` 自动发现.

Font migration 测试必须把 Fonts directory 和 backup root 放在临时 HOME root 下, 并作为参数显式传入 helper, 不得写入调用者的真实 `HOME`. Homebrew metadata, install, list 和 uninstall 全部由 stub 提供; 至少断言原文件恢复内容, failed-install artifact 保留位置, batch counter 和 `state` marker.

App migration 测试必须覆盖临时 Applications directory 与显式 backup root, 不得读写真实 `/Applications`. 至少证明 differing existing bundle 使用普通 install 而非 `--adopt`, original snapshot 在成功后保留, install failure 与 verify failure 均恢复旧 bundle, 新 artifact 被隔离, current rerun 不产生 mutation, outdated 仍走 upgrade, absent target 仍走普通 install.

Platform Constraint 测试必须 stub `sw_vers`, 并证明 below-minimum 不产生 Homebrew mutation, at-minimum 正常 reconciliation, installed/outdated 仍受 gate 保护, invalid major 和 command failure 返回非零状态. 不允许用忽略 `brew install` failure 代替 preflight gate.

## Stub design

Package manager 测试通过 Shell function 或临时 executable 替代外部命令. Stub 必须记录完整参数, 使测试能够同时验证动作和调用次数. 不允许只断言最终 exit code 而忽略错误分支执行了什么命令.
