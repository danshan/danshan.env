#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
fixture="${HOME}/repository"
mkdir -p "${fixture}" "${HOME}/.config"
cp -R "${PROJECT_ROOT}/scripts" "${PROJECT_ROOT}/config" "${fixture}/"
mkdir -p "${fixture}/dotfiles"
cp -R "${PROJECT_ROOT}/dotfiles/mise" "${fixture}/dotfiles/"
source "${fixture}/scripts/lib/core.sh"
source "${fixture}/scripts/mise.sh"
ln -s "${DOTFILES_DIR}/mise/.config/mise" "${HOME}/.config/mise"
printf 'npm:fixture-latest\tlatest\nnpm:fixture-keep\tinstalled\nnode\tinstalled\n' > "${PROJECT_ROOT}/config/mise-policy.tsv"
CALLS="${HOME}/calls"
REMOTE_VERSION=new
FAIL_COMMAND=""
printf 'old\n' > "${HOME}/locked"
activate_homebrew() { :; }
mise() {
    [[ "$1" == --cd && "$2" == "${PROJECT_ROOT}" ]] || return 90
    shift 2
    printf '%s\n' "$*" >> "${CALLS}"
    case "$1" in
        lock)
            [[ "${DANSHAN_MODE:-apply}" != check && "${FAIL_COMMAND}" != lock ]] || return 3
            [[ "$*" == 'lock --global --bump --platform macos-arm64,macos-x64 npm:fixture-latest' ]] || return 93
            printf '%s\n' "${REMOTE_VERSION}" > "${HOME}/locked" ;;
        install)
            if [[ "$2" == --yes ]]; then
                [[ "${DANSHAN_MODE:-apply}" != check && "${FAIL_COMMAND}" != install ]] || return 4
                cp "${HOME}/locked" "${HOME}/latest-installed"
                [[ -f "${HOME}/keep-installed" ]] || printf 'retained\n' > "${HOME}/keep-installed"
                [[ -f "${HOME}/node-installed" ]] || printf 'pinned\n' > "${HOME}/node-installed"
            else
                [[ "$2" == --dry-run-code && "${FAIL_COMMAND}" != verify ]] || return 5
                [[ -f "${HOME}/latest-installed" && -f "${HOME}/keep-installed" && -f "${HOME}/node-installed" ]] || return 1
                cmp -s "${HOME}/locked" "${HOME}/latest-installed"
            fi ;;
        ls)
            [[ "$2" == --current ]] || return 91
            if [[ "${3:-}" == --json ]]; then
                [[ "${FAIL_COMMAND}" != inventory ]] || return 6
                if [[ "${FAIL_COMMAND}" == malformed ]]; then printf '[]\n'; return; fi
                printf '{"npm:fixture-latest": [], "npm:fixture-keep": [], "node": []}\n'
            fi ;;
        *) return 94 ;;
    esac
}

# Missing tools are installed, only opted-in selectors are refreshed, and pins stay intact.
apply_mise
assert_equals new "$(cat "${HOME}/latest-installed")" 'Latest tool installed after lock refresh'
assert_equals retained "$(cat "${HOME}/keep-installed")" 'Install-only tool installed'
assert_equals pinned "$(cat "${HOME}/node-installed")" 'Runtime pin retained'
apply_mise
REMOTE_VERSION=newer
apply_mise
assert_equals newer "$(cat "${HOME}/latest-installed")" 'Outdated latest tool upgraded'
assert_equals retained "$(cat "${HOME}/keep-installed")" 'Installed tool not upgraded'

# An empty latest selection must never turn into an unfiltered native lock command.
printf 'npm:fixture-latest\tinstalled\n' > "${PROJECT_ROOT}/config/mise-policy.tsv"
: > "${CALLS}"
REMOTE_VERSION=newest
apply_mise
assert_not_contains 'lock --global' "${CALLS}" 'No implicit all-tool refresh'
assert_equals newer "$(cat "${HOME}/latest-installed")" 'Switching to installed freezes the lock'

printf 'npm:fixture-latest\tlatest\n' > "${PROJECT_ROOT}/config/mise-policy.tsv"
DANSHAN_MODE=check
: > "${CALLS}"
check_mise
assert_not_contains 'lock --global' "${CALLS}" 'Check never refreshes versions'
assert_not_contains 'install --yes' "${CALLS}" 'Check never installs'
DANSHAN_MODE=apply

for FAIL_COMMAND in inventory malformed lock install verify; do
    : > "${CALLS}"
    expect_failure apply_mise
    if [[ "${FAIL_COMMAND}" == inventory || "${FAIL_COMMAND}" == malformed || "${FAIL_COMMAND}" == lock ]]; then
        assert_not_contains 'install --yes' "${CALLS}" 'Lock failure stops installation'
    elif [[ "${FAIL_COMMAND}" == install ]]; then
        assert_not_contains 'install --dry-run-code' "${CALLS}" 'Install failure stops verification'
    fi
done
FAIL_COMMAND=""
printf 'npm:unknown\tlatest\n' > "${PROJECT_ROOT}/config/mise-policy.tsv"
: > "${CALLS}"
expect_failure apply_mise
assert_not_contains 'lock --global' "${CALLS}" 'Unknown tool rejected before lock mutation'
assert_not_contains 'install --yes' "${CALLS}" 'Unknown tool rejected before installation'
