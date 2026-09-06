# danshan.env

个人 macOS 开发环境的可重复 Bootstrap 和 dotfiles 仓库.

## Get started

```bash
git clone git@github.com:danshan/danshan.env.git "$HOME/.config/danshan.env"
cd "$HOME/.config/danshan.env"
bash install.sh
```

提交变更前可以先执行只读检查:

```bash
bash install.sh plan
bash install.sh status
bash install.sh status --stage devenv
```

## Update

```bash
cd "$HOME/.config/danshan.env"
git pull --ff-only
bash install.sh
```

安装过程先执行 preflight, 再收敛 Homebrew, dotfiles 和 Mise Desired State. Homebrew 管理 macOS 系统工具和 App, Mise 管理语言 runtime 与固定版本的全局 CLI, Bun 和 NPM 只管理具体项目的依赖. `plan` 和 `status` 不修改 Managed State; `--stage` 和 `--from` 可缩小诊断范围.

Cask manifest 可使用 `adopt` 接管内容相同的 App artifact, 或使用 `migrate` 对不同版本的既有 App 执行 snapshot, install, verify 和自动 Rollback. App 和 Nerd Font migration 都使用互斥锁, 原子状态记录和启动时中断恢复. 不会信任整个 tap, 关闭 trust check 或使用 `--force` 覆盖冲突. 任一阶段失败时, 顶层返回非零状态且不会输出完成提示.

## Documentation

- 文档入口: [docs/README.md](docs/README.md).
- 项目术语: [CONTEXT.md](CONTEXT.md).
- 安装和故障处理: [Installation Runbook](docs/operations/installation.md).
- 开发与测试: [Testing Guide](docs/development/testing.md).
- 文档规范: [Documentation Standard](docs/standards/documentation.md).
