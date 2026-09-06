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
    local migration_exit_code

    [[ -d "${package_path}" ]] || {
        die "Dotfile package not found: ${package_name}"
        return 1
    }
    if [[ -z "$(find "${package_path}" -type f -print -quit)" ]]; then
        log_notice "Skipping empty dotfile package: ${package_name}"
        return
    fi

    log_info "Applying dotfile package: ${package_name}"
    if [[ "${package_name}" == mise ]]; then
        if migrate_legacy_stow_file \
            "${package_name}" ".config/mise/config.toml" \
            "${HOME}/Library/Application Support/danshan.env/dotfile-backups"; then
            return
        else
            migration_exit_code=$?
            [[ "${migration_exit_code}" -eq 2 ]] || return "${migration_exit_code}"
        fi
    fi
    if is_read_only_mode; then
        stow --dir "${DOTFILES_DIR}" --target "${HOME}" --restow --simulate "${package_name}"
    else
        stow --dir "${DOTFILES_DIR}" --target "${HOME}" --restow --verbose "${package_name}"
    fi
}

log_title "Configuring dotfiles."

recover_interrupted_stow_migrations \
    "${HOME}/Library/Application Support/danshan.env/dotfile-backups"

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

while IFS= read -r package_name || [[ -n "${package_name}" ]]; do
    case "${package_name}" in
        ''|'#'*) continue ;;
    esac
    stow_package "${package_name}"
done < "${PROJECT_ROOT}/defaults/dotfile_pkgs.txt"

ensure_tracking_git_repository \
    "Zed configuration" \
    "git@github.com:danshan/zed-config.git" \
    "${HOME}/.config/zed"

log_success "Dotfiles configuration complete."
