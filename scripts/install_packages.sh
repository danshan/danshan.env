#!/bin/zsh #!/bin/bash

# Install brew packages, casks, oh-my-tmux, and uv

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Ensure brew is available
if [[ $(uname -m) = "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/Homebrew/bin/brew shellenv)" 2>/dev/null || true
fi

printf "📦 Configuring Completions in zsh...\n"
brew cleanup && rm -f $ZSH_COMPDUMP && omz reload

printf "📦 Installing essential danshan.env toolchains...\n"
brew update

cat "${PROJECT_ROOT}/defaults/brew_pkgs.txt" | while read -r pkg; do
    printf "📦 Installing homebrew package: ${pkg}\n"
    brew install "$pkg"
done

cat "${PROJECT_ROOT}/defaults/brew_casks.txt" | while read -r pkg; do
    pkg_name="$(echo ${pkg} | awk -F '|' '{ print $1 }')"
    app_name="$(echo ${pkg} | awk -F '|' '{ print $2 }')"
    if [ -e "/Applications/${app_name}.app" ]; then
        printf "✅ Application ${app_name} exists.\n"
    else
        printf "📦 Installing ${pkg_name}...\n"
        brew install --cask "$pkg_name"
    fi
done

printf "📦 Installing oh-my-tmux...\n"
git clone https://github.com/gpakosz/.tmux.git ${HOME}/.config/oh-my-tmux
ln -f -s ${HOME}/.config/oh-my-tmux/.tmux.conf ${HOME}/.tmux.conf
ln -s -f ${PROJECT_ROOT}/dotfiles/tmux/.tmux.conf.local ${HOME}/.tmux.conf.local
tmux source-file ${HOME}/.tmux.conf

printf "📦 Installing uv...\n"
curl -LsSf https://astral.sh/uv/install.sh | sh

printf "✅ Package installation complete.\n"
