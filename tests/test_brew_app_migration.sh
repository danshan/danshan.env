#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"
# shellcheck source=scripts/common.sh
source "${PROJECT_ROOT}/scripts/common.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-app-migration-test.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
APPLICATIONS_DIR="${TEST_TEMP_DIR}/Applications"
BACKUP_ROOT="${TEST_TEMP_DIR}/backups"
STATE_DIR="${TEST_TEMP_DIR}/brew-state"
BREW_CALL_LOG="${TEST_TEMP_DIR}/brew-calls.log"
mkdir -p -- "${APPLICATIONS_DIR}" "${STATE_DIR}"
: > "${BREW_CALL_LOG}"

application_bundle_path() {
    printf '%s/%s.app\n' "${APPLICATIONS_DIR}" "$1"
}

write_application_version() {
    local application_name="$1"
    local version="$2"
    local application_path
    application_path="$(application_bundle_path "${application_name}")"
    mkdir -p -- "${application_path}/Contents"
    printf '%s\n' "${version}" > "${application_path}/Contents/version.txt"
}

read_application_version() {
    local application_name="$1"
    sed -n '1p' "$(application_bundle_path "${application_name}")/Contents/version.txt"
}

brew() {
    printf '%s\n' "$*" >> "${BREW_CALL_LOG}"
    case "$*" in
        'install --quiet --cask app-success')
            write_application_version 'Success App' new
            : > "${STATE_DIR}/app-success"
            ;;
        'install --quiet --cask absent-app')
            write_application_version 'Absent App' new
            : > "${STATE_DIR}/absent-app"
            ;;
        'install --quiet --cask app-fail')
            write_application_version 'Fail App' failed-new
            return 1
            ;;
        'install --quiet --cask app-verify')
            : > "${STATE_DIR}/app-verify"
            ;;
        'install --quiet --cask app-rollback')
            write_application_version 'Rollback App' failed-new
            : > "${STATE_DIR}/app-rollback"
            return 1
            ;;
        'upgrade --quiet --cask app-outdated')
            return 0
            ;;
        'list --cask app-success'|'list --cask absent-app'|'list --cask app-fail'|'list --cask app-verify'|'list --cask app-rollback')
            [[ -f "${STATE_DIR}/${3}" ]]
            ;;
        'uninstall --cask app-rollback')
            return 1
            ;;
        'uninstall --cask app-success'|'uninstall --cask absent-app'|'uninstall --cask app-fail'|'uninstall --cask app-verify')
            rm -f -- "${STATE_DIR}/${3}"
            ;;
        *)
            fail "Unexpected brew invocation: $*"
            ;;
    esac
}

BREW_INSTALLED_ITEMS=()
BREW_OUTDATED_ITEMS=()
BREW_INSTALLED_COUNT=0
BREW_UPGRADED_COUNT=0
BREW_SKIPPED_COUNT=0

write_application_version 'Success App' old
reconcile_brew_package cask app-success 'Success App' migrate '' "${BACKUP_ROOT}"
SUCCESS_BACKUP_DIR="${BREW_APP_MIGRATION_BACKUP_DIR}"
assert_equals new "$(read_application_version 'Success App')" "Migrated application content"
assert_equals old \
    "$(sed -n '1p' "${SUCCESS_BACKUP_DIR}/originals/Success App.app/Contents/version.txt")" \
    "Original application snapshot"
assert_equals completed "$(sed -n '1p' "${SUCCESS_BACKUP_DIR}/state")" \
    "Successful application migration state"
assert_equals 1 "${BREW_INSTALLED_COUNT}" "Migrated application install count"
assert_not_contains 'install --quiet --cask --adopt app-success' "${BREW_CALL_LOG}" \
    "Application migration must not use adopt"

