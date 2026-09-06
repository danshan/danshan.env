---
title: Native Bootstrap Review and Implementation
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../adr/0008-native-package-managers-and-explicit-migrations.md
  - ../development/testing.md
  - ../operations/installation.md
---

# Native Bootstrap Review and Implementation

## Scope and decision

本轮根据文档一致性, 模块职责, package owner, 通用性和配置扩展能力审查 Bootstrap. 用户批准直接重整设计, 允许开发 CLI 使用 latest, 并要求同步实现和文档. 决策与兼容性变化记录在 ADR 0008.

## Findings and changes

| 原问题 | 已实现调整 |
|---|---|
| Homebrew 清单, trust, 平台与自建普通 reconciliation 分散, 大型 common 模块跨职责 | 原生 Brewfile/Bundle, 独立功能模块, 删除重复普通 package engine |
| Starship 分类不明确, 运行时与 Shell 的 NVM/RVM/standalone 路径冲突 | 主机 Shell 工具归 Homebrew, 开发工具归 Mise, 清理旧初始化并补齐 Bash activation |
| Git dependency 与 symlink 硬编码, 配置文档的 ownership 说明不一致 | 配置化 repositories/links, Stow 管理仓库内 dotfiles |
| 用 global config override 误认为 Mise cwd 已隔离 | 使用真实路径 ceiling, 独立 global/system 层, 清除调用者 Mise 设置并测试实际发现结果 |
| 原生查询启动时仍写内部迁移标记 | 公开 check 在系统只读离线沙箱中执行, 不依赖命令命名判断副作用 |
| PID lock 创建与 PID 写入之间存在竞态 | 使用 macOS `lockf` 的内核锁和保留 inode |
| 旧配置迁移准备写入失败可能被条件调用吞掉 | 显式检查 mkdir, manifest, state 和 move 结果, 增加失败注入 |
| App snapshot-failed 且未移动原件时恢复会误隔离原件 | 验证 state 与原件位置, 未移动原件保持原位 |
| Font recovery 未充分限制精确路径 | 恢复前校验 target, 类型, 重复项和 symlinked parent |
| 回滚在保留失败产物之前调用卸载 | 先保存失败 artifact, 再卸载, 从持续保留的原件复制恢复 |
| 测试把版本字符串与业务状态耦合, 多文件 bash -n 只检查第一个 | 检查原生 config/lock 结构, 逐文件语法验证, 独立编排与失败场景 |
| 配置缺少就地格式说明 | `config/` 全部文件补充完整格式, 允许值与示例, 同步字段与重复值校验 |
| Bundle 缓冲子命令输出, 迁移 quiet install 缺少安装反馈 | Bundle 启用 verbose, 迁移移除 quiet, 直接透传 stdout/stderr 保留 TTY, 补充步骤状态与耗时 |
| 工具清单按维护者选择调整 | 菜单栏管理使用 Thaw; 移除 drawio, zellij, Hammerspoon 和 cmux 安装项, 同步移除对应的 Stow 清单, 配置文件和失效启动注释 |

## Verification boundary

测试范围与命令见 Testing Guide. 验证使用临时 HOME, stub package manager, 本地 Git, 真实只读 Mise 查询和系统锁. Native Mise lock 刷新使用隔离 HOME, 更新仓库锁文件, 不执行工具安装. 最终隔离验证结果为 `PASS 12 test files`, 包括逐文件 Shell 语法, 配置格式与锁文件一致性, 整体入口, 只读边界和迁移失败恢复. 安装输出测试同时覆盖 PTY 和重定向场景, 要求在命令结束前观察到无换行的 stdout/stderr, 并验证 TTY, 退出码和失败提示.

上述 Bootstrap 重构的隔离验证不执行真实 apply/migrate/recover, 不修改用户已安装软件. 下载可用性, 系统权限和应用启动需在真实安装时继续确认. 旧命令和 preserve 默认语义的迁移说明已写入 runbook.

后续按维护者明确指令通过原生 Homebrew 卸载 Hammerspoon 和 cmux, 使用 Stow 解除已有配置链接, 并移除相应清单和配置文件. 这些操作持有仓库 `lockf` 锁, 保留用户偏好数据, 独立于上述隔离测试.

Thaw 的旧平台安装随后按 [ADR 0010](../adr/0010-local-compatibility-casks.md) 改为原生 Local Tap 和 Compatibility Cask, 取代旧系统完全跳过的声明. 当前平台规则与维护方法以 [Installation Runbook](../operations/installation.md#compatibility-casks) 为准.

在 macOS 15.7.3 上, 使用仅包含所选 tap/Cask 的临时 Brewfile 完成 Thaw 1.2.0 原生安装, 验证 App version, Homebrew inventory, 独立 tap source, Bundle check 和重复 install 跳过. 安装持有仓库锁, 不收敛其他应用. GUI 功能未验证. 隔离回归仍为 `PASS 12 test files`.

## Obsolete material

按维护者授权删除旧普通 Homebrew engine, defaults 清单, compatibility facade, 旧 stage 入口和对应失效测试. 删除已由 ADR 0008 替代的 ADR 0001 至 0006 和 hardening 方案, 不复用编号. 仍有效的 ADR 0007 保留, 原凭据事件 Review 移至 archive, 所有入站链接同步更新.
