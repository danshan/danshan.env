#!/bin/zsh #!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"

printf "${COLOR_TITLE}📦 Installing danshan.env${COLOR_RESET}\n"

# Check if .bin directory exists, create if not
if [ ! -d "${HOME}/.bin" ]; then
    printf "${COLOR_SUBTITLE}📦 Creating ${HOME}/.bin directory${COLOR_RESET}\n"
    mkdir -p "${HOME}/.bin"
else
    printf "${COLOR_SUCCESS}✅ ${HOME}/.bin directory already exists${COLOR_RESET}\n"
fi

# Step 1: Homebrew
source "${SCRIPT_DIR}/scripts/setup_homebrew.sh"

# Step 2: Shell environment (oh-my-zsh)
source "${SCRIPT_DIR}/scripts/setup_shell.sh"

# Step 3: Packages (brew pkgs/casks, oh-my-tmux, uv)
source "${SCRIPT_DIR}/scripts/install_packages.sh"

# Step 4: Dotfiles configuration
source "${SCRIPT_DIR}/scripts/setup_dotfiles.sh"

# Step 5: Development environment (asdf, npm tools)
source "${SCRIPT_DIR}/scripts/setup_devenv.sh"

###################################################
# Finished
###################################################

printf "${COLOR_TITLE}🎉 danshan.env installation complete!${COLOR_RESET}\n"
printf "💡 Don't forget to restart your terminal to tweak your preferences.\n"
