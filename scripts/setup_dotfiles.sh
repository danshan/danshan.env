#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

activate_homebrew
require_command git
require_command stow

stow_package() {
    local package_name="$1"
    local package_path="${DOTFILES_DIR}/${package_name}"

    [[ -d "${package_path}" ]] || {
        die "Dotfile package not found: ${package_name}"
        return 1
    }
    if [[ -z "$(find "${package_path}" -type f -print -quit)" ]]; then
        log_notice "Skipping empty dotfile package: ${package_name}"
        return
    fi

    log_info "Applying dotfile package: ${package_name}"
    stow --dir "${DOTFILES_DIR}" --target "${HOME}" --restow --verbose "${package_name}"
}

log_title "Configuring dotfiles."

case "${SHELL:-}" in
    */zsh)
        stow_package zsh
        ;;
    */bash)
        stow_package bash
        ;;
    */fish)
        stow_package fish
        ;;
    *)
        die "Unsupported or unset login shell: ${SHELL:-unset}"
        ;;
esac

for package_name in \
    vim \
    fzf \
    git \
    screen \
    starship \
    tmux \
    nvim \
    ghostty \
    cmux \
    fastfetch \
    zellij \
    fd \
    hammerspoon \
    codex \
    gemini \
    claude \
    pi \
    herdr; do
    stow_package "${package_name}"
done

ensure_tracking_git_repository \
    "Zed configuration" \
    "git@github.com:danshan/zed-config.git" \
    "${HOME}/.config/zed"

log_success "Dotfiles configuration complete."
