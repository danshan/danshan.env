#!/usr/bin/env bash

repository_mise() (
    local setting
    # Keep registry credentials/proxies, but exclude caller-controlled Mise settings.
    for setting in ${!MISE_@} ${!__MISE_@}; do unset "${setting}"; done
    export MISE_GLOBAL_CONFIG_FILE="${DOTFILES_DIR}/mise/.config/mise/config.toml"
    export MISE_SYSTEM_CONFIG_FILE="${PROJECT_ROOT}/config/mise-system.toml"
    export MISE_CEILING_PATHS="${PROJECT_ROOT}"
    export MISE_AUTO_ENV=false
    export MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=""
    export MISE_AUTO_INSTALL=false
    export MISE_AUTO_UPDATE=false
    if is_read_only_mode; then export MISE_OFFLINE=true; fi
    mise --cd "${PROJECT_ROOT}" "$@"
)

verify_mise_deployment() {
    local name target
    for name in config.toml mise.lock; do
        target="${HOME}/.config/mise/${name}"
        [[ "$(resolve_file_path "${target}")" == "${DOTFILES_DIR}/mise/.config/mise/${name}" ]] || {
            die "Mise deployment differs from repository state: ${target}; run the dotfiles stage."
            return 1
        }
    done
}

apply_mise() {
    activate_homebrew || return 1
    require_command mise || return 1
    verify_mise_deployment || return 1
    repository_mise install --yes || return 1
    repository_mise install --dry-run-code
}

check_mise() {
    if ! command -v mise >/dev/null 2>&1; then
        log_notice "UNKNOWN: Mise is missing; development tool state cannot be inspected."
        return 1
    fi
    local failed=0
    verify_mise_deployment || failed=1
    repository_mise ls --current || failed=1
    repository_mise install --dry-run-code || failed=1
    return "${failed}"
}
