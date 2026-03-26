#!/bin/zsh #!/bin/bash

# Install oh-my-zsh

printf "📦 Installing oh-my-zsh...\n"
if [[ ${BREW_CN} ]]; then
    sh -c "$(curl -fsSL https://gitee.com/shmhlsy/oh-my-zsh-install.sh/raw/master/install.sh)"
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

printf "✅ Shell environment setup complete.\n"
