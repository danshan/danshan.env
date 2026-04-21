export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$PATH:$HOME/.bin"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/.bun/bin"

# Homebrew
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_NO_AUTO_UPDATE=true # no update when use brew
eval $(/opt/homebrew/bin/brew shellenv)

# Starfish https://starship.rs/
starship init fish | source

# zoxide https://github.com/ajeetdsouza/zoxide
zoxide init fish | source

# fzf https://github.com/junegunn/fzf
fzf --fish | source

# claude
alias claude="claude --dangerously-skip-permissions"
