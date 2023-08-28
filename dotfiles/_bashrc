#!/bin/bash

BASH_SILENCE_DEPRECATION_WARNING=1

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

export WORKON_HOME=$HOME/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON=$HOMEBREW_PREFIX/bin/python3
export VIRTUALENVWRAPPER_VIRTUALENV=$HOMEBREW_PREFIX/bin/virtualenv

# nvm
# brew install nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"  # This loads nvm
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
. "$HOME/.cargo/env"

# https://starship.rs/
eval "$(starship init bash)"

###_BEGIN_Completion_ae
test -e "/Users/honghao.shan/.completion/ae.completion.sh" &&  source "/Users/honghao.shan/.completion/ae.completion.sh"
###_END_Completion_ae
