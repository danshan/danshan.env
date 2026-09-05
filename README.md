# danshan.env

个人 macOS 开发环境的可重复 Bootstrap 和 dotfiles 仓库.

## Get started

```bash
git clone git@github.com:danshan/danshan.env.git "$HOME/.config/danshan.env"
cd "$HOME/.config/danshan.env"
bash install.sh
```

## Update

```bash
cd "$HOME/.config/danshan.env"
git pull --ff-only
bash install.sh
```

安装过程会先收敛显式的第三方 Homebrew package trust, 再按当前 macOS major 跳过不兼容 Cask, 跳过已安装的最新 Formula 和 Cask, 只安装 missing 项并升级 outdated 项. Manifest 可使用 `adopt` 接管内容相同的 App artifact, 或使用 `migrate` 对不同版本的既有 App 执行 snapshot, install, verify 和自动 Rollback. Nerd Font 使用独立的 batch migration transaction. 不会信任整个 tap, 关闭 trust check 或使用 `--force` 覆盖冲突. 任一阶段失败时, 顶层返回非零状态且不会输出完成提示.

## Documentation

- 文档入口: [docs/README.md](docs/README.md).
- 项目术语: [CONTEXT.md](CONTEXT.md).
- 安装和故障处理: [Installation Runbook](docs/operations/installation.md).
- 开发与测试: [Testing Guide](docs/development/testing.md).
- 文档规范: [Documentation Standard](docs/standards/documentation.md).
