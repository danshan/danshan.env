#!/usr/bin/env bash

if [[ -n "${DANSHAN_CORE_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly DANSHAN_CORE_LOADED=1

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
readonly DOTFILES_DIR="${PROJECT_ROOT}/dotfiles"
readonly STATE_ROOT="${HOME}/Library/Application Support/danshan.env"

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
    [[ "${DANSHAN_MODE:-apply}" == check ]]
}

log_planned_action() { log_info "Would $1"; }

resolve_file_path() {
    local path="$1" link parent count=0
    while [[ -L "${path}" ]]; do
        count=$((count + 1))
        [[ "${count}" -le 40 ]] || return 1
        link="$(readlink "${path}")" || return 1
        case "${link}" in
            /*) path="${link}" ;;
            *) path="${path%/*}/${link}" ;;
        esac
    done
    [[ -f "${path}" ]] || return 1
    parent="$(cd -P "${path%/*}" && pwd)" || return 1
    printf '%s/%s\n' "${parent}" "${path##*/}"
}

validate_relative_path() {
    case "$1" in
        ''|/*|*/|.|..|./*|../*|*/../*|*/..|*/./*|*/.|*//*|*'|'*|*$'\t'*|*$'\n'*)
            die "Unsafe relative path: $1"; return 1 ;;
    esac
}

shell_matches() { [[ "$1" == all || "$1" == "${SHELL##*/}" ]]; }

array_contains() {
    local expected="$1"
    local item
    shift

    for item in "$@"; do
        if [[ "${item}" == "${expected}" ]]; then
            return 0
        fi
    done
    return 1
}

validate_table_file() {
    local path="$1" separator="$2" columns="$3"
    awk -F "${separator}" -v columns="${columns}" '
        /^#/ || /^$/ { next }
        NF != columns { print "ERROR: Wrong field count at " FILENAME ":" NR > "/dev/stderr"; failed=1; next }
        { for (i=1; i<=NF; i++) if ($i == "" || $i ~ /\r/) {
            print "ERROR: Empty field or CRLF at " FILENAME ":" NR > "/dev/stderr"; failed=1
        }}
        END { exit failed }
    ' "${path}"
}
