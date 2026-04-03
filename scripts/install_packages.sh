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

printf "${COLOR_TITLE}📦 Configuring Completions in zsh...${COLOR_RESET}\n"
brew cleanup && rm -f $ZSH_COMPDUMP && omz reload

printf "${COLOR_TITLE}📦 Installing essential danshan.env toolchains...${COLOR_RESET}\n"
brew update

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    printf "${COLOR_INFO}📦 Installing homebrew package: ${pkg}${COLOR_RESET}\n"
    brew install --quiet "$pkg" </dev/null
done < "${PROJECT_ROOT}/defaults/brew_pkgs.txt"

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    pkg_name="$(echo "$pkg" | awk -F '|' '{ print $1 }')"
    app_name="$(echo "$pkg" | awk -F '|' '{ print $2 }')"
    if [ -n "$app_name" ] && [ -e "/Applications/${app_name}.app" ]; then
        printf "${COLOR_SUCCESS}✅ Application ${app_name} exists.${COLOR_RESET}\n"
    else
        printf "${COLOR_INFO}📦 Installing ${pkg_name}...${COLOR_RESET}\n"
        brew install --quiet --cask "$pkg_name" </dev/null
    fi
done < "${PROJECT_ROOT}/defaults/brew_casks.txt"

printf "${COLOR_SUCCESS}✅ Package installation complete.${COLOR_RESET}\n"
