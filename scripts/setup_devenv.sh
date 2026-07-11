#!/bin/zsh #!/bin/bash

# Install development environment: mise plugins and global npm tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# install stow
printf "${COLOR_TITLE}📦 Installing stow...${COLOR_RESET}\n"
brew install --quiet stow
source ~/.zshrc 2>/dev/null || true

# install tmux and oh-my-tmux
printf "${COLOR_TITLE}📦 Installing tmux...${COLOR_RESET}\n"
brew install --quiet "tmux" </dev/null
if [ ! -d "${HOME}/.config/oh-my-tmux" ]; then
  printf "${COLOR_SUBTITLE}⚙️  Installing oh-my-tmux...${COLOR_RESET}\n"
  git clone https://github.com/gpakosz/.tmux.git "${HOME}/.config/oh-my-tmux" </dev/null
else
  printf "${COLOR_SUBTITLE}⚙️  oh-my-tmux already installed, updating...${COLOR_RESET}\n"
  pushd "${HOME}/.config/oh-my-tmux"
  git pull origin HEAD </dev/null
  popd

fi
printf "${COLOR_SUBTITLE}⚙️  Configuring tmux...${COLOR_RESET}\n"
ln -f -s "${HOME}/.config/oh-my-tmux/.tmux.conf" "${HOME}/.tmux.conf"
pushd "${DOTFILES_DIR}"
stow -v --no-fold -R -t ~ tmux
popd

# install uv
printf "${COLOR_TITLE}📦 Installing uv...${COLOR_RESET}\n"
curl -LsSf https://astral.sh/uv/install.sh | sh </dev/null

# install mise
printf "${COLOR_TITLE}📦 Installing mise...${COLOR_RESET}\n"
curl https://mise.run | sh

printf "${COLOR_SUBTITLE}⚙️  Configuring mise java...${COLOR_RESET}\n"
mise use --global java@zulu-17.66.19.0

printf "${COLOR_SUBTITLE}⚙️  Configuring mise maven...${COLOR_RESET}\n"
mise use --global maven@3.9.9

printf "${COLOR_SUBTITLE}⚙️  Configuring mise nodejs...${COLOR_RESET}\n"
mise use --global  node@24.18.0

printf "${COLOR_SUBTITLE}⚙️  Configuring mise python...${COLOR_RESET}\n"
mise use python@3.12.12

# install bun
printf "${COLOR_SUBTITLE}⚙️  Configuring mise bun...${COLOR_RESET}\n"
mise use --global bun@1.3.14

# install codex
printf "${COLOR_TITLE}📦 Install Codex...${COLOR_RESET}\n"
bun add -g @openai/codex@latest

printf "${COLOR_SUBTITLE}⚙️  Configuring codex...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v --no-fold -R -t ~ codex
popd

# install gemini-cli
printf "${COLOR_TITLE}📦 Install Gemini-CLI...${COLOR_RESET}\n"
bun add -g @google/gemini-cli@latest

printf "${COLOR_SUBTITLE}⚙️  Configuring gemini...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v --no-fold -R -t ~ gemini
popd

# install claude-code
printf "${COLOR_TITLE}📦 Install Claude-Code...${COLOR_RESET}\n"
#curl -fsSL https://claude.ai/install.sh | bash
bun add -g @anthropic-ai/claude-code@latest

printf "${COLOR_SUBTITLE}⚙️  Configuring Claude-Code...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v --no-fold -R -t ~ claude
popd

# install opencode
printf "${COLOR_TITLE}📦 Install OpenCode...${COLOR_RESET}\n"
bun add -g opencode-ai@latest

printf "${COLOR_SUBTITLE}📦 Install Oh-My-OpenAgent...${COLOR_RESET}\n"
bun add -g oh-my-openagent@latest

# install pi-coding-agent
printf "${COLOR_TITLE}⚙️  Install PI...${COLOR_RESET}\n"
bun add -g @earendil-works/pi-coding-agent

printf "${COLOR_SUBTITLE}⚙️  Configuring pi...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v --no-fold -R -t ~ pi
popd

# install context7
printf "${COLOR_SUBTITLE}⚙️  Install context7...${COLOR_RESET}\n"
bun install -g ctx7
printf "${COLOR_SUBTITLE}⚙️  Configuring context7...${COLOR_RESET}\n"
ctx7 setup 

printf "${COLOR_SUBTITLE}⚙️  Install playwright-cli...${COLOR_RESET}\n"
npm install -g @playwright/cli@latest

printf "${COLOR_SUBTITLE}⚙️  Configuring neovim...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ nvim
popd


# install herdr
printf "${COLOR_TITLE}📦 Install herdr...${COLOR_RESET}\n"
curl -fsSL https://herdr.dev/install.sh | sh

printf "${COLOR_SUBTITLE}⚙️  Configuring herdr...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v --no-fold -R -t ~ herdr
popd

printf "${COLOR_SUCCESS}✅ Development environment setup complete.${COLOR_RESET}\n"

