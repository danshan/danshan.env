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

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    printf "📦 Installing homebrew package: ${pkg}\n"
    brew install --quiet "$pkg" </dev/null
done < "${PROJECT_ROOT}/defaults/brew_pkgs.txt"

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    pkg_name="$(echo "$pkg" | awk -F '|' '{ print $1 }')"
    app_name="$(echo "$pkg" | awk -F '|' '{ print $2 }')"
    if [ -n "$app_name" ] && [ -e "/Applications/${app_name}.app" ]; then
        printf "✅ Application ${app_name} exists.\n"
    else
        printf "📦 Installing ${pkg_name}...\n"
        brew install --quiet --cask "$pkg_name" </dev/null
    fi
done < "${PROJECT_ROOT}/defaults/brew_casks.txt"

printf "✅ Package installation complete.\n"
