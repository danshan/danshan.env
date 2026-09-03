#!/usr/bin/env bash

set -Eeuo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${INSTALL_DIR}/scripts/common.sh"

run_stage() {
    local stage_name="$1"
    local script_path="$2"

    log_title "Running Bootstrap Stage: ${stage_name}"
    bash "${script_path}"
}

on_error() {
    local exit_code=$?
    printf '%bInstallation failed with exit code %s.%b\n' "${COLOR_ERROR}" "${exit_code}" "${COLOR_RESET}" >&2
    exit "${exit_code}"
}
trap on_error ERR

log_title "Installing danshan.env"

if [[ ! -d "${HOME}/.bin" ]]; then
    log_notice "Creating ${HOME}/.bin directory."
    mkdir -p "${HOME}/.bin"
else
    log_success "Skipping existing directory: ${HOME}/.bin"
fi

run_stage "Homebrew" "${PROJECT_ROOT}/scripts/setup_homebrew.sh"
run_stage "Homebrew package trust" "${PROJECT_ROOT}/scripts/setup_brew_trust.sh"
run_stage "Homebrew formulae" "${PROJECT_ROOT}/scripts/install_brew_pkgs.sh"
run_stage "Homebrew casks" "${PROJECT_ROOT}/scripts/install_brew_casks.sh"
run_stage "Shell framework" "${PROJECT_ROOT}/scripts/setup_shell.sh"
run_stage "Dotfiles" "${PROJECT_ROOT}/scripts/setup_dotfiles.sh"
run_stage "Development environment" "${PROJECT_ROOT}/scripts/setup_devenv.sh"

log_title "danshan.env installation complete."
printf '%s\n' "Restart the terminal to load the updated environment."
