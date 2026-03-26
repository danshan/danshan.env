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
