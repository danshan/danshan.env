#!/bin/bash #!/bin/zsh

export DANSHAN_ENV=${DANSHAN_ENV:-"${HOME}/.config/danshan.env"}
printf "📦 Installing danshan.env\n"


###################################################
# Install Homebrew
###################################################

if test ! "$(command -v brew)"; then
    printf "📦 Homebrew not installed. Installing.\n"
    if [[ $(uname -s) = "Linux" ]] && [[ $(uname -m) = "aarch64" ]]; then
        printf "⚠️  danshan.env doesn't support limited Linux-son-ARM yet."
        sleep 5
        exit
    elif [[ ${BREW_CN} ]]; then
        /bin/bash -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

printf "⚙️  Adding Custom settings...\n"
cp -i -v ${DANSHAN_ENV}/defaults.sh ${DANSHAN_ENV}/custom.sh

printf "📦 Activating Homebrew on MacOS...\n"
if [[ $(uname -m) = "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/Homebrew/bin/brew shellenv)"
fi

brew tap homebrew/cask-fonts
brew tap homebrew/services
brew tap homebrew/bundle

###################################################
# Install Packages
###################################################

printf "📦 Installing essential danshan.env toolchains...\n"

cat ${DANSHAN_ENV}/defaults/brew_pkgs.txt | while read -r pkg; do
    brew install "$pkg"
done

cat ${DANSHAN_ENV}/defaults/brew_casks.txt | while read -r pkg; do
    brew install --cask "$pkg"
done

###################################################
# Update Shell Settings
###################################################

printf "⚙️  Configuring Shell...\n"
case ${SHELL} in
*zsh)
    export DS_SHELL=${HOME}/.zshrc
    ln -s -f ${DS_SHELL} ${HOME}/.zshrc
    ;;
*bash)
    if [[ $(bash --version | head -n1 | cut -d' ' -f4 | cut -d'.' -f1) -lt 5 ]]; then
        printf "📦 Installing latest Bash...\n"
        brew install bash bash-completion
    fi
    export DS_SHELL=${HOME}/.bashrc
    ln -s -f ${DS_SHELL} ${HOME}/.bashrc
    ;;
esac


printf "🎉 danshan.env installation complete!\n"
printf "💡 Don't forget to restart your terminal to tweak your preferences.\n"

