#!/bin/zsh #!/bin/bash

# Install and configure Homebrew

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

printf "${COLOR_TITLE}📦 Installing Homebrew...${COLOR_RESET}\n"

if test ! "$(command -v brew)"; then
    printf "${COLOR_SUBTITLE}📦 Homebrew not installed. Installing.${COLOR_RESET}\n"
    if [[ $(uname -s) = "Linux" ]] && [[ $(uname -m) = "aarch64" ]]; then
        printf "${COLOR_INFO}⚠️  danshan.env doesn't support limited Linux-son-ARM yet.${COLOR_RESET}"
        sleep 5
        exit
    elif [[ ${BREW_CN} ]]; then
        git clone --depth=1 https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/install.git /tmp/brew-install
        /bin/bash /tmp/brew-install/install.sh
        rm -rf /tmp/brew-install
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

printf "${COLOR_SUBTITLE}📦 Activating Homebrew on MacOS...${COLOR_RESET}\n"
if [[ $(uname -m) = "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/Homebrew/bin/brew shellenv)"
fi

printf "${COLOR_SUCCESS}✅ Homebrew setup complete.${COLOR_RESET}\n"
