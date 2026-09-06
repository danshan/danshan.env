#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
load_bootstrap_libraries
application_root() { printf '%s/Applications\n' "${HOME}"; }
mkdir -p "${HOME}/Applications" "${HOME}/Library/Fonts" "${HOME}/brew-state"
BREW_MODE=success
brew() {
    local package="${!#}" target item
    if [[ "$*" == 'list --cask -1' ]]; then
        [[ "${BREW_MODE}" != inventory-failure ]] || return 9
        for item in "${HOME}/brew-state/"*; do
            [[ ! -f "${item}" ]] || printf '%s\n' "${item##*/}"
        done
        return 0
    fi
    case "${package}" in
        app) target="${HOME}/Applications/Example.app" ;;
        font-a|font-b) target="${HOME}/Library/Fonts/${package}.ttf" ;;
        *) return 90 ;;
    esac
    case "$*" in
        'info --cask --json=v2 '*)
            printf '{"casks":[{"artifacts":[{"font":["%s.ttf"],"target":"%s"}]}]}\n' "${package}" "${target}" ;;
        'list --cask '*) [[ -f "${HOME}/brew-state/${package}" ]] ;;
        'install --cask '*)
            if [[ "${package}" == app ]]; then mkdir -p "${target}"; printf 'new\n' > "${target}/version";
            else printf 'new\n' > "${target}"; fi
            : > "${HOME}/brew-state/${package}"
            if [[ "${BREW_MODE}" == verify-failure ]]; then rm -rf "${target}"; fi
            [[ "${BREW_MODE}" != install-failure && "${BREW_MODE}" != rollback-incomplete && ! ( "${BREW_MODE}" == partial && "${package}" == font-b ) ]] ;;
        'uninstall --cask '*)
            # Real Cask uninstall removes artifacts, not only inventory records.
            [[ "${BREW_MODE}" != rollback-incomplete ]] || return 1
            rm -rf "${target}"
            rm -f "${HOME}/brew-state/${package}" ;;
        *) return 91 ;;
    esac
}
last_snapshot() { find "$1" -mindepth 1 -maxdepth 1 -type d -print | tail -1; }
for mode in success install-failure verify-failure rollback-incomplete; do
    BREW_MODE="${mode}"
    root="${HOME}/${mode}-app"
    target="${HOME}/Applications/Example.app"
    rm -rf "${target}"; rm -f "${HOME}/brew-state/app"
    mkdir -p "${target}"; printf 'old\n' > "${target}/version"
    if [[ "${mode}" == success ]]; then migrate_existing_brew_app_cask app Example "${root}";
    else expect_failure migrate_existing_brew_app_cask app Example "${root}"; fi
    backup="$(last_snapshot "${root}")"
    assert_equals old "$(cat "${backup}/originals/Example.app/version")" 'Retained App original'
    case "${mode}" in
        success) assert_equals completed "$(cat "${backup}/state")" 'App commit' ;;
        rollback-incomplete) assert_equals rollback-incomplete "$(cat "${backup}/state")" 'Incomplete App rollback'; expect_failure recover_interrupted_app_migration "${backup}" ;;
        *) assert_equals rolled-back "$(cat "${backup}/state")" 'App rollback' ;;
    esac
    if [[ "${mode}" != success ]]; then assert_equals old "$(cat "${target}/version")" 'Restored App'; fi
    if [[ "${mode}" == install-failure ]]; then assert_equals new "$(cat "${backup}/failed-install-artifact/Example.app/version")" 'Preserved failed App before uninstall'; fi
done
BREW_MODE=success
root="${HOME}/interrupted-app"; mkdir -p "${root}/originals"
printf 'app|%s|present\n' "${target}" > "${root}/manifest.txt"
write_migration_state "${root}" snapshot-failed
recover_interrupted_app_migration "${root}"
assert_equals old "$(cat "${target}/version")" 'Snapshot failure leaves untouched App in place'
assert_equals rolled-back "$(cat "${root}/state")" 'Snapshot failure recovery'
# Recovery is repeatable after original restoration but before the final state write.
mv "${target}" "${root}/originals/Example.app"
write_migration_state "${root}" verifying
recover_interrupted_app_migration "${root}"
write_migration_state "${root}" rolling-back
recover_interrupted_app_migration "${root}"
assert_equals old "$(cat "${target}/version")" 'Repeated App recovery'

for mode in success partial verify-failure rollback-incomplete; do
    BREW_MODE="${mode}"
    root="${HOME}/${mode}-fonts"
    rm -f "${HOME}/brew-state/font-a" "${HOME}/brew-state/font-b"
    printf 'old-a\n' > "${HOME}/Library/Fonts/font-a.ttf"
    rm -f "${HOME}/Library/Fonts/font-b.ttf"
    if [[ "${mode}" == success ]]; then migrate_brew_font_casks "${HOME}/Library/Fonts" "${root}" font-a font-b;
    else expect_failure migrate_brew_font_casks "${HOME}/Library/Fonts" "${root}" font-a font-b; fi
    backup="$(last_snapshot "${root}")"
    assert_equals old-a "$(cat "${backup}/originals/font-a/font-a.ttf")" 'Retained font original'
    case "${mode}" in
        success) assert_equals completed "$(cat "${backup}/state")" 'Font batch commit' ;;
        rollback-incomplete) assert_equals rollback-incomplete "$(cat "${backup}/state")" 'Incomplete font rollback' ;;
        *) assert_equals rolled-back "$(cat "${backup}/state")" 'Font batch rollback' ;;
    esac
    if [[ "${mode}" != success ]]; then
        assert_equals old-a "$(cat "${HOME}/Library/Fonts/font-a.ttf")" 'Restored font'
        [[ ! -e "${HOME}/Library/Fonts/font-b.ttf" ]] || fail 'Originally absent font must remain absent.'
    fi
    if [[ "${mode}" == partial ]]; then
        assert_equals new "$(cat "${backup}/failed-install-artifacts/font-a/font-a.ttf")" 'Preserved installed font before uninstall'
        write_migration_state "${backup}" rolling-back
        BREW_MODE=success
        recover_interrupted_font_migration "${backup}"
    fi
