#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

activate_homebrew
load_brew_trust_state

log_title "Reconciling Homebrew package trust."
while IFS='|' read -r package_type package_name || [[ -n "${package_type}${package_name}" ]]; do
    case "${package_type}" in
        ''|'#'*) continue ;;
    esac
    [[ -n "${package_name}" ]] || {
        die "Invalid Homebrew trust manifest entry: ${package_type}"
        exit 1
    }
    reconcile_brew_trust "${package_type}" "${package_name}"
done < "${PROJECT_ROOT}/defaults/brew_trust.txt"

print_brew_trust_summary
