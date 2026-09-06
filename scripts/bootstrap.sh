#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for argument in "$@"; do
    [[ "${argument}" != --no-color ]] || export DANSHAN_NO_COLOR=1
done
source "${SCRIPT_DIR}/lib/core.sh"
source "${SCRIPT_DIR}/homebrew.sh"
source "${SCRIPT_DIR}/mise.sh"
source "${SCRIPT_DIR}/dotfiles.sh"
source "${SCRIPT_DIR}/repositories.sh"
source "${SCRIPT_DIR}/migrations/transaction.sh"
source "${SCRIPT_DIR}/migrations/casks.sh"
source "${SCRIPT_DIR}/migrations/legacy-mise.sh"
source "${SCRIPT_DIR}/migrations/runner.sh"
source "${SCRIPT_DIR}/preflight.sh"
DANSHAN_MODE=apply
SELECTED_STAGE=""
START_STAGE=""
CURRENT_STAGE=preflight
STAGES=(homebrew repositories dotfiles mise)
usage() {
    printf '%s\n' 'Usage: bash install.sh [apply|check|migrate|recover] [--stage NAME|--from NAME] [--no-color]' \
        'Stages for apply/check: homebrew repositories dotfiles mise'
}
case "${1:-}" in apply|check|migrate|recover) DANSHAN_MODE="$1"; shift ;; esac
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --stage|--from)
            [[ "$#" -ge 2 ]] || { usage >&2; exit 2; }
            if [[ "$1" == --stage ]]; then SELECTED_STAGE="$2"; else START_STAGE="$2"; fi
            shift 2 ;;
        --no-color) shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1"; exit 2 ;;
    esac
done
[[ -z "${SELECTED_STAGE}" || -z "${START_STAGE}" ]] || { die "Use either --stage or --from."; exit 2; }
for stage in "${SELECTED_STAGE}" "${START_STAGE}"; do
    [[ -z "${stage}" ]] || array_contains "${stage}" "${STAGES[@]}" || { die "Unknown stage: ${stage}"; exit 2; }
done
if [[ "${DANSHAN_MODE}" == migrate || "${DANSHAN_MODE}" == recover ]]; then
    [[ -z "${SELECTED_STAGE}${START_STAGE}" ]] || { die "Migration commands do not accept stage selection."; exit 2; }
fi
export DANSHAN_MODE
on_error() {
    local code=$?
    printf 'Bootstrap failed in %s with exit code %s.\n' "${CURRENT_STAGE}" "${code}" >&2
    exit "${code}"
}
trap on_error ERR
trap 'exit 130' INT
trap 'exit 143' TERM HUP
bootstrap_preflight
lock_bootstrap
if [[ "${DANSHAN_MODE}" == migrate || "${DANSHAN_MODE}" == recover ]]; then
    CURRENT_STAGE="${DANSHAN_MODE}"
    if [[ "${DANSHAN_MODE}" == recover ]]; then
        recover_migrations
    else
        activate_homebrew
        assert_no_pending_migrations
        run_migrations
    fi
else
    failed=0
    if [[ "${DANSHAN_MODE}" == check ]]; then
        assert_no_pending_migrations || failed=1
    else
        assert_no_pending_migrations
    fi
    started=0
    [[ -n "${START_STAGE}" ]] || started=1
    for stage in "${STAGES[@]}"; do
        [[ "${stage}" != "${START_STAGE}" ]] || started=1
        [[ "${started}" -eq 1 ]] || continue
        [[ -z "${SELECTED_STAGE}" || "${stage}" == "${SELECTED_STAGE}" ]] || continue
        CURRENT_STAGE="${stage}"
        log_title "${DANSHAN_MODE}: ${stage}"
        if [[ "${DANSHAN_MODE}" == check ]]; then
            "check_${stage}" || failed=1
        else
            "apply_${stage}"
        fi
    done
    if [[ "${failed}" -ne 0 ]]; then
        log_notice "Check found unmet, conflicting or unavailable state."
        exit 1
    fi
fi
log_success "Bootstrap ${DANSHAN_MODE} complete."
