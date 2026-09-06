#!/bin/bash

BASH_SILENCE_DEPRECATION_WARNING=1

export PATH="$HOME/.local/bin:$HOME/.bin:$PATH"

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

# Mise owns language runtimes and development CLI tools.
if command -v mise >/dev/null 2>&1; then
  if [[ "$-" == *i* ]]; then
    eval "$(mise activate bash)"
  else
    eval "$(mise activate bash --shims)"
  fi
fi
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"

# https://starship.rs/
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"

###_BEGIN_Completion_ae
test -e "${HOME}/.completion/ae.completion.sh" && source "${HOME}/.completion/ae.completion.sh"
###_END_Completion_ae

[[ ! -r "$HOME/.bash.local.sh" ]] || source "$HOME/.bash.local.sh"
