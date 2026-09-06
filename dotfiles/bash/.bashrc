#!/bin/bash

BASH_SILENCE_DEPRECATION_WARNING=1

export PATH="$HOME/.bun/bin:$HOME/.local/bin:$HOME/.bin:/usr/local/go/bin:$PATH"

brew_executable="$(command -v brew 2>/dev/null || true)"
if [[ -z "${brew_executable}" ]]; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "${candidate}" ]]; then
      brew_executable="${candidate}"
      break
    fi
  done
fi
if [[ -n "${brew_executable}" ]]; then
  eval "$(env SHELL=/bin/bash "${brew_executable}" shellenv)"
fi
unset brew_executable candidate

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

export WORKON_HOME=$HOME/.virtualenvs
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  export VIRTUALENVWRAPPER_PYTHON="$HOMEBREW_PREFIX/bin/python3"
  export VIRTUALENVWRAPPER_VIRTUALENV="$HOMEBREW_PREFIX/bin/virtualenv"
fi

# nvm
# brew install nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"  # This loads nvm
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
[[ -r "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# https://starship.rs/
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"

###_BEGIN_Completion_ae
test -e "${HOME}/.completion/ae.completion.sh" && source "${HOME}/.completion/ae.completion.sh"
###_END_Completion_ae
