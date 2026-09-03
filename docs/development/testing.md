---
title: Testing Guide
status: active
owner: repository-maintainers
last_updated: 2026-09-03
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
| `test_brew_reconcile.sh` | Formula/Cask missing, current, outdated, App Cask adoption, tap name normalization, bounded inventory calls |
| `test_install_failure.sh` | Stage failure propagation and success-banner suppression |
| `test_gtest_stash.sh` | No-staged-change rejection and existing stash preservation |
| `test_repository_policy.sh` | Shell syntax, Fish syntax when available, secret markers, mutable package references, remote script pipelines |

新增 Bootstrap 分支时必须扩展现有测试或增加独立 test file. 测试文件命名为 `test_<behavior>.sh`, 并由 `tests/run.sh` 自动发现.

## Stub design

Package manager 测试通过 Shell function 或临时 executable 替代外部命令. Stub 必须记录完整参数, 使测试能够同时验证动作和调用次数. 不允许只断言最终 exit code 而忽略错误分支执行了什么命令.
