#!/bin/zsh #!/bin/bash

# Configure dotfiles using stow, and set up neovim/zed/pi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DOTFILES_DIR="${PROJECT_ROOT}/dotfiles"

printf "⚙️  Configuring Shell...\n"
case ${SHELL} in
*zsh)
    printf "⚙️  Configuring zsh...\n"
    pushd "${DOTFILES_DIR}"
    stow -v -R -t ~ zsh
    popd
    ;;
*bash)
    if [[ $(bash --version | head -n1 | cut -d' ' -f4 | cut -d'.' -f1) -lt 5 ]]; then
        printf "📦 Installing latest Bash...\n"
        brew install bash bash-completion
    fi
    printf "⚙️  Configuring bash...\n"
    pushd "${DOTFILES_DIR}"
    stow -v -R -t ~ bash
    popd
    ;;
esac

printf "⚙️  Configuring vim...\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ vim
popd

printf "⚙️  Configuring fzf...\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ fzf
popd

printf "⚙️  Configuring git...\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ git
popd

printf "⚙️  Configuring screen...\n"
pushd "${DOTFILES_DIR}"
stow -v -R -t ~ screen
popd

printf "⚙️  Configuring neovim...\n"
if [ -d "${HOME}/.config/nvim" ]; then
    printf "📦 Updating neovim config...\n"
    pushd ${HOME}/.config/nvim
    git pull
    popd
else
    git clone --depth=1 git@github.com:danshan/lazyvim.git ${HOME}/.config/nvim
fi

printf "⚙️  Configuring zed...\n"
if [ -d "${HOME}/.config/zed" ]; then
    printf "📦 Updating zed config...\n"
    pushd ${HOME}/.config/zed
    git pull
    popd
else
    git clone --depth=1 git@github.com:danshan/zed-config.git ${HOME}/.config/zed
fi

printf "⚙️  Configuring pi...\n"
pushd "${DOTFILES_DIR}"
stow -v --no-fold -R -t ~ pi
popd

printf "✅ Dotfiles configuration complete.\n"
