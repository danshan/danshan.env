#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

activate_homebrew
acquire_brew_migration_lock \
    "${HOME}/Library/Application Support/danshan.env/locks"
trap release_brew_migration_lock EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
recover_interrupted_brew_migrations \
    "${HOME}/Library/Application Support/danshan.env/app-backups" \
    "${HOME}/Library/Application Support/danshan.env/font-backups"
load_brew_state cask
validate_brew_cask_manifest "${PROJECT_ROOT}/defaults/brew_casks.txt"
load_macos_state
migrate_missing_brew_font_casks \
    "${PROJECT_ROOT}/defaults/brew_casks.txt" \
    "${HOME}/Library/Fonts" \
    "${HOME}/Library/Application Support/danshan.env/font-backups"

log_title "Reconciling Homebrew casks."
while IFS='|' read -r package_name application_name existing_artifact_policy minimum_macos_major ||
    [[ -n "${package_name}" ]]; do
    case "${package_name}" in
        ''|'#'*) continue ;;
    esac
    if [[ "${existing_artifact_policy:-preserve}" == migrate ]] &&
        [[ -z "${application_name}" ]]; then
        normalized_name="$(normalize_brew_name "${package_name}")"
        if [[ "${#BREW_RECONCILED_ITEMS[@]}" -gt 0 ]] &&
            array_contains "${normalized_name}" "${BREW_RECONCILED_ITEMS[@]}"; then
            continue
        fi
        existing_artifact_policy=preserve
    fi
    reconcile_brew_package cask \
        "${package_name}" \
        "${application_name}" \
        "${existing_artifact_policy:-preserve}" \
        "${minimum_macos_major}" \
        "${HOME}/Library/Application Support/danshan.env/app-backups"
done < "${PROJECT_ROOT}/defaults/brew_casks.txt"

print_brew_summary "Cask"
