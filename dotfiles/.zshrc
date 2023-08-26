# INIT MAC
#
# install Command Line Tools
# xcode-select --install
# 
# install software manager homebrew(maybe very slowly - you can use cellular)
#
# /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
#
# change mirror to tuna
# cd "$(brew --repo)"
# git remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
# cd "$(brew --repo)/Library/Taps/homebrew/homebrew-core"
# git remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git

# Path to your oh-my-zsh installation.
export ZSH=${HOME}/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
#ZSH_THEME="robbyrussell"
ZSH_THEME=jispwoso

# Uncomment the following line to use case-sensitive completion.
CASE_SENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder
ZSH_CUSTOM=${HOME}/Dropbox/sync/mac/.oh-my-zshrc

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#plugins=(git ssh-agent history extract zsh-autosuggestions oc kubectl helm)
plugins=(git ssh-agent history extract zsh-autosuggestions mvn httpie aliases)

# User configuration

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$PATH:${HOME}/.bin"
export PATH="$PATH:${HOME}/.local/bin"
export PATH="$PATH:/usr/local/go/bin"

source $ZSH/oh-my-zsh.sh

# Homebrew
export HOMEBREW_NO_AUTO_UPDATE=true # no update when use brew
eval $(/opt/homebrew/bin/brew shellenv)

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if test ! "$(command -v nvim)"; then
    export EDITOR="nvim"
    alias vim='nvim'
    alias vi='nvim'
    alias v='nvim'
else 
    export EDITOR="vim"
    alias vim='vim'
    alias vi='vim'
    alias v='vim'
    
alias nv='neovide --multigrid'
alias vv='neovide --multigrid'

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias subl="'/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl'"
alias code="'/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code'"
alias nano="subl"
alias fuckgfw='export https_proxy=http://127.0.0.1:6152;export http_proxy=http://127.0.0.1:6152;export all_proxy=socks5://127.0.0.1:6153;export no_proxy=localhost,127.0.0.1,10.96.0.0/12,192.168.99.0/24,192.168.39.0/24'
alias noproxy='unset http_proxy https_proxy all_proxy no_proxy'

## proxy
#export https_proxy=http://127.0.0.1:1235;export http_proxy=http://127.0.0.1:1235;export all_proxy=socks5://127.0.0.1:1234

#THIS MUST BE AT THE END OF THE FILE FOR JENV TO WORK!!!
#eval "$(rbenv init -)"

# config for autojump
[ -f $(brew --prefix)/etc/profile.d/autojump.sh ] && . $(brew --prefix)/etc/profile.d/autojump.sh

# Add JAVA_HOME
export JAVA_HOME="${HOME}/.sdkman/candidates/java/current"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

test -e "${HOME}/.iterm2_shell_integration.zsh" && echo "loading shell integration" && source "${HOME}/.iterm2_shell_integration.zsh"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# fzf
#export FZF_DEFAULT_COMMAND='fd --type file'
#export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
#export FZF_ALT_C_COMMAND="fd -t d . "
#export FZF_DEFAULT_OPTS='--height 40% --reverse --border'
#[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
#alias pp='fzf --preview '"'"'[[ $(file --mime {}) =~ binary ]] && echo {} is a binary file || (highlight -O ansi -l {} || coderay {} || rougify {} || cat {}) 2> /dev/null | head -500'"'"
#alias oo='fzf --preview '"'"'[[ $(file --mime {}) =~ binary ]] && echo {} is a binary file || (highlight -O ansi -l {} || coderay {} || rougify {} || tac {}) 2> /dev/null | head -500'"'"  # flashback

source $ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

export PATH="/usr/local/opt/openssl@1.1/bin:$PATH"
export PATH="/usr/local/opt/ruby/bin:$PATH"

# thefuck
#eval $(thefuck --alias)


# virtualenvwrapper
export WORKON_HOME=$HOME/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON=$HOMEBREW_PREFIX/bin/python3
export VIRTUALENVWRAPPER_VIRTUALENV=$HOMEBREW_PREFIX/bin/virtualenv
#source $HOMEBREW_PREFIX/bin/virtualenvwrapper.sh

# maven
export MVNW_VERBOSE=true

## gron https://github.com/tomnomnom/gron
alias norg="gron --ungron"
alias ungron="gron --ungron"

# git-repo
export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'

# nvm
# brew install nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# starship
#eval "$(starship init zsh)"


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('${HOME}/workspace/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "${HOME}/workspace/miniconda3/etc/profile.d/conda.sh" ]; then
        . "${HOME}/workspace/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="${HOME}/workspace/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


###_BEGIN_Completion_ae
test -e "${HOME}/.completion/ae.completion.sh" &&  source "${HOME}/.completion/ae.completion.sh"
###_END_Completion_ae
