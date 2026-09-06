#!/usr/bin/env bash

if [[ -n "${DANSHAN_CORE_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly DANSHAN_CORE_LOADED=1

if [[ -t 1 && -z "${NO_COLOR:-}" && "${DANSHAN_NO_COLOR:-0}" != 1 ]]; then
    readonly COLOR_TITLE=$'\033[1;36m'
    readonly COLOR_SUBTITLE=$'\033[1;33m'
    readonly COLOR_SUCCESS=$'\033[0;32m'
    readonly COLOR_INFO=$'\033[0;34m'
    readonly COLOR_ERROR=$'\033[0;31m'
    readonly COLOR_RESET=$'\033[0m'
else
    readonly COLOR_TITLE=""
    readonly COLOR_SUBTITLE=""
    readonly COLOR_SUCCESS=""
    readonly COLOR_INFO=""
    readonly COLOR_ERROR=""
    readonly COLOR_RESET=""
fi

log_title() { printf '%b%s%b\n' "${COLOR_TITLE}" "$1" "${COLOR_RESET}"; }
log_notice() { printf '%b%s%b\n' "${COLOR_SUBTITLE}" "$1" "${COLOR_RESET}"; }
log_info() { printf '%b%s%b\n' "${COLOR_INFO}" "$1" "${COLOR_RESET}"; }
log_success() { printf '%b%s%b\n' "${COLOR_SUCCESS}" "$1" "${COLOR_RESET}"; }

die() {
    printf '%bERROR: %s%b\n' "${COLOR_ERROR}" "$1" "${COLOR_RESET}" >&2
    return 1
}

require_command() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

is_read_only_mode() {
    [[ "${DANSHAN_MODE:-apply}" == plan || "${DANSHAN_MODE:-apply}" == status ]]
}

log_planned_action() { log_info "Would $1"; }
