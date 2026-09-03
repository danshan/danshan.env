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
: > "${BREW_CALL_LOG}"

brew() {
    printf '%s\n' "$*" >> "${BREW_CALL_LOG}"
    case "$*" in
        'list --formula -1')
            printf '%s\n' current-package outdated-package im-select
            ;;
        'outdated --quiet --formula')
            printf '%s\n' outdated-package
            ;;
        'list --cask -1')
            printf '%s\n' current-app outdated-app thaw
            ;;
        'outdated --quiet --cask')
            printf '%s\n' outdated-app
            ;;
        install*|upgrade*)
            return 0
            ;;
        *)
            fail "Unexpected brew invocation: $*"
            ;;
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

BREW_INSTALLED_COUNT=0
BREW_UPGRADED_COUNT=0
BREW_SKIPPED_COUNT=0
load_brew_state cask
reconcile_brew_package cask current-app
reconcile_brew_package cask outdated-app
reconcile_brew_package cask missing-app 'Missing App'
reconcile_brew_package cask thaw

assert_equals 1 "${BREW_INSTALLED_COUNT}" "Cask install count"
assert_equals 1 "${BREW_UPGRADED_COUNT}" "Cask upgrade count"
assert_equals 2 "${BREW_SKIPPED_COUNT}" "Cask skip count"
assert_contains 'upgrade --quiet --cask outdated-app' "${BREW_CALL_LOG}" "Outdated cask upgrade"
assert_contains 'install --quiet --cask --adopt missing-app' "${BREW_CALL_LOG}" "Missing app cask adopt"
assert_not_contains 'install --quiet --cask --adopt thaw' "${BREW_CALL_LOG}" "Non-app cask install"
assert_not_contains 'install --quiet --cask current-app' "${BREW_CALL_LOG}" "Current cask skip"

formula_list_calls="$(grep -Fc 'list --formula -1' "${BREW_CALL_LOG}")"
formula_outdated_calls="$(grep -Fc 'outdated --quiet --formula' "${BREW_CALL_LOG}")"
cask_list_calls="$(grep -Fc 'list --cask -1' "${BREW_CALL_LOG}")"
cask_outdated_calls="$(grep -Fc 'outdated --quiet --cask' "${BREW_CALL_LOG}")"
assert_equals 1 "${formula_list_calls}" "Formula installed inventory call count"
assert_equals 1 "${formula_outdated_calls}" "Formula outdated inventory call count"
assert_equals 1 "${cask_list_calls}" "Cask installed inventory call count"
assert_equals 1 "${cask_outdated_calls}" "Cask outdated inventory call count"
