#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
load_bootstrap_libraries
STOW_MODE=success
stow() {
    local dir="${HOME}/.config/mise"
    [[ "${STOW_MODE}" != install-failure ]] || return 1
    ln -sf "${DOTFILES_DIR}/mise/.config/mise/config.toml" "${dir}/config.toml"
    [[ -L "${dir}/mise.lock" ]] || ln -s "${DOTFILES_DIR}/mise/.config/mise/mise.lock" "${dir}/mise.lock"
    if [[ "${STOW_MODE}" == verify-failure ]]; then
        ln -sf "${DOTFILES_DIR}/mise/.config/mise/mise.lock" "${dir}/config.toml"
    elif [[ "${STOW_MODE}" == rollback-incomplete ]]; then
        rm "${dir}/config.toml"
        printf 'unrecognized new data\n' > "${dir}/config.toml"
        return 1
    fi
}
legacy() { mkdir -p "${HOME}/.config/mise"; printf '[tools]\nnode = "24.18.0"\n' > "${HOME}/.config/mise/config.toml"; }
for mode in success install-failure verify-failure rollback-incomplete; do
    STOW_MODE="${mode}"
    rm -rf "${HOME}/.config/mise"
    legacy
    root="${HOME}/${mode}"
    if [[ "${mode}" == success ]]; then
        migrate_legacy_stow_file mise .config/mise/config.toml "${root}"
        verify_mise_deployment
        result=0; migrate_legacy_stow_file mise .config/mise/config.toml "${root}" || result=$?
        assert_equals 2 "${result}" 'Repeated legacy migration'
    else expect_failure migrate_legacy_stow_file mise .config/mise/config.toml "${root}"; fi
    backup="$(find "${root}" -mindepth 1 -maxdepth 1 -type d -print)"
    assert_contains 'node = "24.18.0"' "${backup}/originals/.config/mise/config.toml" 'Retained legacy config'
    case "${mode}" in
        success) assert_equals completed "$(cat "${backup}/state")" 'Stow commit' ;;
        rollback-incomplete) assert_equals rollback-incomplete "$(cat "${backup}/state")" 'Stow incomplete rollback'
            assert_contains 'unrecognized new data' "${HOME}/.config/mise/config.toml" 'Preserved conflicting file' ;;
        *) assert_equals rolled-back "$(cat "${backup}/state")" 'Stow rollback'
            assert_contains 'node = "24.18.0"' "${HOME}/.config/mise/config.toml" 'Restored legacy config' ;;
    esac
done
# A failed snapshot move cannot be swallowed by a caller's conditional context.
rm -rf "${HOME}/.config/mise"; legacy
mv() { case "$1" in --) [[ "$2" != "${HOME}/.config/mise/config.toml" ]] || return 7 ;; esac; command mv "$@"; }
expect_failure migrate_legacy_stow_file mise .config/mise/config.toml "${HOME}/move-failed"
unset -f mv
assert_contains 'node = "24.18.0"' "${HOME}/.config/mise/config.toml" 'Failed snapshot move preserves target'
recover_interrupted_stow_migrations "${HOME}/move-failed"
# An already-owned lockfile survives rollback.
ln -s "${DOTFILES_DIR}/mise/.config/mise/mise.lock" "${HOME}/.config/mise/mise.lock"
STOW_MODE=install-failure
expect_failure migrate_legacy_stow_file mise .config/mise/config.toml "${HOME}/owned-lock"
[[ -L "${HOME}/.config/mise/mise.lock" ]] || fail 'Rollback lost an existing owned lockfile.'
# Recovery after moving the original always restores it; success is not inferred from one link.
backup="${HOME}/interrupted/one"
mkdir -p "${backup}/originals/.config/mise"
mv "${HOME}/.config/mise/config.toml" "${backup}/originals/.config/mise/config.toml"
printf 'mise|.config/mise/config.toml\n' > "${backup}/manifest.txt"
write_migration_state "${backup}" reconciling
recover_interrupted_stow_migrations "${HOME}/interrupted"
write_migration_state "${backup}" rolling-back
recover_interrupted_stow_migrations "${HOME}/interrupted"
assert_contains 'node = "24.18.0"' "${HOME}/.config/mise/config.toml" 'Repeated Stow recovery'
# Unknown settings and assignments outside [tools] cannot pass subset validation.
printf '[tools]\nunknown = "1"\n' > "${HOME}/.config/mise/config.toml"
expect_failure migrate_legacy_stow_file mise .config/mise/config.toml "${HOME}/unknown"
[[ ! -e "${HOME}/unknown" ]] || fail 'Rejected config created a snapshot.'
printf '[settings]\nnode = "24.18.0"\n' > "${HOME}/wrong-section.toml"
expect_failure source_has_simple_toml_tool "${HOME}/wrong-section.toml" node 24.18.0
