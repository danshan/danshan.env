---
title: Installation Runbook
status: active
owner: repository-maintainers
last_updated: 2026-09-06
related:
  - ../architecture/bootstrap.md
  - ../adr/0008-native-package-managers-and-explicit-migrations.md
  - ../adr/0007-reviewed-npm-trust-policy-exception.md
  - ../development/testing.md
---

# Installation Runbook

## Preconditions

使用受 Homebrew 支持的 macOS, 安装 Command Line Tools, 准备 Git, 网络访问和必要的 SSH repository 权限. 支持的登录 Shell 为 Bash, Zsh, Fish. Homebrew 首次安装使用 `config/bootstrap.env` 中完整 commit 对应的安装器; 配置文件头部说明修改格式和审查要求.

Bootstrap 不切换登录 Shell, 不强制覆盖冲突配置, 不删除未声明软件. Stow 部署 `all` 和当前登录 Shell 的 package. 已有 Zed 等 Git target 必须匹配清单声明的 origin; identity 不匹配时先核实来源, 不应直接绕过检查.

## Commands

在仓库根目录执行:

```bash
bash install.sh check
bash install.sh apply
bash install.sh check --stage mise
bash install.sh apply --from dotfiles
```

| 操作 | 行为 | 退出语义 |
|---|---|---|
| `apply` 或省略操作 | 收敛声明资源 | 任何失败立即非零, 无完成提示 |
| `check` | 本地只读, 离线检查 | unmet, conflict 或 unknown 为非零 |
| `migrate` | 按迁移许可接管既有 artifact | 单 transaction 失败即停止 |
| `recover` | 恢复已有可识别的中断 transaction | 未完成恢复为非零 |

阶段顺序为 `homebrew`, `repositories`, `dotfiles`, `mise`. `--stage` 只执行一个阶段; `--from` 执行指定阶段及之后全部阶段, 两者互斥. 这些选项仅用于 `apply/check`, 不补跑依赖阶段. 例如 `--stage mise` 要求 Homebrew/Mise 已存在且 Mise package 已由 Stow 部署.

旧 `plan/status` 已移除, 改用 `check`; 旧 `devenv` stage 改为 `mise`. 模块脚本是内部实现, 日常操作统一使用 `install.sh`.

首次 `check` 通常报告管理器或资源缺失并返回非零. `check` 不刷新 metadata, 解析新的 latest 或检查 tracking repository 的远端提交. Homebrew, Stow, Mise 缺失时会报告无法查询的范围, 不替操作者安装它们. Preflight 和互斥锁错误会提前终止, 普通阶段问题会继续汇总.

`check` 通过 `config/check.sb` 禁止文件写入和网络访问, 包括 package manager 的隐式更新和 cache 写入. Mise 查询可能输出写入内部标记失败的 warning, 被检查文件仍保持原状. 如果外层执行环境禁止 `sandbox-exec`, 在允许建立该沙箱的 macOS Terminal 中执行; 不应删除沙箱或直接调用内部脚本规避只读约束.

Homebrew stage 默认先刷新 metadata; 调试隔离测试时可设置 `DANSHAN_SKIP_BREW_UPDATE=1` 使用已有 metadata. `--no-color` 或 `NO_COLOR=1` 关闭 Bootstrap 消息的 ANSI color, 原生子命令输出遵循工具自身设置. `BREW_CN=1` 仅切换首次 Homebrew 安装器获取方式为配置中同一 commit 的镜像, 不改变包 owner 或版本策略.

## Installation output

Homebrew stage 默认显示 metadata update, Brewfile install/upgrade 和最终 verification 的开始, 完成或失败及耗时. 首次安装 Homebrew 也有独立步骤提示. Bundle 启用 `--verbose`, 安装过程中的原生下载, 解包和安装输出随命令执行直接显示.

在交互终端中, Homebrew 可以显示原生动态下载进度. 经 `tee`, 文件重定向或执行器捕获后, Homebrew 可能关闭动态进度条, 但安装状态日志仍会实时输出. 不保证每个下载源都提供百分比, 也不计算整个 Brewfile 的统一百分比.

