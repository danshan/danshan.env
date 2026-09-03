#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"
# shellcheck source=scripts/common.sh
source "${PROJECT_ROOT}/scripts/common.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-brew-trust-test.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
BREW_CALL_LOG="${TEST_TEMP_DIR}/brew-calls.log"
: > "${BREW_CALL_LOG}"

plutil() {
    case "$*" in
        '-extract formulae raw -o - '*)
            printf '%s\n' 1
            ;;
        '-extract casks raw -o - '*)
            printf '%s\n' 1
            ;;
        '-extract formulae.0 raw -o - '*)
            printf '%s\n' daipeihust/tap/im-select
            ;;
        '-extract casks.0 raw -o - '*)
            printf '%s\n' detachhead/tap/rebased
            ;;
        *)
            fail "Unexpected plutil invocation: $*"
            ;;
    esac
}

brew() {
    printf '%s\n' "$*" >> "${BREW_CALL_LOG}"
    case "$*" in
        'trust --json=v1')
            printf '%s\n' '{"formulae":[],"casks":[]}'
            ;;
        'trust --formula '*|'trust --cask '*)
            return 0
            ;;
        *)
            fail "Unexpected brew invocation: $*"
            ;;
    esac
}

load_brew_trust_state
reconcile_brew_trust formula daipeihust/tap/im-select
reconcile_brew_trust cask detachhead/tap/rebased
reconcile_brew_trust cask muxy-app/tap/muxy
reconcile_brew_trust cask localsend/localsend/localsend

assert_equals 2 "${BREW_TRUST_ADDED_COUNT}" "Trust add count"
assert_equals 2 "${BREW_TRUST_SKIPPED_COUNT}" "Trust skip count"
assert_contains 'trust --cask muxy-app/tap/muxy' "${BREW_CALL_LOG}" "Missing cask trust"
assert_contains 'trust --cask localsend/localsend/localsend' "${BREW_CALL_LOG}" "LocalSend cask trust"
assert_not_contains 'trust --formula localsend/localsend/localsend' "${BREW_CALL_LOG}" "LocalSend formula trust forbidden"
assert_not_contains 'trust --formula daipeihust/tap/im-select' "${BREW_CALL_LOG}" "Current formula trust skip"
assert_not_contains 'trust --cask detachhead/tap/rebased' "${BREW_CALL_LOG}" "Current cask trust skip"
assert_not_contains 'trust muxy-app/tap' "${BREW_CALL_LOG}" "Whole-tap trust forbidden"

brew() {
    case "$*" in
        'trust --formula failing/tap/package') return 17 ;;
        *) fail "Unexpected brew invocation during failure test: $*" ;;
    esac
}

if reconcile_brew_trust formula failing/tap/package; then
    fail "Trust command failure must propagate."
fi

if reconcile_brew_trust tap failing/tap; then
    fail "Unsupported trust type must fail."
fi
