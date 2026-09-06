#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"
# shellcheck source=scripts/common.sh
source "${PROJECT_ROOT}/scripts/common.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-migration-recovery.XXXXXX")"
trap 'release_brew_migration_lock; rm -rf -- "${TEST_TEMP_DIR}"' EXIT
export HOME="${TEST_TEMP_DIR}/home"
APPLICATIONS_DIR="${TEST_TEMP_DIR}/Applications"
APP_BACKUP_ROOT="${TEST_TEMP_DIR}/app-backups"
FONT_BACKUP_ROOT="${TEST_TEMP_DIR}/font-backups"
FONT_DIR="${HOME}/Library/Fonts"
BREW_STATE_DIR="${TEST_TEMP_DIR}/brew-state"
mkdir -p -- "${APPLICATIONS_DIR}" "${APP_BACKUP_ROOT}" "${FONT_BACKUP_ROOT}" \
    "${FONT_DIR}" "${BREW_STATE_DIR}"

application_bundle_path() {
    printf '%s/%s.app\n' "${APPLICATIONS_DIR}" "$1"
}

brew() {
    case "$*" in
        'list --cask interrupted-app') [[ -f "${BREW_STATE_DIR}/interrupted-app" ]] ;;
        'uninstall --cask interrupted-app') rm -f -- "${BREW_STATE_DIR}/interrupted-app" ;;
        'list --cask interrupted-font') [[ -f "${BREW_STATE_DIR}/interrupted-font" ]] ;;
        'uninstall --cask interrupted-font') rm -f -- "${BREW_STATE_DIR}/interrupted-font" ;;
        'list --cask legacy-font') [[ -f "${BREW_STATE_DIR}/legacy-font" ]] ;;
        *) fail "Unexpected brew recovery invocation: $*" ;;
    esac
}

app_backup="${APP_BACKUP_ROOT}/interrupted-app"
app_target="$(application_bundle_path 'Interrupted App')"
app_original="${app_backup}/originals/Interrupted App.app"
mkdir -p -- "${app_original}/Contents" "${app_target}/Contents"
printf '%s\n' old > "${app_original}/Contents/version.txt"
printf '%s\n' new > "${app_target}/Contents/version.txt"
printf '%s|%s|present\n' interrupted-app "${app_target}" > "${app_backup}/manifest.txt"
write_migration_state "${app_backup}" installing
: > "${BREW_STATE_DIR}/interrupted-app"

font_backup="${FONT_BACKUP_ROOT}/interrupted-font"
font_target="${FONT_DIR}/Interrupted.ttf"
font_original="${font_backup}/originals/interrupted-font/Interrupted.ttf"
mkdir -p -- "${font_original%/*}"
printf '%s\n' old-font > "${font_original}"
printf '%s\n' new-font > "${font_target}"
printf '%s|%s|present\n' interrupted-font "${font_target}" > "${font_backup}/manifest.txt"
write_migration_state "${font_backup}" verifying
: > "${BREW_STATE_DIR}/interrupted-font"

legacy_backup="${FONT_BACKUP_ROOT}/legacy-completed"
legacy_target="${FONT_DIR}/Legacy.ttf"
legacy_original="${legacy_backup}/legacy-font/Legacy.ttf"
mkdir -p -- "${legacy_original%/*}"
printf '%s\n' old-legacy > "${legacy_original}"
printf '%s\n' current-legacy > "${legacy_target}"
printf '%s|%s|%s\n' legacy-font "${legacy_target}" "${legacy_original}" \
    > "${legacy_backup}/manifest.txt"
: > "${BREW_STATE_DIR}/legacy-font"

recover_interrupted_brew_migrations "${APP_BACKUP_ROOT}" "${FONT_BACKUP_ROOT}"

assert_equals old "$(sed -n '1p' "${app_target}/Contents/version.txt")" \
    "Interrupted application restoration"
assert_equals new \
    "$(sed -n '1p' "${app_backup}/failed-install-artifact/Interrupted App.app/Contents/version.txt")" \
    "Interrupted application artifact preservation"
assert_equals rolled-back "$(sed -n '1p' "${app_backup}/state")" \
    "Interrupted application state"
assert_equals old-font "$(sed -n '1p' "${font_target}")" \
    "Interrupted font restoration"
assert_equals new-font \
    "$(sed -n '1p' "${font_backup}/failed-install-artifacts/interrupted-font/Interrupted.ttf")" \
    "Interrupted font artifact preservation"
assert_equals rolled-back "$(sed -n '1p' "${font_backup}/state")" \
    "Interrupted font state"
[[ ! -e "${legacy_backup}/state" ]] || fail "Legacy snapshot recovery must not rewrite history."
assert_equals old-legacy "$(sed -n '1p' "${legacy_original}")" \
    "Legacy snapshot preservation"

invalid_legacy_root="${TEST_TEMP_DIR}/invalid-legacy-font-backups"
invalid_legacy="${invalid_legacy_root}/invalid"
mkdir -p -- "${invalid_legacy}"
printf '%s|%s|%s\n' legacy-font "${FONT_DIR}/Missing.ttf" \
    "${invalid_legacy}/legacy-font/Missing.ttf" > "${invalid_legacy}/manifest.txt"
if recover_interrupted_brew_migrations "${TEST_TEMP_DIR}/empty-app-backups" \
    "${invalid_legacy_root}"; then
    fail "Unverified stateless font snapshot must fail closed."
fi

lock_root="${TEST_TEMP_DIR}/locks"
acquire_brew_migration_lock "${lock_root}"
assert_equals 1 "${DANSHAN_MIGRATION_LOCK_HELD}" "Migration lock acquisition"
if (DANSHAN_MIGRATION_LOCK_HELD=0; acquire_brew_migration_lock "${lock_root}"); then
    fail "Concurrent migration lock acquisition must fail."
fi
release_brew_migration_lock
assert_equals 0 "${DANSHAN_MIGRATION_LOCK_HELD}" "Migration lock release"

mkdir -p -- "${lock_root}/cask-migration.lock"
printf '%s\n' 999999 > "${lock_root}/cask-migration.lock/pid"
acquire_brew_migration_lock "${lock_root}"
assert_equals 1 "${DANSHAN_MIGRATION_LOCK_HELD}" "Stale migration lock recovery"
