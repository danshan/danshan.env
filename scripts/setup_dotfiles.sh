#!/bin/zsh #!/bin/bash

# Configure dotfiles using stow, and set up neovim/zed/pi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

printf "${COLOR_TITLE}⚙️  Configuring Shell...${COLOR_RESET}\n"
case ${SHELL} in
*zsh)
    printf "${COLOR_SUBTITLE}⚙️  Configuring zsh...${COLOR_RESET}\n"
    pushd "${DOTFILES_DIR}"
    stow -v -R -t ~ zsh
    popd
    ;;
*bash)
    if [[ $(bash --version | head -n1 | cut -d' ' -f4 | cut -d'.' -f1) -lt 5 ]]; then
        printf "${COLOR_SUBTITLE}📦 Installing latest Bash...${COLOR_RESET}\n"
        brew install bash bash-completion
    fi
    printf "${COLOR_SUBTITLE}⚙️  Configuring bash...${COLOR_RESET}\n"
    pushd "${DOTFILES_DIR}"
    stow -v -R -t ~ bash
    popd
    ;;
esac

printf "${COLOR_SUBTITLE}⚙️  Configuring vim...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ vim
popd

printf "${COLOR_SUBTITLE}⚙️  Configuring fzf...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ fzf
popd

printf "${COLOR_SUBTITLE}⚙️  Configuring git...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ git
popd

printf "${COLOR_SUBTITLE}⚙️  Configuring screen...${COLOR_RESET}\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ screen
popd

printf "${COLOR_SUBTITLE}⚙️  Configuring neovim...${COLOR_RESET}\n"
if [ -d "${HOME}/.config/nvim" ]; then
    printf "${COLOR_SUBTITLE}📦 Updating neovim config...${COLOR_RESET}\n"
    pushd ${HOME}/.config/nvim
    git pull
    popd
else
    git clone --depth=1 git@github.com:danshan/lazyvim.git ${HOME}/.config/nvim
fi

printf "${COLOR_SUBTITLE}⚙️  Configuring zed...${COLOR_RESET}\n"
if [ -d "${HOME}/.config/zed" ]; then
    printf "${COLOR_SUBTITLE}📦 Updating zed config...${COLOR_RESET}\n"
    pushd ${HOME}/.config/zed
    git pull
    popd
else
    git clone --depth=1 git@github.com:danshan/zed-config.git ${HOME}/.config/zed
fi






printf "${COLOR_SUCCESS}✅ Dotfiles configuration complete.${COLOR_RESET}\n"
