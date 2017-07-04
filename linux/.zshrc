# Path to your oh-my-zsh installation.
export ZSH=/Users/dan/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

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
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git autojump ssh-agent)

# User configuration

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

export JAVA_HOME="/Users/dan/.jenv/candidates/java/1.8"
export PATH="$PATH:$JYTHON_HOME/bin"
export PATH="$PATH:$ARCANIST_HOME/bin"
# export MANPATH="/usr/local/man:$MANPATH"
#export PYTHONPATH=/usr/local/Cellar/ansible/2.1.0.0/libexec/lib/python2.7/site-packages

eval $(thefuck --alias)

source $ZSH/oh-my-zsh.sh
#source /usr/local/bin/virtualenvwrapper.sh


# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='mvim'
fi

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
alias nano="subl"
export EDITOR="vim"

# alias wdproxy='export http_proxy=socks5://vpn08.iladder.win:25; export https_proxy=socks5://vpn08.iladder.win:25; export no_proxy=localhost,127.0.0.0/8,127.0.1.1,127.0.1.1*,local.home,*.wanda.cn,*.wanda.com,*.wanda.net; echo "use proxy for wanda"'
#alias wdproxy1='export http_proxy=http://shanhonghao:9fzzbFXnS2@10.15.206.30:8080; export https_proxy=http://shanhonghao:9fzzbFXnS2@10.15.206.30:8080; export no_proxy=localhost,127.0.0.0/8,127.0.1.1,127.0.1.1*,local.home,*.wanda.cn,*.wanda.net,*.wanda.com; echo "use proxy1 for wanda"'
#alias gfwproxy='export http_proxy=socks5://127.0.0.1:1234; export https_proxy=socks5://127.0.0.1:1234; echo "use proxy for gfw"'
alias fuckgfw='export https_proxy=http://127.0.0.1:1235;export http_proxy=http://127.0.0.1:1235;export no_proxy=localhost,127.0.0.0/8,10.0.0.0/8,local.home,*.wanda.cn,*.wanda.net,*.wanda.com,*.wanda-itg.local,*.wanda-group.net;echo "use proxy $http_proxy"'
alias noproxy='unset http_proxy https_proxy; echo "stop proxy"'
alias jump='ssh 10.214.124.132'

#THIS MUST BE AT THE END OF THE FILE FOR JENV TO WORK!!!
[[ -s "/Users/dan/.jenv/bin/jenv-init.sh" ]] && source "/Users/dan/.jenv/bin/jenv-init.sh" && source "/Users/dan/.jenv/commands/completion.sh"
eval "$(rbenv init -)"

export NVM_DIR="/Users/dan/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

[[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh

