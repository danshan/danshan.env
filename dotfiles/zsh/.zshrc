# OPENSPEC:START
# OpenSpec shell completions configuration
fpath=("${HOME}/.oh-my-zsh/custom/completions" $fpath)
autoload -Uz compinit
compinit
# OPENSPEC:END

# Path to your oh-my-zsh installation.
export ZSH=${HOME}/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
#ZSH_THEME="robbyrussell"
#ZSH_THEME=jispwoso
#ZSH_THEME=amuse
ZSH_THEME=refined

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
ZSH_CUSTOM="${ZSH}/custom"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#plugins=(git ssh-agent history extract zsh-autosuggestions oc kubectl helm)
plugins=(git history extract mvn httpie aliases)

# User configuration

export PATH="$HOME/.local/bin:$HOME/.bin:$PATH"

[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# Homebrew
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_NO_AUTO_UPDATE=true # no update when use brew
brew_executable="${commands[brew]:-}"
if [[ -z "$brew_executable" ]]; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      brew_executable="$candidate"
      break
    fi
  done
fi
[[ -n "$brew_executable" ]] && eval "$("$brew_executable" shellenv)"
unset brew_executable candidate

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
export EDITOR="vim"
alias vi='vim'
alias v='vim'
#alias nv='neovide --multigrid'
#alias vv='neovide --multigrid'

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
alias fuckgfw='export https_proxy=http://127.0.0.1:6152;export http_proxy=http://127.0.0.1:6152;export all_proxy=socks5://127.0.0.1:6153;export no_proxy=localhost,127.0.0.1,10.96.0.0/12,192.168.0.0/16'
alias noproxy='unset http_proxy https_proxy all_proxy no_proxy'

# config for autojump
if (( $+commands[brew] )); then
  autojump_init="$(brew --prefix)/etc/profile.d/autojump.sh"
  [[ -r "$autojump_init" ]] && source "$autojump_init"
  unset autojump_init
fi


# iTerm2 shell integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Host Shell plugins are installed through Homebrew.
for plugin_file in "${HOMEBREW_PREFIX:-}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "${HOMEBREW_PREFIX:-}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  [[ ! -r "$plugin_file" ]] || source "$plugin_file"
done
unset plugin_file

# mise 
(( $+commands[mise] )) && eval "$(mise activate zsh)"

# maven
export MVNW_VERBOSE=true

## gron https://github.com/tomnomnom/gron
alias norg="gron --ungron"
alias ungron="gron --ungron"

# git-repo
export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'

# fzf
(( $+commands[fzf] )) && source <(fzf --zsh)

# Kiro
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# OpenClaw Completion
test -e "${HOME}/.openclaw/completions/openclaw.zsh" && source "${HOME}/.openclaw/completions/openclaw.zsh"

# Starship
(( $+commands[starship] )) && eval "$(starship init zsh)"

# Explicit unsafe alias
alias claude-unsafe="claude --dangerously-skip-permissions"

[[ ! -r "$HOME/.zsh.local.sh" ]] || source "$HOME/.zsh.local.sh"
