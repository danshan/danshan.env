#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"
# shellcheck source=scripts/common.sh
source "${PROJECT_ROOT}/scripts/common.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-stow-migration.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
export HOME="${TEST_TEMP_DIR}/home"
mkdir -p -- "${HOME}/.config/mise"
STOW_MODE=success

write_legacy_config() {
    local target_path="$1"
    mkdir -p -- "${target_path%/*}"
    printf '%s\n' \
        '[tools]' \
        'java = "zulu-17.66.19.0"' \
        'node = "24.18.0"' \
        > "${target_path}"
}

stow() {
    local target_config="${HOME}/.config/mise/config.toml"
    local target_lock="${HOME}/.config/mise/mise.lock"
    case "$*" in
        *'--delete'*)
            rm -f -- "${target_config}" "${target_lock}"
            [[ "${STOW_MODE}" != rollback-incomplete ]]
            ;;
        *)
            [[ "${STOW_MODE}" != install-failure && "${STOW_MODE}" != rollback-incomplete ]] || return 1
            mkdir -p -- "${target_config%/*}"
            ln -s "${DOTFILES_DIR}/mise/.config/mise/config.toml" "${target_config}"
            ln -s "${DOTFILES_DIR}/mise/.config/mise/mise.lock" "${target_lock}"
            if [[ "${STOW_MODE}" == verify-failure ]]; then
                rm -f -- "${target_config}"
                ln -s "${DOTFILES_DIR}/mise/.config/mise/mise.lock" "${target_config}"
            fi
            ;;
    esac
}

target_config="${HOME}/.config/mise/config.toml"
success_root="${TEST_TEMP_DIR}/success"
write_legacy_config "${target_config}"
migrate_legacy_stow_file mise .config/mise/config.toml "${success_root}"
[[ -L "${target_config}" ]] || fail "Successful migration must install a symlink."
success_backup="$(find "${success_root}" -mindepth 1 -maxdepth 1 -type d -print -quit)"
assert_equals completed "$(sed -n '1p' "${success_backup}/state")" \
    "Successful Stow migration state"
assert_contains 'java = "zulu-17.66.19.0"' \
    "${success_backup}/originals/.config/mise/config.toml" \
    "Successful Stow migration snapshot"
if migrate_legacy_stow_file mise .config/mise/config.toml "${success_root}"; then
    fail "Repeat migration must report not applicable."
else
    assert_equals 2 "$?" "Repeat Stow migration result"
fi

rm -f -- "${HOME}/.config/mise/config.toml" "${HOME}/.config/mise/mise.lock"
failure_root="${TEST_TEMP_DIR}/install-failure"
write_legacy_config "${target_config}"
STOW_MODE=install-failure
if migrate_legacy_stow_file mise .config/mise/config.toml "${failure_root}"; then
    fail "Stow install failure must fail migration."
fi
[[ -f "${target_config}" && ! -L "${target_config}" ]] || \
    fail "Install failure must restore the legacy config."
failure_backup="$(find "${failure_root}" -mindepth 1 -maxdepth 1 -type d -print -quit)"
assert_equals rolled-back "$(sed -n '1p' "${failure_backup}/state")" \
    "Install failure Rollback state"

rm -f -- "${target_config}"
verify_root="${TEST_TEMP_DIR}/verify-failure"
write_legacy_config "${target_config}"
STOW_MODE=verify-failure
if migrate_legacy_stow_file mise .config/mise/config.toml "${verify_root}"; then
    fail "Stow verification failure must fail migration."
fi
[[ -f "${target_config}" && ! -L "${target_config}" ]] || \
    fail "Verify failure must restore the legacy config."
verify_backup="$(find "${verify_root}" -mindepth 1 -maxdepth 1 -type d -print -quit)"
assert_equals rolled-back "$(sed -n '1p' "${verify_backup}/state")" \
    "Verify failure Rollback state"

rm -f -- "${target_config}"
incomplete_root="${TEST_TEMP_DIR}/rollback-incomplete"
write_legacy_config "${target_config}"
STOW_MODE=rollback-incomplete
if migrate_legacy_stow_file mise .config/mise/config.toml "${incomplete_root}"; then
    fail "Incomplete Stow Rollback must fail migration."
fi
incomplete_backup="$(find "${incomplete_root}" -mindepth 1 -maxdepth 1 -type d -print -quit)"
assert_equals rollback-incomplete "$(sed -n '1p' "${incomplete_backup}/state")" \
    "Incomplete Stow Rollback state"
[[ -f "${target_config}" ]] || fail "Incomplete Rollback should preserve the original config."

rm -f -- "${target_config}" "${HOME}/.config/mise/mise.lock"
recovery_root="${TEST_TEMP_DIR}/recovery"
recovery_backup="${recovery_root}/interrupted"
recovery_original="${recovery_backup}/originals/.config/mise/config.toml"
write_legacy_config "${recovery_original}"
printf '%s\n' 'mise|.config/mise/config.toml' > "${recovery_backup}/manifest.txt"
write_migration_state "${recovery_backup}" reconciling
STOW_MODE=success
recover_interrupted_stow_migrations "${recovery_root}"
assert_equals rolled-back "$(sed -n '1p' "${recovery_backup}/state")" \
    "Interrupted Stow migration state"
[[ -f "${target_config}" && ! -L "${target_config}" ]] || \
    fail "Interrupted migration must restore the legacy config."

unrecognized_root="${TEST_TEMP_DIR}/unrecognized"
printf '%s\n' '[tools]' 'custom = "1.0.0"' > "${target_config}"
if migrate_legacy_stow_file mise .config/mise/config.toml "${unrecognized_root}"; then
    fail "Unrecognized existing config must fail closed."
fi
[[ ! -d "${unrecognized_root}" ]] || fail "Rejected config must not create a snapshot."
