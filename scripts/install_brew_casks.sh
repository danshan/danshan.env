#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

activate_homebrew
load_brew_state cask

log_title "Reconciling Homebrew casks."
while IFS='|' read -r package_name application_name existing_app_policy || [[ -n "${package_name}" ]]; do
    case "${package_name}" in
        ''|'#'*) continue ;;
    esac
    reconcile_brew_package cask "${package_name}" "${application_name}" "${existing_app_policy:-preserve}"
done < "${PROJECT_ROOT}/defaults/brew_casks.txt"

print_brew_summary "Cask"