BREW_INSTALLED_ITEMS=(app-success)
BREW_OUTDATED_ITEMS=()
calls_before_rerun="$(wc -l < "${BREW_CALL_LOG}" | tr -d ' ')"
reconcile_brew_package cask app-success 'Success App' migrate '' "${BACKUP_ROOT}"
calls_after_rerun="$(wc -l < "${BREW_CALL_LOG}" | tr -d ' ')"
assert_equals "${calls_before_rerun}" "${calls_after_rerun}" "Current application migration rerun"
assert_equals 1 "${BREW_SKIPPED_COUNT}" "Current migrated application skip count"

BREW_INSTALLED_ITEMS=(app-outdated)
BREW_OUTDATED_ITEMS=(app-outdated)
reconcile_brew_package cask app-outdated 'Outdated App' migrate '' "${BACKUP_ROOT}"
assert_contains 'upgrade --quiet --cask app-outdated' "${BREW_CALL_LOG}" \
    "Outdated migrated application upgrade"

BREW_INSTALLED_ITEMS=()
BREW_OUTDATED_ITEMS=()
reconcile_brew_package cask absent-app 'Absent App' migrate '' "${BACKUP_ROOT}"
assert_equals new "$(read_application_version 'Absent App')" "Absent application ordinary install"
assert_contains 'install --quiet --cask absent-app' "${BREW_CALL_LOG}" \
    "Absent migration target ordinary install"

write_application_version 'Fail App' old
installed_count_before_failure="${BREW_INSTALLED_COUNT}"
if reconcile_brew_package cask app-fail 'Fail App' migrate '' "${BACKUP_ROOT}"; then
    fail "Application install failure must propagate a non-zero status."
fi
FAILURE_BACKUP_DIR="${BREW_APP_MIGRATION_BACKUP_DIR}"
assert_equals old "$(read_application_version 'Fail App')" "Rolled back application content"
assert_equals failed-new \
    "$(sed -n '1p' "${FAILURE_BACKUP_DIR}/failed-install-artifact/Fail App.app/Contents/version.txt")" \
    "Failed application artifact preservation"
assert_equals rolled-back "$(sed -n '1p' "${FAILURE_BACKUP_DIR}/state")" \
    "Failed application migration state"
assert_equals "${installed_count_before_failure}" "${BREW_INSTALLED_COUNT}" \
    "Failed application migration install count"

write_application_version 'Verify App' old
if reconcile_brew_package cask app-verify 'Verify App' migrate '' "${BACKUP_ROOT}"; then
    fail "Missing installed application target must fail verification."
fi
VERIFY_BACKUP_DIR="${BREW_APP_MIGRATION_BACKUP_DIR}"
assert_equals old "$(read_application_version 'Verify App')" "Verification failure rollback"
assert_equals rolled-back "$(sed -n '1p' "${VERIFY_BACKUP_DIR}/state")" \
    "Verification failure migration state"
assert_contains 'uninstall --cask app-verify' "${BREW_CALL_LOG}" \
    "Registered application rollback"

write_application_version 'Rollback App' old
if reconcile_brew_package cask app-rollback 'Rollback App' migrate '' "${BACKUP_ROOT}"; then
    fail "Incomplete application rollback must propagate a non-zero status."
fi
ROLLBACK_BACKUP_DIR="${BREW_APP_MIGRATION_BACKUP_DIR}"
assert_equals old "$(read_application_version 'Rollback App')" \
    "Incomplete rollback restores original application when possible"
assert_equals failed-new \
    "$(sed -n '1p' "${ROLLBACK_BACKUP_DIR}/failed-install-artifact/Rollback App.app/Contents/version.txt")" \
    "Incomplete rollback preserves failed artifact"
assert_equals rollback-incomplete "$(sed -n '1p' "${ROLLBACK_BACKUP_DIR}/state")" \
    "Incomplete application rollback state"
assert_contains 'uninstall --cask app-rollback' "${BREW_CALL_LOG}" \
    "Incomplete application rollback uninstall"

INVALID_MANIFEST="${TEST_TEMP_DIR}/invalid-casks.txt"
printf '%s\n' 'unsafe-app|../Unsafe|migrate' > "${INVALID_MANIFEST}"
if validate_brew_cask_manifest "${INVALID_MANIFEST}"; then
    fail "Unsafe application migration target must be rejected."
fi