以下为步骤输出示例, 中间会穿插 Homebrew 的原生日志:

```text
Starting: Update Homebrew metadata
Finished: Update Homebrew metadata (2s)
Starting: Install or upgrade Brewfile packages
Finished: Install or upgrade Brewfile packages (35s)
Starting: Verify Brewfile packages
Finished: Verify Brewfile packages (1s)
```

失败步骤显示 `Failed`, 原命令的 exit code 和耗时, 顶层返回非零, 不继续报告该步骤或整个安装完成. 单个 install 步骤的 `Finished` 只表示该命令成功, 最终结果还需通过后续 verification.

显式 `migrate` 中每个 App/font Cask 安装也显示原生输出和步骤耗时. 迁移仍保持 stdin 关闭, stdout/stderr 直接透传; ownership 验证和失败回滚按既有 transaction 契约执行.

## Maintain inventories

| 文件 | 修改方式 |
|---|---|
| `Brewfile` | 使用原生 `brew` 或 `cask` declaration. 第三方 package 使用完整 token 和 `trusted: true`, 不给整个 tap 授权. 平台差异用原生条件表达. |
| `dotfiles/mise/.config/mise/config.toml` | 修改 runtime 或开发 CLI declaration; 新开发 CLI 通常使用 `latest`. |
| `config/dotfiles.tsv` | 新增 Stow package 及 `all/bash/zsh/fish` selector. |
| `config/repositories.tsv` | 新增 Git URL, HOME-relative target, commit 或 tracking 和 Shell selector. |
| `config/links.tsv` | 新增依赖仓库内的精确 source/target link. |
| `config/migrations.txt` | 只登记需要明确接管许可的 App, font 或受支持的 legacy config. |

`config/` 各文件头部是数据格式的就地说明, 包括分隔符, 顺序, 允许值和示例. TSV 必须用真实 TAB, 不支持用空格替代, 不允许空字段, 行尾注释或额外列. 不在这些清单中放凭据.

