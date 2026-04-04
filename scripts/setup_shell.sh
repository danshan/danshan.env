#!/bin/zsh #!/bin/bash

# Install oh-my-zsh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

printf "${COLOR_TITLE}📦 Installing oh-my-zsh...${COLOR_RESET}\n"
if [[ ${BREW_CN} ]]; then
    sh -c "$(curl -fsSL https://gitee.com/shmhlsy/oh-my-zsh-install.sh/raw/master/install.sh)"
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

printf "${COLOR_TITLE}📦 Installing starship...${COLOR_RESET}\n"
brew install --quiet starship </dev/null
printf "${COLOR_SUBTITLE}⚙️  Configuring statship...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ starship
popd

printf "${COLOR_SUCCESS}✅ Shell environment setup complete.${COLOR_RESET}\n"
