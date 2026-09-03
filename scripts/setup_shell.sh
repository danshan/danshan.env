#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_tool_versions

log_title "Configuring shell frameworks."
ensure_pinned_git_repository \
    "Oh My Zsh" \
    "https://github.com/ohmyzsh/ohmyzsh.git" \
    "${HOME}/.oh-my-zsh" \
    "${OH_MY_ZSH_REF}"

ensure_pinned_git_repository \
    "oh-my-tmux" \
    "https://github.com/gpakosz/.tmux.git" \
    "${HOME}/.config/oh-my-tmux" \
    "${OH_MY_TMUX_REF}"

ensure_symlink \
    "${HOME}/.config/oh-my-tmux/.tmux.conf" \
    "${HOME}/.tmux.conf"

log_success "Shell framework setup complete."