菜单栏管理统一使用 Thaw 替代 Bartender, 由 Brewfile 的 `thaw` Cask 管理. [Homebrew Cask](https://formulae.brew.sh/cask/thaw) 要求 macOS 26 及以上, 因而较旧系统跳过该项, 不自动安装 Bartender 作为替代. 已安装的 Bartender 不会被 Bootstrap 自动卸载; 切换时应先退出 Bartender 并关闭其登录启动, 再启用 Thaw, 避免同时管理菜单栏. 平台要求核对日期为 2026-09-06.

刷新开发 CLI latest 和修改后的 runtime pin:

```bash
bash scripts/update_mise_lock.sh
git diff -- dotfiles/mise/.config/mise/config.toml dotfiles/mise/.config/mise/mise.lock
bash tests/run.sh
bash install.sh apply --stage mise
```

刷新命令仅调用原生 `mise lock --global --bump --platform macos-arm64,macos-x64`, 不安装工具. 可以追加 tool selector 缩小刷新范围, 例如 `bash scripts/update_mise_lock.sh npm:@openai/codex`. 它会访问远端 metadata, 部分 backend 会下载 artifact 验证 provenance. Mise 原生 NPM lock 记录 top-level version, 不锁定完整传递 dependency graph. 不手写 backend 不提供的 checksum 字段.

`oh-my-openagent@4.19.1` 的 `effect@4.0.0-beta.66` 例外仍以 ADR 0007 为准. 改变依赖链前重新审查, 依赖不再需要时删除例外; 不扩大为无版本的 `effect` 例外.

## Compatibility casks

Thaw 的平台选择由 Brewfile 决定:

| macOS major | 声明 |
|---|---|
| 小于 14 | 不安装 Thaw |
| 14 至 25 | 本仓库 `danshan/env/thaw@1`, 固定 1.2.0 |
| 26 及以上 | 官方 `thaw`, 由 Homebrew 提供当前版本 |

在旧平台, 原生 Bundle 将当前 Bootstrap Git 仓库克隆为 `danshan/env` tap. 源位置从 Brewfile 所在目录解析, 不依赖调用者 cwd. Cask 定义必须先提交到源仓库, 未提交修改不会进入 tap. 普通仓库更新后执行:

```bash
bash install.sh apply --stage homebrew
```

该命令会收敛整个 Homebrew 清单, 并非只安装 Thaw. 预期 `thaw@1` 安装成功, 再次执行时由原生 Bundle 跳过已满足项. 安装失败保留非零结果, 不移除平台条件或使用 `--force`.

维护 `Casks/` 时先核对官方 release, 下载摘要及最低系统要求, 同步 ADR 与平台测试, 然后提交定义并执行上述命令. 不直接编辑 Homebrew tap clone. 源仓库移动后, 核对 `brew --repository danshan/env` 中的 origin, 再显式调整本地 tap 的 source; 不覆盖未知 tap.

`thaw@1` 与官方 `thaw` 都安装 `Thaw.app`, 因此声明原生 conflict. 系统升级到 macOS 26 后, 需要先明确卸载旧 Cask, 保留偏好数据, 再执行 Homebrew 阶段安装官方版本; Bootstrap 不自动删除旧版本. Cask 固定版本不控制 App 内置更新器, 旧系统不要手动升级到超出系统要求的版本. 发布证据与选择理由见 [ADR 0010](../adr/0010-local-compatibility-casks.md).

## NPM trust downgrade

`trustPolicy=no-downgrade` 表示候选 release 的发布信任证据弱于历史版本, 不属于普通下载或版本解析失败. 先从 npm 官方 registry 核对 publisher, provenance, source commit 和 tarball 摘要; 若代理返回的 metadata 不同, 还需定位代理问题. 不自动加入 `trust_policy_excludes`, 不使用 `npm.shell_out=true` 绕过检查.

当前 `@playwright/cli@0.1.19` 在 npm 官方 registry 缺少 `0.1.18` 具备的 trusted publisher 和 provenance. 仓库将其固定为经过核验的 `0.1.18`, 原生 lockfile 同步固定, 证据和解除条件见 [ADR 0009](../adr/0009-playwright-cli-trust-hold.md). `update_mise_lock.sh` 尊重该精确版本, 不会因 `--bump` 自动回到 `latest`.

在 config 和 lockfile 已由 Stow 部署的前提下, 更新仓库后继续:

```bash
bash install.sh apply --stage mise
```

该命令只重新收敛 Mise 阶段. 预期不再选择被 Hold 排除的版本; 其他 dependency 的信任失败仍需独立审查, 必须保持非零退出. 解除 Hold 前验证新版本的发布证据和依赖, 然后同步 declaration, 原生 lockfile, ADR 与安全约束测试.

## Existing artifacts and migration

Brewfile 的 Cask declaration 表示 Homebrew ownership. 原生 Bundle 默认尝试 adoption, 接管条件由 Homebrew 判定, 不保证逐字节比较. 需要继续由外部安装器管理的 App 应从 Brewfile 移除. 从清单移除不会自动卸载.

遇到 adoption 或 Stow conflict 时, 先比较现有 artifact 与声明意图. `migrate` 会替换许可清单内的 App/font, 需要额外磁盘空间保存原件和可能的失败产物. 原件与 snapshot 必须位于同一 filesystem, 不支持可能发生部分复制的跨卷 move. App snapshot 只包含 bundle, 不包含其他 Library 中的 preferences 或用户数据. 字体 snapshot 不得由 Bootstrap 自动清理.

```bash
cat config/migrations.txt
bash install.sh migrate
bash install.sh apply
```

常规顺序是先执行一次 `apply`, 使原生 Bundle 完成 package trust 授权并报告冲突, 再执行显式迁移. `migrate` 在移动原件前要求 Cask 属于当前平台有效的 Brewfile, 且第三方包已有精确 trust. 已由 Homebrew 管理的 Cask 跳过. 无外部 App 时留给后续 `apply` 安装; 字体 batch 也会安装许可清单中的 missing Cask.

App 按清单中的不含 `.app` 后缀的名字定位 `/Applications/<name>.app`. 字体 target 仅取 Homebrew metadata, 只允许 `${HOME}/Library/Fonts` 直接文件, 拒绝非字体 artifact, 目录穿越, 重复目标和 symlinked parent.

旧 `~/.config/mise/config.toml` 的迁移只接受已知 `[tools]` 简单赋值子集. 额外 section, comment, 不同版本, 未知 key 或外部 lockfile 都会拒绝. 先保留 snapshot, 再部署 config/lockfile. 普通 Stow 冲突和既有独立 Git checkout 不在自动适配范围, 需先比较并保留本地改动, 再移至明确备份路径.

## Recovery and snapshots

状态目录为 `${HOME}/Library/Application Support/danshan.env`. `app-backups`, `font-backups`, `dotfile-backups` 中的 snapshot 持续保留. 新 snapshot 包含 `format`, `manifest.txt`, `state`, `originals`, 以及失败时的 artifact. 状态由同目录临时文件加 rename 原子更新.

| 状态 | 操作 |
|---|---|
| `completed` | 新 ownership 已验证, 保留原件. |
| `rolled-back` | 已恢复原状态, 修复外部原因后可以重新 `migrate`. |
| `prepared/snapshotting/snapshot-failed/installing/reconciling/verifying/rolling-back` | 使用显式 `recover` 处理对应类型可识别的中断状态. |
| `rollback-incomplete` 或未知状态/metadata | 停止自动重试, 核实 snapshot, 原件, 目标和 Homebrew inventory 后人工处理. |

```bash
bash install.sh recover
bash install.sh check
```

`apply/check` 发现 pending snapshot 会报告, 不隐式恢复. 恢复前会验证 manifest 的精确目标与 snapshot 路径. 回滚先保留新 artifact, 再卸载本次已登记 Cask, 最后从持续保留的原件恢复. 恢复中再次中断可重试; 丢失原件, 未知冲突或无法确认的状态会 fail closed. 不手工把未知 state 改为 completed.

格式 1 的旧 snapshot 仍可按既有布局恢复. 更早无 state 的 font snapshot 只有在 target, 保留原件和 Homebrew ownership 全部验证后才被只读认可为 completed, 不补写历史 state.

变更命令由 `locks/bootstrap.lock` 的内核锁串行化, 不删除该文件 inode. 已存在锁文件时 `check` 只读加锁; 首次 `check` 不创建锁文件. 进程树结束后锁自动释放. 旧 `cask-migration.lock` 的活跃 PID 会阻止新命令, 无 PID 或异常结构需要人工确认旧进程已结束, 不直接删除 active lock.

## Shell and local secrets

Bash, Zsh, Fish 使用 Homebrew Shell 环境和 Mise activation. NVM/RVM/standalone Bun, uv, OpenCode 的旧初始化已从声明配置中移除; Bootstrap 不删除机器上这些旧安装目录. 重新打开 Shell 后检查实际命令来源; 已在运行的 Fish session 可能保留先前 universal PATH, 不应以旧 session 判断新的初始化结果.

Bash/Zsh 的本机扩展分别为 `~/.bash.local.sh` 和 `~/.zsh.local.sh`. Fish 可从被忽略的 `conf.d/*.local.fish` 加载. 不提交真实凭据, 不对 local-secret 文件使用 `git add -f`.

```bash
cp dotfiles/fish/.config/fish/conf.d/secrets.local.fish.example \
  dotfiles/fish/.config/fish/conf.d/secrets.local.fish
chmod 600 dotfiles/fish/.config/fish/conf.d/secrets.local.fish
```

## Existing security records

本仓库不管理全局 Codex Hook. 如新增 Hook, 仅使用 repository-local `.codex/hooks.json` 和仓库内 executable. `Hook failed` 的 exit 127 应检查命令是否存在, 可执行以及非交互 PATH, 不能靠交互 alias 解决.

历史凭据事件保留在 [2026-09-03 Review](../archive/2026-09-03-bootstrap-remediation.md). 历史清理不等于 credential revocation; 旧 token 必须在对应服务端撤销且不复用. 不把旧 history merge 回已清理仓库, 先保留本地改动, 再通过干净 clone 和审查后的 patch 恢复工作.
