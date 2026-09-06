---
title: Perl Flock Helper
status: active
owner: repository-maintainers
last_updated: 2026-09-07
related:
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - ../development/testing.md
  - 0008-native-package-managers-and-explicit-migrations.md
---

# ADR 0011: Perl Flock Helper

## Context

Bootstrap 需要在 Homebrew 安装和其他 mutation 之前取得非阻塞内核锁, 因此锁实现不能依赖 Homebrew package. 原实现硬编码调用 `/usr/bin/lockf`, 但 macOS 14.4 只提供 `lockf(3)` 库函数, 没有该 CLI. Shell 把 command-not-found 的退出状态与锁竞争合并处理, 导致 Bootstrap 误报 "Another Bootstrap operation holds".

macOS `flock(2)` 支持对已打开文件描述符进行 advisory, exclusive 和 non-blocking 加锁. 经 `fork(2)` 复制的描述符引用同一锁, 因此 helper 子进程退出后, 父 Bash 的继承描述符可继续持锁.

## Decision

- 使用仓库内 `scripts/lib/lock.pl` 调用 Perl `flock`, 不依赖不存在的 `/usr/bin/lockf` CLI.
- Bash 先打开 `locks/bootstrap.lock`, 再把文件描述符传给 helper. Helper 只负责非阻塞加锁, 不创建, 删除或替换 lock inode.
- Helper 使用退出状态 1 表示锁竞争, 退出状态 2 表示参数, 描述符或内核调用故障. Bootstrap 只对状态 1 报告已有持有者.
- 使用 macOS 系统 `/usr/bin/perl`, 并在加锁前显式验证命令与 helper. 该依赖如在后续 macOS 中被移除, Bootstrap 必须 fail closed, 再通过新 ADR 选择系统级替代, 不回退到 PID lock.

## Consequences and alternatives

该实现保留 Bash 3.2, 持续 inode, 进程树锁生命周期和无 stale-lock 清理的现有约束, 同时让依赖故障与真实竞争可区分. 代价是 Bootstrap 明确依赖 macOS 系统 Perl.

运行时编译 C helper 可直接调用 `flock(2)`, 但会引入 Command Line Tools 前置条件和构建产物. Homebrew `flock` 在锁保护 Homebrew Bootstrap 之前不可用. `mkdir` 和 PID lock 需要 stale-owner 判断和清理, 且不满足内核互斥约束, 因此不采用.

## Verification basis

在 macOS 14.4 上核对了本机 `flock(2)` 与 Perl `flock` 文档, 并验证了 helper 退出后父进程继承描述符仍持锁, 关闭父描述符后竞争者可取得锁. 持续验证由 `tests/test_lock.sh` 覆盖.
