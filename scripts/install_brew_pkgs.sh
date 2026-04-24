#!/bin/zsh #!/bin/bash

# Install brew packages

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

printf "${COLOR_TITLE}📦 Installing homebrew packages...${COLOR_RESET}\n"
brew update

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    printf "${COLOR_INFO}📦 Installing homebrew package: ${pkg}${COLOR_RESET}\n"
    brew install --quiet "$pkg" </dev/null
done < "${PROJECT_ROOT}/defaults/brew_pkgs.txt"

printf "${COLOR_SUCCESS}✅ Homebrew packages installation complete.${COLOR_RESET}\n"
