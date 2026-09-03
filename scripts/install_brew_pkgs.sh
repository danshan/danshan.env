#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

activate_homebrew
load_brew_state formula

log_title "Reconciling Homebrew formulae."
while IFS= read -r package_name || [[ -n "${package_name}" ]]; do
    case "${package_name}" in
        ''|'#'*) continue ;;
    esac
    reconcile_brew_package formula "${package_name}"
done < "${PROJECT_ROOT}/defaults/brew_pkgs.txt"

print_brew_summary "Formula"
