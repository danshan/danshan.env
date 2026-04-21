#!/bin/zsh #!/bin/bash

# Install development environment: asdf plugins and global npm tools

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

# install asdf and plugins
printf "${COLOR_TITLE}📦 Installing asdf...${COLOR_RESET}\n"
brew install --quiet "asdf" </dev/null

printf "${COLOR_SUBTITLE}⚙️  Configuring asdf java...${COLOR_RESET}\n"
asdf plugin add java

printf "${COLOR_SUBTITLE}⚙️  Configuring asdf maven...${COLOR_RESET}\n"
asdf plugin add maven

printf "${COLOR_SUBTITLE}⚙️  Configuring asdf nodejs...${COLOR_RESET}\n"
asdf plugin add nodejs
asdf install nodejs 22.20.0

printf "${COLOR_SUBTITLE}⚙️  Configuring asdf python...${COLOR_RESET}\n"
asdf plugin add python

# install bun
printf "${COLOR_TITLE}📦 Installing Bun...${COLOR_RESET}\n"
npm -i -g bun@latest

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
printf "${COLOR_TITLE}📦 Configuring PI...${COLOR_RESET}\n"
bun add -g @mariozechner/pi-coding-agent@latest

printf "${COLOR_SUBTITLE}⚙️  Configuring pi...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v --no-fold -R -t ~ pi
popd

# install context7
printf "${COLOR_SUBTITLE}⚙️  Configuring context7...${COLOR_RESET}\n"
bun install -g ctx7
ctx7 setup --cli --universal

printf "${COLOR_SUBTITLE}⚙️  Configuring playwright-cli...${COLOR_RESET}\n"
npm install -g @playwright/cli@latest


printf "${COLOR_SUCCESS}✅ Development environment setup complete.${COLOR_RESET}\n"