done
# Invalid recovery metadata must never move arbitrary files, including via parent symlinks.
root="${HOME}/unsafe-font"; mkdir -p "${root}"
printf 'untouched\n' > "${HOME}/unrelated.txt"
printf 'font-a|%s|absent\n' "${HOME}/unrelated.txt" > "${root}/manifest.txt"
write_migration_state "${root}" installing
expect_failure recover_interrupted_font_migration "${root}"
assert_equals untouched "$(cat "${HOME}/unrelated.txt")" 'Unsafe recovery target'
printf 'font-a|%s|absent\n' "${HOME}/Library/Fonts/../unrelated.ttf" > "${root}/manifest.txt"
expect_failure recover_interrupted_font_migration "${root}"
# Legacy completed snapshots remain unchanged after ownership validation.
root="${HOME}/legacy-font"; mkdir -p "${root}/font-a"
printf 'old\n' > "${root}/font-a/font-a.ttf"
printf 'new\n' > "${HOME}/Library/Fonts/font-a.ttf"
: > "${HOME}/brew-state/font-a"
printf 'font-a|%s|%s\n' "${HOME}/Library/Fonts/font-a.ttf" "${root}/font-a/font-a.ttf" > "${root}/manifest.txt"
recover_interrupted_font_migration "${root}"
[[ ! -e "${root}/state" ]] || fail 'Legacy snapshot must remain immutable.'
# Partial snapshot failure cannot uninstall a Cask or move the untouched second font.
BREW_MODE=success
printf 'old-a\n' > "${HOME}/Library/Fonts/font-a.ttf"
printf 'old-b\n' > "${HOME}/Library/Fonts/font-b.ttf"
rm -f "${HOME}/brew-state/font-a" "${HOME}/brew-state/font-b"
mv() {
    if [[ "$1" == -- && "$2" == "${HOME}/Library/Fonts/font-b.ttf" ]]; then return 7; fi
    command mv "$@"
}
expect_failure migrate_brew_font_casks "${HOME}/Library/Fonts" "${HOME}/snapshot-failed-fonts" font-a font-b
unset -f mv
assert_equals old-a "$(cat "${HOME}/Library/Fonts/font-a.ttf")" 'Restored partially moved batch'
assert_equals old-b "$(cat "${HOME}/Library/Fonts/font-b.ttf")" 'Untouched original after failed snapshot move'
# A missing original in the install phase must stop before altering existing targets.
root="${HOME}/missing-original"; mkdir -p "${root}"
printf 'font-a|%s|present\n' "${HOME}/Library/Fonts/font-a.ttf" > "${root}/manifest.txt"
write_migration_state "${root}" installing
expect_failure recover_interrupted_font_migration "${root}"
assert_equals old-a "$(cat "${HOME}/Library/Fonts/font-a.ttf")" 'Missing snapshot leaves target untouched'
# Unexpected metadata target is rejected before a snapshot is created.
append_brew_font_cask_targets() { printf 'font-a|%s\n' "${HOME}/outside.ttf" >> "$2"; }
expect_failure migrate_brew_font_casks "${HOME}/Library/Fonts" "${HOME}/invalid-metadata" font-a
[[ ! -e "${HOME}/invalid-metadata" ]] || fail 'Invalid metadata opened a transaction.'

# Unknown inventory is not evidence that uninstall is unnecessary.
BREW_MODE=inventory-failure
root="${HOME}/unknown-inventory"; mkdir -p "${root}/originals/Example.app"
printf 'old\n' > "${root}/originals/Example.app/version"
printf 'app|%s|present\n' "${HOME}/Applications/Example.app" > "${root}/manifest.txt"
write_migration_state "${root}" installing
expect_failure recover_interrupted_app_migration "${root}"
assert_equals rollback-incomplete "$(cat "${root}/state")" 'Inventory failure cannot claim rollback success'
# Failed-artifact directories must not redirect recovery outside the snapshot.
BREW_MODE=success
root="${HOME}/symlinked-recovery"; mkdir -p "${root}" "${HOME}/redirect"
printf 'font-a|%s|absent\n' "${HOME}/Library/Fonts/font-a.ttf" > "${root}/manifest.txt"
ln -s "${HOME}/redirect" "${root}/failed-install-artifacts"
write_migration_state "${root}" installing
expect_failure recover_interrupted_font_migration "${root}"
[[ -z "$(ls -A "${HOME}/redirect")" ]] || fail 'Recovery followed a symlinked retention directory.'

# Cross-filesystem mv is copy/delete and must never be used as an atomic snapshot.
printf 'original\n' > "${HOME}/cross-volume-original"
mkdir -p "${HOME}/cross-volume-backup"
stat() { if [[ "${!#}" == "${HOME}/cross-volume-original" ]]; then printf '1\n'; else printf '2\n'; fi; }
expect_failure move_to_snapshot "${HOME}/cross-volume-original" "${HOME}/cross-volume-backup/original"
unset -f stat
assert_equals original "$(cat "${HOME}/cross-volume-original")" 'Cross-volume snapshot preserves original'
[[ ! -e "${HOME}/cross-volume-backup/original" ]] || fail 'Cross-volume snapshot copied an unverified original.'
