#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"
# shellcheck source=scripts/common.sh
source "${PROJECT_ROOT}/scripts/common.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-brew-test.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
BREW_CALL_LOG="${TEST_TEMP_DIR}/brew-calls.log"
SW_VERS_OUTPUT=15.7.3
SW_VERS_SHOULD_FAIL=0
BREW_OUTDATED_CASKS_OUTPUT='outdated-app incompatible-outdated'
: > "${BREW_CALL_LOG}"

sw_vers() {
    [[ "$*" == -productVersion ]] || fail "Unexpected sw_vers invocation: $*"
    if [[ "${SW_VERS_SHOULD_FAIL}" -eq 1 ]]; then
        return 1
    fi
    printf '%s\n' "${SW_VERS_OUTPUT}"
}

brew() {
    printf '%s\n' "$*" >> "${BREW_CALL_LOG}"
    if [[ -n "${BREW_FAIL_COMMAND:-}" ]] && [[ "$*" == "${BREW_FAIL_COMMAND}" ]]; then
        return 1
    fi
    case "$*" in
        'list --formula -1')
            printf '%s\n' current-package outdated-package im-select
            ;;
        'outdated --quiet --formula')
            printf '%s\n' outdated-package
            ;;
        'list --cask -1')
            printf '%s\n' current-app outdated-app incompatible-current incompatible-outdated
            ;;
        'outdated --quiet --cask')
            if [[ -n "${BREW_OUTDATED_CASKS_OUTPUT}" ]]; then
                printf '%s\n' ${BREW_OUTDATED_CASKS_OUTPUT}
            fi
            ;;
        install*|upgrade*)
            return 0
            ;;
        *)
            fail "Unexpected brew invocation: $*"
            ;;
    esac
}

application_bundle_exists() {
    case "$1" in
        'Existing App'|'Adopted App') return 0 ;;
        *) return 1 ;;
    esac
}

load_brew_state formula
reconcile_brew_package formula current-package
reconcile_brew_package formula outdated-package
reconcile_brew_package formula missing-package
reconcile_brew_package formula daipeihust/tap/im-select

assert_equals 1 "${BREW_INSTALLED_COUNT}" "Formula install count"
assert_equals 1 "${BREW_UPGRADED_COUNT}" "Formula upgrade count"
assert_equals 2 "${BREW_SKIPPED_COUNT}" "Formula skip count"
assert_contains 'upgrade --quiet outdated-package' "${BREW_CALL_LOG}" "Outdated formula upgrade"
assert_contains 'install --quiet missing-package' "${BREW_CALL_LOG}" "Missing formula install"
assert_not_contains 'install --quiet current-package' "${BREW_CALL_LOG}" "Current formula skip"
assert_not_contains 'install --quiet daipeihust/tap/im-select' "${BREW_CALL_LOG}" "Qualified formula normalization"

load_macos_state
assert_equals 15 "${MACOS_MAJOR_VERSION}" "Current macOS major"
SW_VERS_OUTPUT=invalid
if load_macos_state; then
    fail "Invalid current macOS version must fail."
fi
SW_VERS_SHOULD_FAIL=1
if load_macos_state; then
    fail "macOS version command failure must propagate."
fi
SW_VERS_OUTPUT=15.7.3
SW_VERS_SHOULD_FAIL=0
load_macos_state

BREW_INSTALLED_COUNT=0
BREW_UPGRADED_COUNT=0
BREW_SKIPPED_COUNT=0
load_brew_state cask
reconcile_brew_package cask current-app
reconcile_brew_package cask outdated-app
reconcile_brew_package cask missing-app 'Missing App'
reconcile_brew_package cask external-app 'Existing App'
reconcile_brew_package cask adopted-app 'Adopted App' adopt
reconcile_brew_package cask adoptable-font '' adopt
reconcile_brew_package cask thaw 'Thaw' preserve 26
reconcile_brew_package cask supported-cask '' preserve 15
reconcile_brew_package cask incompatible-current '' preserve 26
reconcile_brew_package cask incompatible-outdated '' preserve 26

assert_equals 4 "${BREW_INSTALLED_COUNT}" "Cask install count"
assert_equals 1 "${BREW_UPGRADED_COUNT}" "Cask upgrade count"
assert_equals 5 "${BREW_SKIPPED_COUNT}" "Cask skip count"
assert_contains 'upgrade --quiet --cask outdated-app' "${BREW_CALL_LOG}" "Outdated cask upgrade"
assert_contains 'install --quiet --cask missing-app' "${BREW_CALL_LOG}" "Missing app cask install"
assert_not_contains 'install --quiet --cask external-app' "${BREW_CALL_LOG}" "Existing external app preserve"
assert_contains 'install --quiet --cask --adopt adopted-app' "${BREW_CALL_LOG}" "Explicit app cask adopt"
assert_contains 'install --quiet --cask --adopt adoptable-font' "${BREW_CALL_LOG}" "Explicit non-app cask adopt"
assert_contains 'install --quiet --cask supported-cask' "${BREW_CALL_LOG}" "Supported cask install"
assert_not_contains 'install --quiet --cask --adopt missing-app' "${BREW_CALL_LOG}" "Absent app adopt forbidden"
assert_not_contains 'install --quiet --cask thaw' "${BREW_CALL_LOG}" "Incompatible cask skip"
assert_not_contains 'upgrade --quiet --cask incompatible-outdated' "${BREW_CALL_LOG}" \
    "Incompatible outdated cask skip"
assert_not_contains 'install --quiet --cask current-app' "${BREW_CALL_LOG}" "Current cask skip"

if reconcile_brew_package cask invalid-policy 'Invalid App' overwrite; then
    fail "Unsupported existing App policy must fail."
fi
if reconcile_brew_package cask invalid-platform '' preserve Tahoe; then
    fail "Invalid minimum macOS major must fail."
fi

formula_list_calls="$(grep -Fc 'list --formula -1' "${BREW_CALL_LOG}")"
formula_outdated_calls="$(grep -Fc 'outdated --quiet --formula' "${BREW_CALL_LOG}")"
cask_list_calls="$(grep -Fc 'list --cask -1' "${BREW_CALL_LOG}")"
cask_outdated_calls="$(grep -Fc 'outdated --quiet --cask' "${BREW_CALL_LOG}")"
assert_equals 1 "${formula_list_calls}" "Formula installed inventory call count"
assert_equals 1 "${formula_outdated_calls}" "Formula outdated inventory call count"
assert_equals 1 "${cask_list_calls}" "Cask installed inventory call count"
assert_equals 1 "${cask_outdated_calls}" "Cask outdated inventory call count"

BREW_OUTDATED_CASKS_OUTPUT=""
if ! load_brew_state cask; then
    fail "Empty outdated cask inventory must load successfully."
fi
assert_equals 0 "${#BREW_OUTDATED_ITEMS[@]}" "Empty outdated cask inventory"

BREW_INSTALLED_ITEMS=()
BREW_OUTDATED_ITEMS=()
reconcile_brew_package cask empty-inventory-app 'Absent App'
assert_contains 'install --quiet --cask empty-inventory-app' "${BREW_CALL_LOG}" "Empty inventory install"

installed_count_before_failure="${BREW_INSTALLED_COUNT}"
BREW_FAIL_COMMAND='install --quiet --cask --adopt failing-font'
if reconcile_brew_package cask failing-font '' adopt; then
    fail "Failed cask adoption must propagate a non-zero status."
fi
assert_equals "${installed_count_before_failure}" "${BREW_INSTALLED_COUNT}" "Failed cask adoption install count"
