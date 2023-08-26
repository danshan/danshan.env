#!/bin/bash

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH=${PATH}:${HOME}/.ssh/usm

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
. "$HOME/.cargo/env"

BASH_SILENCE_DEPRECATION_WARNING=1

###_BEGIN_Completion_ae
test -e "/Users/honghao.shan/.completion/ae.completion.sh" &&  source "/Users/honghao.shan/.completion/ae.completion.sh"
###_END_Completion_ae
