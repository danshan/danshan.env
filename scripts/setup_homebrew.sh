#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_tool_versions

HOMEBREW_INSTALL_DIRECTORY=""

cleanup_homebrew_installer() {
    if [[ -n "${HOMEBREW_INSTALL_DIRECTORY}" && -d "${HOMEBREW_INSTALL_DIRECTORY}" ]]; then
        rm -rf -- "${HOMEBREW_INSTALL_DIRECTORY}"
    fi
}

install_homebrew() {
    local install_directory
    local install_repository
    local install_script
    local install_url

    install_directory="$(mktemp -d "${TMPDIR:-/tmp}/danshan-homebrew.XXXXXX")"
    HOMEBREW_INSTALL_DIRECTORY="${install_directory}"
    trap cleanup_homebrew_installer EXIT

    if [[ -n "${BREW_CN:-}" ]]; then
        require_command git
        install_repository="${install_directory}/repository"
        log_info "Cloning the Homebrew installer mirror at pinned revision ${HOMEBREW_INSTALL_REF}."
        git clone --filter=blob:none --no-checkout \
            "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/install.git" \
            "${install_repository}"
        git -C "${install_repository}" fetch --depth=1 origin "${HOMEBREW_INSTALL_REF}"
        git -C "${install_repository}" checkout --detach "${HOMEBREW_INSTALL_REF}"
        install_script="${install_repository}/install.sh"
    else
        require_command curl
        install_script="${install_directory}/install.sh"
        install_url="https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_REF}/install.sh"
        log_info "Downloading pinned Homebrew installer revision ${HOMEBREW_INSTALL_REF}."
        curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
            --output "${install_script}" "${install_url}"
    fi

    /bin/bash "${install_script}"
    cleanup_homebrew_installer
    trap - EXIT
}

log_title "Configuring Homebrew."

if [[ "$(uname -s)" != Darwin ]]; then
    die "This bootstrap currently supports macOS only."
fi

if command -v brew >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/brew ]] || [[ -x /usr/local/bin/brew ]]; then
    log_success "Skipping Homebrew installation: Homebrew is already available."
else
    if is_read_only_mode; then
        log_planned_action "install Homebrew."
        log_notice "Remaining Homebrew state is unavailable until Homebrew is installed."
        exit 0
    fi
    install_homebrew
fi

activate_homebrew

if is_read_only_mode; then
    log_notice "Skipping Homebrew metadata update in ${DANSHAN_MODE} mode."
elif [[ "${DANSHAN_SKIP_BREW_UPDATE:-0}" == 1 ]]; then
    log_notice "Skipping Homebrew metadata update by request."
else
    log_info "Refreshing Homebrew metadata once."
    brew update --quiet
fi

log_success "Homebrew setup complete."
