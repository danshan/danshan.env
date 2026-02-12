#!/bin/zsh #!/bin/bash

export DANSHAN_ENV=${DANSHAN_ENV:-"${HOME}/.config/danshan.env"}
printf "📦 Installing danshan.env\n"

# Check if .bin directory exists, create if not
if [ ! -d "${HOME}/.bin" ]; then
    printf "📦 Creating ${HOME}/.bin directory\n"
    mkdir -p "${HOME}/.bin"
else
    printf "✅ ${HOME}/.bin directory already exists\n"
fi

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
        git clone --depth=1 https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/install.git /tmp/brew-install
        /bin/bash /tmp/brew-install/install.sh
        rm -rf /tmp/brew-install
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

brew tap localsend/localsend
brew tap daipeihust/tap

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

printf "📦 Configuring Completions in zsh...\n"
# https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh
brew cleanup && rm -f $ZSH_COMPDUMP && omz reload

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

printf "📦 Installing oh-my-tmux...\n"
git clone https://github.com/gpakosz/.tmux.git ${HOME}/.config/oh-my-tmux 
ln -f -s ${HOME}/.config/oh-my-tmux/.tmux.conf ${HOME}/.tmux.conf
ln -s -f ${DANSHAN_ENV}/dotfiles/_tmux.conf.local ${HOME}/.tmux.conf.local
tmux source-file ${HOME}/.tmux.conf

printf "📦 Installing uv...\n"
curl -LsSf https://astral.sh/uv/install.sh | sh

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

###################################################
# Install configs
###################################################

printf "⚙️  Configuring neovim...\n"
if [ -d "${HOME}/.config/nvim" ]; then
    printf "📦 Updating neovim config...\n"
    cd ${HOME}/.config/nvim
    git pull
    cd -
else
    git clone --depth=1 git@github.com:danshan/lazyvim.git ${HOME}/.config/nvim
fi

printf "⚙️  Configuring zed...\n"
if [ -d "${HOME}/.config/zed" ]; then
    printf "📦 Updating zed config...\n"
    cd ${HOME}/.config/zed
    git pull
    cd -
else
    git clone --depth=1 git@github.com:danshan/zed-config.git ${HOME}/.config/zed
fi

# printf "⚙️  Configuring warp...\n"
# mkdir -p ${HOME}/.warp
# git clone --depth=1 git@github.com:danshan/warp-workflows.git ${HOME}/.warp/workflows
# mkdir -p ${HOME}/.warp/themes
# cp -f ${HOME}/.config/catppuccin-warp/dist/*.yml ${HOME}/.warp/themes/


###################################################
# Install Developing Envornment
###################################################

source ~/.zshrc

printf "⚙️  Configuring asdf java...\n"
asdf plugin add java

printf "⚙️  Configuring asdf maven...\n"
asdf plugin add maven

printf "⚙️  Configuring asdf nodejs...\n"
asdf plugin add nodejs 22.20.0
asdf install nodejs 22.20.0

printf "⚙️  Configuring asdf python...\n"
asdf plugin add python

source ~/.zshrc

printf "❇️  Configuring codex...\n"
npm i -g @openai/codex
printf "❇️  Configuring gemini-cli...\n"
npm i -g @google/gemini-cli


printf "❇️  Configuring opencode...\n"
curl -fsSL https://opencode.ai/install | bash
printf "❇️  Configuring oh-my-opencode...\n"
npm install -g oh-my-opencode

###################################################
# Finished
###################################################

printf "🎉 danshan.env installation complete!\n"
printf "💡 Don't forget to restart your terminal to tweak your preferences.\n"
