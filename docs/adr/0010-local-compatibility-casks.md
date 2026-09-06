---
title: Local Compatibility Casks
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../operations/installation.md
  - ../development/testing.md
  - 0008-native-package-managers-and-explicit-migrations.md
---

# ADR 0010: Local Compatibility Casks

## Context

官方 Thaw Cask 已选择要求 macOS 26 的 2.0.1. 仅在 Brewfile 中添加最低平台条件会让旧平台完全跳过安装, 无法满足仍需使用 Thaw 的意图. 核对日期为 2026-09-06.

Homebrew 当前要求自定义 Cask 位于 tap; Bundle 的 package identity 使用 Cask token, 不能依赖任意本地 Ruby 路径维持重复安装和检查. 原生 `tap` 支持以本地 Git 仓库为 clone source. 来源见 [Homebrew Manpage](https://docs.brew.sh/Manpage#tap-options-userrepo-url) 与 [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook).

## Decision

- 在本仓库 `Casks/` 保存 Compatibility Cask, 使用独立 versioned token, 固定 version, upstream URL 和 SHA-256.
- Brewfile 在旧平台声明 `danshan/env` Local Tap, source 为 Brewfile 所在 Git 仓库. Homebrew 创建独立 clone, 不使用指向源工作树的 tap symlink.
- 对具体 Cask 设置 `trusted: true`, 不信任整个 tap, 不关闭路径或包级 trust 检查.
- 平台选择仍位于 Brewfile. 安装, 当前状态检查和更新继续使用原生 Bundle/Homebrew, 不增加 package-specific Shell 分支.
- Cask 定义先提交到源仓库, 再由原生 tap clone/update 读取. 该机制不需要额外公开 tap 或远端发布.

## Thaw release evidence

[官方 1.2.0 release](https://github.com/thaw-app/Thaw/releases/tag/1.2.0) 的 `Thaw_1.2.0.zip` 下载内容匹配 GitHub asset digest:

```text
d67f4d31ef9fa057849a98540b810cfa42e0bc66019d3605abd08e45c69aa06f
```

安装包 `Info.plist` 的 `LSMinimumSystemVersion` 为 `14.0`; 主程序 arm64 与 x86_64 的 Mach-O build metadata 同样声明 `minos 14.0`. 这些证据支持 macOS 14/15 的静态安装要求, 不代表所有菜单栏功能已完成运行验证.

Brewfile 在 macOS major 14 至 25 使用 `danshan/env/thaw@1` 1.2.0, 在 26 及以上使用官方 `thaw`. `thaw@1` 声明与 `thaw` 冲突, 因为它们共享 `Thaw.app` target.

## Consequences and alternatives

旧系统获得可重现的已知兼容版本, 代价是 Compatibility Cask 需要维护者审查更新, 且本地未提交定义不会进入 Homebrew clone. 源仓库移动时需核对并显式调整 tap source. App 自带 updater 独立于 Cask 固定版本.

升级系统后不会自动卸载旧 Cask; 操作者明确移除旧 token 后再安装官方 token. 用户偏好数据无需清除, 不使用 `--zap` 或 `--force` 处理共享 target.

直接移除平台条件仍会下载不兼容的新版本. 手工安装 zip 会失去本仓库约定的 Homebrew ownership. 独立公开 tap 引入额外发布流程, 当前本地 Git source 已满足需求, 因而未采用.
