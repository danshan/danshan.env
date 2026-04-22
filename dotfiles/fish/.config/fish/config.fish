set fish_greeting

if status is-interactive
    eval (zellij setup --generate-auto-start fish | string collect)
end

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$PATH:$HOME/.bin"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/.bun/bin"

# Homebrew
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_NO_AUTO_UPDATE=true # no update when use brew
eval $(/opt/homebrew/bin/brew shellenv)

# ASDF https://asdf-vm.com/
if test -z $ASDF_DATA_DIR
    set _asdf_shims "$HOME/.asdf/shims"
else
    set _asdf_shims "$ASDF_DATA_DIR/shims"
end

# Do not use fish_add_path (added in Fish 3.2) because it
# potentially changes the order of items in PATH
if not contains $_asdf_shims $PATH
    set -gx --prepend PATH $_asdf_shims
end
set --erase _asdf_shims

# Starfish https://starship.rs/
starship init fish | source

# zoxide https://github.com/ajeetdsouza/zoxide
zoxide init fish | source

# fzf https://github.com/junegunn/fzf
fzf --fish | source

# Http Proxy
function fuckgfw
    set -gx https_proxy http://127.0.0.1:6152
    set -gx http_proxy http://127.0.0.1:6152
    set -gx all_proxy socks5://127.0.0.1:6153
    set -gx no_proxy localhost,127.0.0.1,10.96.0.0/12,192.168.0.0/16
end
function noproxy
    unset http_proxy https_proxy all_proxy no_proxy
end

# Claude Code
alias claude="claude --dangerously-skip-permissions"
# Github Copilot
alias copilot="copilot --yolo"
# Sublime
alias subl="'/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl'"
# VSCode
alias code="'/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code'"
