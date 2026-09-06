#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

activate_homebrew
require_command mise

MISE_CONFIG_SOURCE="${DOTFILES_DIR}/mise/.config/mise/config.toml"
MISE_CONFIG_TARGET="${HOME}/.config/mise/config.toml"
if [[ "${DANSHAN_MODE:-apply}" == apply ]]; then
    [[ -L "${MISE_CONFIG_TARGET}" || -f "${MISE_CONFIG_TARGET}" ]] ||
        die "Mise global configuration is not installed: ${MISE_CONFIG_TARGET}"
    export MISE_GLOBAL_CONFIG_FILE="${MISE_CONFIG_TARGET}"
else
    export MISE_GLOBAL_CONFIG_FILE="${MISE_CONFIG_SOURCE}"
fi

log_title "Reconciling Mise-managed development tools."
case "${DANSHAN_MODE:-apply}" in
    plan)
        mise install --dry-run
        ;;
    status)
        mise ls --current
        ;;
    apply)
        mise install --yes
        if ! mise install --dry-run-code >/dev/null; then
            die "Mise-managed development tools did not converge."
        fi
        ;;
    *)
        die "Unsupported Bootstrap mode: ${DANSHAN_MODE}"
        ;;
esac

log_success "Mise development tool reconciliation complete."
