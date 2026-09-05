#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"
# shellcheck source=scripts/common.sh
source "${PROJECT_ROOT}/scripts/common.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-font-migration-test.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
BREW_CALL_LOG="${TEST_TEMP_DIR}/brew-calls.log"
TEST_HOME_ROOT="${TEST_TEMP_DIR}/home"
FONT_DIR="${TEST_HOME_ROOT}/Library/Fonts"
STATE_DIR="${TEST_TEMP_DIR}/brew-state"
SUCCESS_BACKUP_ROOT="${TEST_HOME_ROOT}/Library/Application Support/danshan.env/success-backups"
FAILURE_BACKUP_ROOT="${TEST_HOME_ROOT}/Library/Application Support/danshan.env/failure-backups"
SUCCESS_MANIFEST="${TEST_TEMP_DIR}/success-casks.txt"
FAILURE_MANIFEST="${TEST_TEMP_DIR}/failure-casks.txt"
mkdir -p -- "${FONT_DIR}" "${STATE_DIR}"
: > "${BREW_CALL_LOG}"

emit_cask_info() {
    local font_name="$1"
    local target_path="$2"
    printf '{"casks":[{"artifacts":[{"font":["%s"],"target":"%s"}]}]}\n' \
        "${font_name}" "${target_path}"
}

brew() {
    printf '%s\n' "$*" >> "${BREW_CALL_LOG}"
    case "$*" in
        'info --cask --json=v2 font-current')
            emit_cask_info Current.ttf "${FONT_DIR}/Current.ttf"
            ;;
        'info --cask --json=v2 font-alpha')
            emit_cask_info Alpha.ttf "${FONT_DIR}/Alpha.ttf"
            ;;
        'info --cask --json=v2 font-beta')
            emit_cask_info Beta.ttf "${FONT_DIR}/Beta.ttf"
            ;;
        'info --cask --json=v2 font-gamma')
            emit_cask_info Gamma.ttf "${FONT_DIR}/Gamma.ttf"
            ;;
        'info --cask --json=v2 font-unsafe')
            emit_cask_info Unsafe.ttf "${TEST_TEMP_DIR}/Unsafe.ttf"
            ;;
        'install --quiet --cask font-alpha')
            printf '%s\n' new-alpha > "${FONT_DIR}/Alpha.ttf"
            : > "${STATE_DIR}/font-alpha"
            ;;
        'install --quiet --cask font-beta')
            printf '%s\n' new-beta > "${FONT_DIR}/Beta.ttf"
            : > "${STATE_DIR}/font-beta"
            ;;
        'install --quiet --cask font-gamma')
            printf '%s\n' new-gamma > "${FONT_DIR}/Gamma.ttf"
            return 1
            ;;
        'upgrade --quiet --cask font-current')
            return 0
            ;;
        'list --cask font-current')
            return 0
            ;;
        'list --cask font-alpha'|'list --cask font-beta'|'list --cask font-gamma')
            [[ -f "${STATE_DIR}/${3}" ]]
            ;;
        'uninstall --cask font-alpha'|'uninstall --cask font-beta'|'uninstall --cask font-gamma')
            # Keep the target to verify that rollback preserves uninstall residue.
            rm -f -- "${STATE_DIR}/${3}"
            ;;
        *)
            fail "Unexpected brew invocation: $*"
            ;;
    esac
}

printf '%s\n' \
    'font-current||migrate' \
    'font-alpha||migrate' \
    'font-future||migrate|26' > "${SUCCESS_MANIFEST}"
printf '%s\n' old-alpha > "${FONT_DIR}/Alpha.ttf"
BREW_INSTALLED_ITEMS=(font-current)
BREW_OUTDATED_ITEMS=(font-current)
BREW_INSTALLED_COUNT=0
BREW_UPGRADED_COUNT=0
BREW_SKIPPED_COUNT=0
BREW_RECONCILED_ITEMS=()
MACOS_MAJOR_VERSION=15

validate_brew_cask_manifest "${SUCCESS_MANIFEST}"
migrate_missing_brew_font_casks \
    "${SUCCESS_MANIFEST}" "${FONT_DIR}" "${SUCCESS_BACKUP_ROOT}"

