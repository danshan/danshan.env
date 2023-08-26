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
# Install Shell Environments
###################################################

printf "📦 Installing oh-my-zsh...\n"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

printf "📦 Installing sdkman...\n"
curl -s "https://get.sdkman.io" | bash


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
    ln -s -f ${DANSHAN_ENV}/dotfiles/_zshrc ${DS_SHELL}
    ;;
*bash)
    if [[ $(bash --version | head -n1 | cut -d' ' -f4 | cut -d'.' -f1) -lt 5 ]]; then
        printf "📦 Installing latest Bash...\n"
        brew install bash bash-completion
    fi
    export DS_SHELL=${HOME}/.bashrc
    ln -s -f ${DANSHAN_ENV}/dotfiles/_bashrc ${DS_SHELL}
    ;;
esac

ln -s -f ${DANSHAN_ENV}/dotfiles/_vimrc ${HOME}/.vimrc
ln -s -f ${DANSHAN_ENV}/dotfiles/_screenrc ${HOME}/.screenrc
ln -s -f ${DANSHAN_ENV}/dotfiles/_tmux.conf ${HOME}/.tmux.conf
ln -s -f ${DANSHAN_ENV}/dotfiles/_ideavimrc.conf ${HOME}/.ideavimrc

###################################################
# Install configs
###################################################

printf "⚙️  Configuring hammerspoon...\n"
git clone https://github.com/danshan/hammerspoon-config.git ~/.hammerspoon

printf "⚙️  Configuring neovim...\n"
git clone https://github.com/danshan/nvim.git ~/.config/nvim

printf "🎉 danshan.env installation complete!\n"
printf "💡 Don't forget to restart your terminal to tweak your preferences.\n"

