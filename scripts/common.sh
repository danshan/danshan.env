#!/bin/zsh #!/bin/bash

# Common variables and helpers for danshan.env scripts

# Resolve the root directory of this project
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${(%):-%x}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
export PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export DOTFILES_DIR="${PROJECT_ROOT}/dotfiles"

# ANSI color codes for titles
export COLOR_TITLE="\033[1;36m"      # Bold cyan for main titles
export COLOR_SUBTITLE="\033[1;33m"   # Bold yellow for subtitles
export COLOR_SUCCESS="\033[0;32m"    # Green for success messages
export COLOR_INFO="\033[0;34m"       # Blue for info messages
export COLOR_RESET="\033[0m"         # Reset color
