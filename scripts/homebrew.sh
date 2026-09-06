#!/usr/bin/env bash

run_homebrew_step() {
    local label="$1" started_at="${SECONDS}" result=0
    shift
    log_info "Starting: ${label}"
    # Inherit both output descriptors so Homebrew retains live output and TTY detection.
    "$@" || result=$?
    if [[ "${result}" -ne 0 ]]; then
        log_notice "Failed: ${label} (exit ${result}, $((SECONDS - started_at))s)" >&2
        return "${result}"
    fi
    log_success "Finished: ${label} ($((SECONDS - started_at))s)"
}

find_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
    elif [[ -x /opt/homebrew/bin/brew ]]; then
        printf '%s\n' /opt/homebrew/bin/brew
    elif [[ -x /usr/local/bin/brew ]]; then
        printf '%s\n' /usr/local/bin/brew
    else
        return 1
    fi
}

activate_homebrew() {
    local executable environment
    unset HOMEBREW_CASK_OPTS HOMEBREW_NO_REQUIRE_TAP_TRUST
    executable="$(find_homebrew)" || { die "Homebrew is unavailable."; return 1; }
    environment="$(env SHELL=/bin/bash "${executable}" shellenv)" || {
        die "Failed to read Homebrew shell environment."
        return 1
    }
    eval "${environment}" || return 1
    require_command brew
}

bundle() (
    # Inherited skip/cleanup flags must not change repository ownership.
    local setting
    for setting in ${!HOMEBREW_BUNDLE_@}; do unset "${setting}"; done
    unset HOMEBREW_CASK_OPTS HOMEBREW_NO_REQUIRE_TAP_TRUST
    export HOMEBREW_NO_AUTO_UPDATE=1
    brew bundle "$@" --file="${PROJECT_ROOT}/Brewfile"
)

apply_homebrew() {
    if ! find_homebrew >/dev/null; then
        run_homebrew_step "Install Homebrew" /bin/bash "${PROJECT_ROOT}/scripts/setup_homebrew.sh" || return 1
    fi
    activate_homebrew || return 1
    if [[ "${DANSHAN_SKIP_BREW_UPDATE:-0}" != 1 ]]; then
        run_homebrew_step "Update Homebrew metadata" brew update || return 1
    else
        log_notice "Skipping Homebrew metadata update (DANSHAN_SKIP_BREW_UPDATE=1)."
    fi
    if ! run_homebrew_step "Install or upgrade Brewfile packages" bundle install --verbose; then
        die "Homebrew reconciliation failed. For artifact conflicts, review config/migrations.txt and run migrate."
        return 1
    fi
    run_homebrew_step "Verify Brewfile packages" bundle check --verbose
}

check_homebrew() {
    if ! find_homebrew >/dev/null; then
        log_notice "UNKNOWN: Homebrew is missing; package state cannot be inspected."
        return 1
    fi
    activate_homebrew || return 1
    bundle check --verbose
}

load_homebrew_install_config() {
    local line found=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        case "${line}" in ''|'#'*) continue ;; esac
        if [[ "${found}" -ne 0 || ! "${line}" =~ ^HOMEBREW_INSTALL_REF=([0-9a-f]{40})$ ]]; then
            die "Invalid Homebrew installer config: expected one HOMEBREW_INSTALL_REF commit."; return 1
        fi
        HOMEBREW_INSTALL_REF="${BASH_REMATCH[1]}"
        found=1
    done < "${PROJECT_ROOT}/config/bootstrap.env"
    [[ "${found}" -eq 1 ]] || { die "Missing Homebrew installer revision."; return 1; }
}
