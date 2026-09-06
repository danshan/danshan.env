---
title: Bootstrap Testing Guide
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../reviews/2026-09-06-native-bootstrap.md
---

# Bootstrap Testing Guide

## Environment and command

测试运行于 macOS, 使用系统 Bash 3.2, Git, Ruby, plutil, lockf, sandbox-exec, 以及已安装的 Fish, Mise 和 Python 3.11 及以上. Python 标准库用于配置/锁文件校验和 PTY 输出测试, 不是 Bootstrap 运行依赖. 测试不得执行真实安装或修改用户配置.

```bash
bash tests/run.sh
```

测试创建临时 HOME 和 XDG 目录; 包管理器安装, 卸载, trust 和 Stow 失败路径使用 stub. Git 行为使用临时本地 repository. Mise 的配置发现测试调用真实查询命令, 在只读, 离线沙箱内验证结果和文件摘要; lockf 测试使用系统内核锁.

`check` 的系统沙箱不能在某些外层限制环境中建立. 如果测试报告 `sandbox_apply: Operation not permitted`, 应在允许建立 Seatbelt profile 的执行环境运行整套测试, 同时保留临时 HOME 和 stub. 不应跳过只读验证来把失败改成成功.

## Coverage

| Test | Contract |
|---|---|
| `test_repository_policy.sh` | 逐文件 Shell 语法, 原生清单 owner, latest/lock 一致性, 平台条件, 精确信任例外和 ADR 0009 Trust Hold |
| `test_configuration.sh` | 文件格式, 错误字段, 重复 owner/target, 安装器数据不执行为代码, 迁移许可整体校验 |
| `test_adapters.sh` | Bundle 实时 install/check, update/install/verify 失败状态及停止后续步骤, update skip, 环境 override 清除, 激活失败, Stow simulate, 表格校验 |
| `test_homebrew_output.sh` | PTY 和重定向输出, 命令结束前透传无换行 stdout/stderr, 保留 TTY 与退出码, 耗时及失败无完成提示 |
| `test_install_execution.sh` | 完整隔离入口, 重复执行, check 无文件变化, stage/from, 失败传播, 无隐式恢复 |
| `test_git_repositories.sh` | missing/current/outdated pinned checkout, 前向更新, dirty, origin, worktree root 和查询失败 |
| `test_mise_isolation.sh` | cwd/祖先/全局/system/env 配置隔离, 真实路径 ceiling, 只读查询, Stow directory folding |
| `test_lock.sh` | 锁互斥, 持有者退出, 首次 check 不建状态目录, 旧 PID lock |
| `test_migrations.sh` | App/font commit, 失败, 原件与失败产物保留, batch rollback, 中断重复恢复, 精确目标和 legacy snapshot |
| `test_stow_migration.sh` | 已知旧配置子集, snapshot move 失败, install/verify failure, 已有 lock ownership, 未知冲突保留, 重复恢复 |
| `test_gtest_worktree.sh` | Fish Git helper 不误恢复旧 stash 或覆盖 worktree |
| `test_docs.sh` | 文档元数据, 命名, 导航和内部链接 |

失败注入必须在 `if` 或 `expect_failure` 等调用环境中执行, 覆盖 Bash 在条件函数调用时禁用 `errexit` 的行为. 关键持久化操作需要显式检查退出状态, 不能只依赖 `set -e`.

Cask stub 的 uninstall 必须真的删除测试 artifact, 这样才能发现保存失败产物顺序错误. 测试不得只删除 inventory marker 而保留 artifact, 造成虚假的恢复保证.

## Extending tests

新增普通应用或 CLI 通常只改变原生配置, 用结构与 lock 一致性检查验证, 不为每个 token 写一次重复安装测试. 新字段或条件应覆盖合法值, 非法值和错误传播; 新 ownership migration 则必须覆盖精确路径, success, repeat, install failure, verify failure, original/failed artifact preservation, rollback 和 rollback-incomplete.

Shell 语法检查必须逐文件调用 `/bin/bash -n`, 一次传入多个文件只会检查第一个. 修改文档链接或配置格式时同步更新对应检查. 完成测试后审查 `git diff --check` 和工作树, 排除临时文件, 未登记文档和凭据.

Trust Hold 的固定版本属于显式安全约束, 需要检查 declaration 与 lockfile 都指向审查版本, 且未增加 trust exception. 这类检查不代替真实发布证据审查, 也不把具体版本当作普通 reconciliation 状态机. 解除 Hold 时同步更新 ADR, 配置和对应约束.

这些测试验证仓库的编排与边界, 不代表在真实机器上完成安装. 上游下载, 系统权限提示, App 启动和字体显示应在操作者执行真实安装时验证.