assert_equals new-alpha "$(sed -n '1p' "${FONT_DIR}/Alpha.ttf")" "Migrated font content"
assert_equals old-alpha \
    "$(sed -n '1p' "${BREW_FONT_MIGRATION_BACKUP_DIR}/originals/font-alpha/Alpha.ttf")" \
    "Original font backup"
assert_equals completed "$(sed -n '1p' "${BREW_FONT_MIGRATION_BACKUP_DIR}/state")" \
    "Successful migration state"
assert_equals 1 "${BREW_INSTALLED_COUNT}" "Migrated cask install count"
assert_equals font-alpha "${BREW_RECONCILED_ITEMS[0]}" "Migrated cask reconciliation marker"
assert_not_contains 'info --cask --json=v2 font-current' "${BREW_CALL_LOG}" \
    "Installed font migration inspection"
assert_not_contains 'info --cask --json=v2 font-future' "${BREW_CALL_LOG}" \
    "Incompatible font migration inspection"

reconcile_brew_package cask font-current '' preserve
assert_equals 1 "${BREW_UPGRADED_COUNT}" "Installed outdated font upgrade count"
calls_before_rerun="$(wc -l < "${BREW_CALL_LOG}" | tr -d ' ')"
migrate_missing_brew_font_casks \
    "${SUCCESS_MANIFEST}" "${FONT_DIR}" "${SUCCESS_BACKUP_ROOT}"
calls_after_rerun="$(wc -l < "${BREW_CALL_LOG}" | tr -d ' ')"
assert_equals "${calls_before_rerun}" "${calls_after_rerun}" "Current font migration rerun"

printf '%s\n' \
    'font-beta||migrate' \
    'font-gamma||migrate' > "${FAILURE_MANIFEST}"
printf '%s\n' old-beta > "${FONT_DIR}/Beta.ttf"
rm -f -- "${FONT_DIR}/Gamma.ttf" "${STATE_DIR}/font-beta" "${STATE_DIR}/font-gamma"
BREW_INSTALLED_ITEMS=()
BREW_OUTDATED_ITEMS=()
BREW_INSTALLED_COUNT=0
BREW_UPGRADED_COUNT=0
BREW_SKIPPED_COUNT=0
BREW_RECONCILED_ITEMS=()
BREW_FONT_MIGRATION_BACKUP_DIR=""

if migrate_missing_brew_font_casks \
    "${FAILURE_MANIFEST}" "${FONT_DIR}" "${FAILURE_BACKUP_ROOT}"; then
    fail "Partial font migration failure must propagate a non-zero status."
fi

assert_equals old-beta "$(sed -n '1p' "${FONT_DIR}/Beta.ttf")" "Rolled back external font"
[[ ! -e "${FONT_DIR}/Gamma.ttf" ]] || fail "Absent font target must remain absent after rollback."
assert_equals new-gamma \
    "$(sed -n '1p' "${BREW_FONT_MIGRATION_BACKUP_DIR}/failed-install-artifacts/font-gamma/Gamma.ttf")" \
    "Failed install artifact preservation"
assert_equals new-beta \
    "$(sed -n '1p' "${BREW_FONT_MIGRATION_BACKUP_DIR}/failed-install-artifacts/font-beta/Beta.ttf")" \
    "Uninstall residue preservation"
assert_equals rolled-back "$(sed -n '1p' "${BREW_FONT_MIGRATION_BACKUP_DIR}/state")" \
    "Failed migration state"
assert_equals 0 "${BREW_INSTALLED_COUNT}" "Rolled back cask install count"
assert_contains 'uninstall --cask font-beta' "${BREW_CALL_LOG}" "Installed cask rollback"
assert_not_contains 'uninstall --cask font-gamma' "${BREW_CALL_LOG}" "Unregistered cask rollback"

UNSAFE_TARGET_MANIFEST="${TEST_TEMP_DIR}/unsafe-targets.txt"
: > "${UNSAFE_TARGET_MANIFEST}"
if append_brew_font_cask_targets font-unsafe "${UNSAFE_TARGET_MANIFEST}" "${FONT_DIR}"; then
    fail "Unsafe font target must be rejected."
fi

INVALID_MANIFEST="${TEST_TEMP_DIR}/invalid-casks.txt"
printf '%s\n' 'font-invalid|../Unexpected|migrate' > "${INVALID_MANIFEST}"
if validate_brew_cask_manifest "${INVALID_MANIFEST}"; then
    fail "Unsafe application name must be rejected."
fi
