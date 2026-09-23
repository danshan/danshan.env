#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
command -v brew >/dev/null || fail 'Homebrew is required for native policy verification.'

# Exercise the real Homebrew environment filter without installing any packages.
export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_BOOTSNAP=1 LC_ALL=C
export HOMEBREW_NO_INSTALL_FROM_API=1
export HOMEBREW_DANSHAN_BREW_POLICY=invalid DANSHAN_BREW_POLICY=invalid
before="$(find "${HOME}" -type f -exec shasum {} \; | sort)"
for policy in latest installed all; do
    /usr/bin/sandbox-exec -f "${PROJECT_ROOT}/config/check.sb" /bin/bash -c '
        set -euo pipefail
        source "$1/scripts/lib/core.sh"
        source "$1/scripts/homebrew.sh"
        if [[ "$2" == all ]]; then
            bundle list --cask
        else
            bundle --policy "$2" list --cask
        fi
    ' bash "${PROJECT_ROOT}" "${policy}" | sort > "${TEST_TEMP_DIR}/${policy}"
done
assert_equals '' "$(comm -12 "${TEST_TEMP_DIR}/latest" "${TEST_TEMP_DIR}/installed")" 'Native policy groups must not overlap'
assert_equals "$(cat "${TEST_TEMP_DIR}/all")" "$(sort -u "${TEST_TEMP_DIR}/latest" "${TEST_TEMP_DIR}/installed")" 'Native policy groups must preserve the complete Cask inventory'
assert_not_contains rebased "${TEST_TEMP_DIR}/latest" 'Rebased must not enter the upgrade group'
assert_contains rebased "${TEST_TEMP_DIR}/installed" 'Rebased must remain install-only'
assert_contains chatgpt "${TEST_TEMP_DIR}/latest" 'Latest Casks must remain eligible for upgrades'
assert_equals "${before}" "$(find "${HOME}" -type f -exec shasum {} \; | sort)" 'Native policy verification must preserve HOME'
