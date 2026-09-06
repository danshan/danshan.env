#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

log_title "Validating Bootstrap preconditions."

[[ "$(uname -s)" == Darwin ]] || die "This bootstrap currently supports macOS only."
validate_brew_formula_manifest "${PROJECT_ROOT}/defaults/brew_pkgs.txt"
validate_brew_cask_manifest "${PROJECT_ROOT}/defaults/brew_casks.txt"
validate_brew_trust_manifest "${PROJECT_ROOT}/defaults/brew_trust.txt"
validate_dotfile_manifest "${PROJECT_ROOT}/defaults/dotfile_pkgs.txt"
validate_login_shell
load_tool_versions
validate_tracking_git_repository_identity_if_present \
    "Zed configuration" \
    "git@github.com:danshan/zed-config.git" \
    "${HOME}/.config/zed"

[[ -f "${DOTFILES_DIR}/mise/.config/mise/config.toml" ]] ||
    die "Mise global configuration is missing from the dotfile package."

log_success "Bootstrap preflight complete."
