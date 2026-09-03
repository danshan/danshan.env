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

安装过程会先收敛显式的第三方 Homebrew package trust, 再跳过已安装的最新 Formula 和 Cask, 只安装 missing 项并升级 outdated 项. 不会信任整个 tap 或关闭 trust check. 任一阶段失败时, 顶层返回非零状态且不会输出完成提示.

## Documentation

- 文档入口: [docs/README.md](docs/README.md).
- 项目术语: [CONTEXT.md](CONTEXT.md).
- 安装和故障处理: [Installation Runbook](docs/operations/installation.md).
- 开发与测试: [Testing Guide](docs/development/testing.md).
- 文档规范: [Documentation Standard](docs/standards/documentation.md).
