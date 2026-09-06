set fish_greeting

set -gx PATH "$HOME/.local/bin" "$HOME/.bin" $PATH

# Homebrew
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_NO_AUTO_UPDATE=true # no update when use brew
set -l brew_executable (command -v brew)
if test -z "$brew_executable"
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew
    if test -x "$candidate"
      set brew_executable "$candidate"
      break
    end
  end
end
if test -n "$brew_executable"
  env SHELL=(status fish-path) "$brew_executable" shellenv | source
end

# mise https://mise.jdx.dev/ide-integration.html
if command -q mise
  if status is-interactive
    mise activate fish | source
  else
    mise activate fish --shims | source
  end
end

# Starfish https://starship.rs/
command -q starship; and starship init fish | source

# zoxide https://github.com/ajeetdsouza/zoxide
command -q zoxide; and zoxide init fish | source

# fzf https://github.com/junegunn/fzf
command -q fzf; and fzf --fish | source
set fzf_history_time_format '%Y-%m-%d %H:%M:%S'

# Http Proxy
function fuckgfw
    set -gx https_proxy http://127.0.0.1:6152
    set -gx http_proxy http://127.0.0.1:6152
    set -gx all_proxy socks5://127.0.0.1:6153
    set -gx no_proxy localhost,127.0.0.1,10.96.0.0/12,192.168.0.0/16
end
function noproxy
    set -e http_proxy https_proxy all_proxy no_proxy
end

# Explicit unsafe aliases
alias claude-unsafe="claude --dangerously-skip-permissions"
alias copilot-unsafe="copilot --yolo"
# Sublime
alias subl="'/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl'"
# VSCode
alias code="'/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code'"

# history
function history
    builtin history --show-time="%F %T " $argv
end

# fzf.fish https://github.com/PatrickF1/fzf.fish
functions -q fzf_configure_bindings; and fzf_configure_bindings --directory=ctrl-f

# OpenSpec
export OPENSPEC_TELEMETRY=0


# Added by Antigravity IDE
fish_add_path --global "$HOME/.antigravity-ide/antigravity-ide/bin"

# Codex app proxy
function codex-app
    set -x ALL_PROXY http://127.0.0.1:6152
    set -x all_proxy http://127.0.0.1:6152
    set -x http_proxy http://127.0.0.1:6152
    set -x https_proxy http://127.0.0.1:6152
    set -x HTTP_PROXY http://127.0.0.1:6152
    set -x HTTPS_PROXY http://127.0.0.1:6152
    set -x npm_config_proxy http://127.0.0.1:6152
    set -x npm_config_https_proxy http://127.0.0.1:6152

    nohup /Applications/Codex.app/Contents/MacOS/Codex >/dev/null 2>&1 &
end

function chatgpt-app 
    set -x ALL_PROXY http://127.0.0.1:6152
    set -x all_proxy http://127.0.0.1:6152
    set -x http_proxy http://127.0.0.1:6152
    set -x https_proxy http://127.0.0.1:6152
    set -x HTTP_PROXY http://127.0.0.1:6152
    set -x HTTPS_PROXY http://127.0.0.1:6152
    set -x npm_config_proxy http://127.0.0.1:6152
    set -x npm_config_https_proxy http://127.0.0.1:6152

    nohup /Applications/ChatGPT.app/Contents/MacOS/ChatGPT >/dev/null 2>&1 &
end

# >>> otty shell integration >>>
# Added by Otty — toggle in Settings > Shell > Shell Integration.
# Inert unless launched by Otty (it sets $OTTY_SHELL_INTEGRATION).
if test -n "$OTTY_SHELL_INTEGRATION" -a -r "$OTTY_SHELL_INTEGRATION/otty-integration.fish"
    source "$OTTY_SHELL_INTEGRATION/otty-integration.fish"
end
# <<< otty shell integration <<<

# >>> grok installer >>>
fish_add_path --global "$HOME/.grok/bin"
# <<< grok installer <<<
