#!/bin/zsh #!/bin/bash

# Install development environment: asdf plugins and global npm tools

source ~/.zshrc 2>/dev/null || true

printf "⚙️  Configuring asdf java...\n"
asdf plugin add java

printf "⚙️  Configuring asdf maven...\n"
asdf plugin add maven

printf "⚙️  Configuring asdf nodejs...\n"
asdf plugin add nodejs 22.20.0
asdf install nodejs 22.20.0

printf "⚙️  Configuring asdf python...\n"
asdf plugin add python

source ~/.zshrc 2>/dev/null || true

printf "❇️  Configuring codex...\n"
npm i -g @openai/codex

printf "❇️  Configuring gemini-cli...\n"
npm i -g @google/gemini-cli

printf "❇️  Configuring opencode...\n"
curl -fsSL https://opencode.ai/install | bash

printf "❇️  Configuring oh-my-opencode...\n"
npm install -g oh-my-opencode

printf "❇️  Configuring pi...\n"
npm install -g @mariozechner/pi-coding-agent

printf "✅ Development environment setup complete.\n"
