#!/bin/bash

sh -x

# install brew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew install thefuck
brew install rbenv
brew install wget 

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# install jenv
curl -L -s get.jenv.io | bash
