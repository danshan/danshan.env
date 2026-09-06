#!/usr/bin/env bash

set -Eeuo pipefail

for argument in "$@"; do
    if [[ "${argument}" == --no-color ]]; then
        export DANSHAN_NO_COLOR=1
    fi
done

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${INSTALL_DIR}/scripts/common.sh"

BOOTSTRAP_STAGES=(base homebrew trust formulae casks shell dotfiles devenv)
DANSHAN_MODE=apply
SELECTED_STAGE=""
START_STAGE=""
CURRENT_STAGE=preflight

usage() {
    printf '%s\n' \
        "Usage: bash install.sh [apply|plan|status] [--stage NAME|--from NAME] [--no-color]" \
        "Stages: ${BOOTSTRAP_STAGES[*]}"
}

stage_index() {
    local expected="$1"
    local index=0
    local stage_name
    for stage_name in "${BOOTSTRAP_STAGES[@]}"; do
        if [[ "${stage_name}" == "${expected}" ]]; then
            printf '%s\n' "${index}"
            return
        fi
        index=$((index + 1))
    done
    return 1
}

if [[ "${1:-}" == apply || "${1:-}" == plan || "${1:-}" == status ]]; then
    DANSHAN_MODE="$1"
    shift
fi
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --stage)
            [[ "$#" -ge 2 ]] || { usage >&2; exit 2; }
            SELECTED_STAGE="$2"
            shift 2
            ;;
        --stage=*) SELECTED_STAGE="${1#*=}"; shift ;;
        --from)
            [[ "$#" -ge 2 ]] || { usage >&2; exit 2; }
            START_STAGE="$2"
            shift 2
            ;;
        --from=*) START_STAGE="${1#*=}"; shift ;;
        --no-color) shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1"; exit 2 ;;
    esac
done

[[ -z "${SELECTED_STAGE}" || -z "${START_STAGE}" ]] ||
    die "Use either --stage or --from, not both."
if [[ -n "${SELECTED_STAGE}" ]] && ! stage_index "${SELECTED_STAGE}" >/dev/null; then
    die "Unknown Bootstrap stage: ${SELECTED_STAGE}"
fi
if [[ -n "${START_STAGE}" ]] && ! stage_index "${START_STAGE}" >/dev/null; then
    die "Unknown Bootstrap stage: ${START_STAGE}"
fi
readonly DANSHAN_MODE SELECTED_STAGE START_STAGE
export DANSHAN_MODE

should_run_stage() {
    local stage_name="$1"
    local current_index start_index
    if [[ -n "${SELECTED_STAGE}" ]]; then
        [[ "${stage_name}" == "${SELECTED_STAGE}" ]]
        return
    fi
    if [[ -n "${START_STAGE}" ]]; then
        current_index="$(stage_index "${stage_name}")"
        start_index="$(stage_index "${START_STAGE}")"
        [[ "${current_index}" -ge "${start_index}" ]]
        return
    fi
    return 0
}

run_stage() {
    local stage_name="$1"
    local script_path="$2"
    local started_at elapsed
    should_run_stage "${stage_name}" || return 0
    CURRENT_STAGE="${stage_name}"
    started_at="$(date +%s)"
    log_title "Running Bootstrap Stage: ${stage_name}"
    bash "${script_path}"
    elapsed=$(( $(date +%s) - started_at ))
    log_success "Bootstrap Stage complete: ${stage_name} (${elapsed}s)"
}

run_base_stage() {
    should_run_stage base || return 0
    CURRENT_STAGE=base
    log_title "Running Bootstrap Stage: base"
    if [[ -d "${HOME}/.bin" ]]; then
        log_success "Skipping existing directory: ${HOME}/.bin"
    elif is_read_only_mode; then
        log_planned_action "create ${HOME}/.bin directory."
    else
        log_notice "Creating ${HOME}/.bin directory."
        mkdir -p "${HOME}/.bin"
    fi
    log_success "Bootstrap Stage complete: base"
}

on_error() {
    local exit_code=$?
    printf '%bInstallation failed in stage %s with exit code %s.%b\n' \
        "${COLOR_ERROR}" "${CURRENT_STAGE}" "${exit_code}" "${COLOR_RESET}" >&2
    exit "${exit_code}"
}
trap on_error ERR

log_title "Running danshan.env Bootstrap in ${DANSHAN_MODE} mode."
bash "${PROJECT_ROOT}/scripts/preflight.sh"
run_base_stage
run_stage homebrew "${PROJECT_ROOT}/scripts/setup_homebrew.sh"
run_stage trust "${PROJECT_ROOT}/scripts/setup_brew_trust.sh"
run_stage formulae "${PROJECT_ROOT}/scripts/install_brew_pkgs.sh"
run_stage casks "${PROJECT_ROOT}/scripts/install_brew_casks.sh"
run_stage shell "${PROJECT_ROOT}/scripts/setup_shell.sh"
run_stage dotfiles "${PROJECT_ROOT}/scripts/setup_dotfiles.sh"
run_stage devenv "${PROJECT_ROOT}/scripts/setup_devenv.sh"

if is_read_only_mode; then
    log_title "danshan.env ${DANSHAN_MODE} complete; no managed state was changed."
else
    log_title "danshan.env installation complete."
    printf '%s\n' "Restart the terminal to load the updated environment."
fi
