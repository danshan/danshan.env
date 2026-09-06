#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
load_bootstrap_libraries
CALLS="${HOME}/calls"
BREW_FAILURE=""
brew() {
    printf '%s\n' "$*" >> "${CALLS}"
    case "$1" in
        shellenv) [[ "${BREW_FAILURE}" != shellenv ]] || return 6; printf 'export BOOTSTRAP_TEST_ACTIVATED=1\n' ;;
        update) [[ "${BREW_FAILURE}" != update ]] || return 23 ;;
        bundle)
            [[ -z "${HOMEBREW_BUNDLE_FILE:-}${HOMEBREW_BUNDLE_BREW_SKIP:-}${HOMEBREW_BUNDLE_NO_UPGRADE:-}${HOMEBREW_CASK_OPTS:-}${HOMEBREW_NO_REQUIRE_TAP_TRUST:-}" ]] || return 7
            [[ "${HOMEBREW_NO_AUTO_UPDATE}" == 1 && "${!#}" == "--file=${PROJECT_ROOT}/Brewfile" ]] || return 8
            [[ "${BREW_FAILURE}" != "$2" ]] ;;
    esac
}
export -f brew
# shellenv is invoked as an executable, so provide one for activation.
mkdir -p "${HOME}/bin"
cat > "${HOME}/bin/brew" <<'STUB'
#!/usr/bin/env bash
[[ "${FAIL_SHELLENV:-0}" != 1 ]] || exit 6
printf 'export BOOTSTRAP_TEST_ACTIVATED=1\n'
STUB
chmod +x "${HOME}/bin/brew"
find_homebrew() { printf '%s/bin/brew\n' "${HOME}"; }
export HOMEBREW_BUNDLE_FILE=/unrelated HOMEBREW_BUNDLE_BREW_SKIP=stow HOMEBREW_BUNDLE_NO_UPGRADE=1 HOMEBREW_CASK_OPTS=--force HOMEBREW_NO_REQUIRE_TAP_TRUST=1
DANSHAN_SKIP_BREW_UPDATE=0
apply_homebrew > "${HOME}/output" 2>&1
assert_contains 'Starting: Update Homebrew metadata' "${HOME}/output" 'Update status'
assert_contains 'Finished: Verify Brewfile packages (' "${HOME}/output" 'Verified completion'
assert_contains 'bundle install --verbose --file=' "${CALLS}" 'Native Bundle live install output'
assert_contains 'bundle check --verbose --file=' "${CALLS}" 'Native Bundle verification'
for state in update install check; do
    BREW_FAILURE="${state}"
    : > "${CALLS}"
    expect_failure apply_homebrew > "${HOME}/output" 2>&1
    case "${state}" in
        update)
            assert_contains 'Failed: Update Homebrew metadata (exit 23, ' "${HOME}/output" 'Update failure status'
            assert_not_contains 'bundle install' "${CALLS}" 'No install after update failure' ;;
        install)
            assert_contains 'Failed: Install or upgrade Brewfile packages' "${HOME}/output" 'Install failure status'
            assert_not_contains 'Finished: Install or upgrade Brewfile packages' "${HOME}/output" 'No false install completion'
            assert_not_contains 'bundle check' "${CALLS}" 'No verification after install failure' ;;
        check) assert_contains 'Failed: Verify Brewfile packages' "${HOME}/output" 'Verification failure status' ;;
    esac
    assert_not_contains 'Finished: Verify Brewfile packages' "${HOME}/output" 'No false verified completion'
done
BREW_FAILURE=""
DANSHAN_SKIP_BREW_UPDATE=1
: > "${CALLS}"
apply_homebrew > "${HOME}/output" 2>&1
assert_contains 'Skipping Homebrew metadata update' "${HOME}/output" 'Explicit update skip status'
assert_not_contains 'update' "${CALLS}" 'Skipped update does not execute'
export FAIL_SHELLENV=1
expect_failure activate_homebrew
unset FAIL_SHELLENV
find_homebrew() { return 1; }
expect_failure check_homebrew
# Native Stow simulation must report missing deployment as an unmet check.
stow() { printf 'LINK: .example => repository/.example\n' >&2; }
expect_failure check_dotfiles
stow() { return 0; }
check_dotfiles
# Validate all native and tabular inventories without contacting repositories.
export SHELL=/bin/bash
validate_dotfile_config
validate_repository_config
validate_migration_config
for value in ../outside .config/../../outside /absolute .config/./mise; do expect_failure validate_relative_path "${value}"; done
# Structural validation must preserve empty fields instead of Bash IFS collapsing them.
printf 'one\t\tthree\n' > "${HOME}/empty.tsv"
expect_failure validate_table_file "${HOME}/empty.tsv" '\t' 3
printf 'one\ttwo\tthree\textra\n' > "${HOME}/extra.tsv"
expect_failure validate_table_file "${HOME}/extra.tsv" '\t' 3
printf 'one\ttwo\r\n' > "${HOME}/crlf.tsv"
expect_failure validate_table_file "${HOME}/crlf.tsv" '\t' 2
load_homebrew_install_config
[[ "${HOMEBREW_INSTALL_REF}" =~ ^[0-9a-f]{40}$ ]] || fail 'Installer commit is not pinned.'
