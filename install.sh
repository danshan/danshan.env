#!/bin/zsh #!/bin/bash

export DANSHAN_ENV=${DANSHAN_ENV:-"${HOME}/.config/danshan.env"}
printf "📦 Installing danshan.env\n"

mkdir ${HOME}/.bin

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

printf "📦 Activating Homebrew on MacOS...\n"
if [[ $(uname -m) = "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/Homebrew/bin/brew shellenv)"
fi

#brew tap homebrew/cask-fonts
brew tap homebrew/services
brew tap homebrew/bundle
brew tap localsend/localsend

###################################################
# Install Shell Environments
###################################################

printf "📦 Installing oh-my-zsh...\n"
if [[ ${BREW_CN} ]]; then
    sh -c "$(curl -fsSL https://gitee.com/shmhlsy/oh-my-zsh-install.sh/raw/master/install.sh)"
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi


###################################################
# Install Packages
###################################################

printf "📦 Installing essential danshan.env toolchains...\n"

brew update

cat ${DANSHAN_ENV}/defaults/brew_pkgs.txt | while read -r pkg; do
    printf "📦 Installing homebrew package: ${pkg}\n"
    brew install "$pkg"
done

cat ${DANSHAN_ENV}/defaults/brew_casks.txt | while read -r pkg; do
    pkg_name="$(echo ${pkg} | awk -F '|' '{ print $1 }')"
    app_name="$(echo ${pkg} | awk -F '|' '{ print $2 }')"
    if [ -e "/Applications/${app_name}.app" ]; then
        printf "✅ Application ${app_name} exists.\n"
    else 
        printf "📦 Installing ${pkg_name}...\n"
        brew install --cask "$pkg_name"
    fi
done

printf "📦 Installing sdkman...\n"
curl -s "https://get.sdkman.io" | bash

printf "📦 Installing catppuccin themes...\n"
git clone --depth=1 https://github.com/catppuccin/iterm.git ${HOME}/.config/catppuccin-iterm
git clone --depth=1 https://github.com/catppuccin/sublime-text.git ${HOME}/.config/catppuccin-sublime
git clone --depth=1 https://github.com/catppuccin/Terminal.app.git ${HOME}/.config/catppuccin-terminal
git clone --depth=1 https://github.com/catppuccin/alacritty.git ${HOME}/.config/catppuccin-alacritty
git clone --depth=1 https://github.com/catppuccin/warp.git ${HOME}/.config/catppuccin-warp 

printf "📦 Installing oh-my-tmux...\n"
git clone https://github.com/gpakosz/.tmux.git ${HOME}/.config/oh-my-tmux 
ln -f -s ${HOME}/.config/oh-my-tmux/.tmux.conf ${HOME}/.tmux.conf
ln -s -f ${DANSHAN_ENV}/dotfiles/_tmux.conf.local ${HOME}/.tmux.conf.local
tmux source-file ${HOME}/.tmux.conf

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
ln -s -f ${DANSHAN_ENV}/dotfiles/_ideavimrc ${HOME}/.ideavimrc
ln -s -f ${DANSHAN_ENV}/dotfiles/_screenrc ${HOME}/.screenrc
ln -s -f ${DANSHAN_ENV}/dotfiles/_fzf.zsh ${HOME}/.fzf.zsh
ln -s -f ${DANSHAN_ENV}/dotfiles/_fzf.bash ${HOME}/.fzf.bash
ln -s -f ${DANSHAN_ENV}/dotfiles/_gitignore ${HOME}/.gitignore
# ln -s -f ${DANSHAN_ENV}/dotfiles/_alacritty.toml ${HOME}/.alacritty.toml
# ln -s -f ${DANSHAN_ENV}/dotfiles/_alacritty.yml ${HOME}/.alacritty.yml

###################################################
# Install configs
###################################################

printf "⚙️  Configuring hammerspoon...\n"
git clone --depth=1 git@github.com/danshan/hammerspoon-config.git ${HOME}/.hammerspoon

printf "⚙️  Configuring neovim...\n"
git clone --depth=1 git@github.com/danshan/lazyvim.git ${HOME}/.config/nvim

# printf "⚙️  Configuring zed...\n"
# git clone --depth=1 git@github.com/danshan/zed-config.git ${HOME}/.config/zed

# printf "⚙️  Configuring warp...\n"
# mkdir -p ${HOME}/.warp
# git clone --depth=1 git@github.com:danshan/warp-workflows.git ${HOME}/.warp/workflows
# mkdir -p ${HOME}/.warp/themes
# cp -f ${HOME}/.config/catppuccin-warp/dist/*.yml ${HOME}/.warp/themes/

printf "🎉 danshan.env installation complete!\n"
printf "💡 Don't forget to restart your terminal to tweak your preferences.\n"

