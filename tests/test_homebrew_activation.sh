#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-homebrew-activation-test.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT

mkdir -p "${TEST_TEMP_DIR}/bin"
BREW_STUB_PATH="${TEST_TEMP_DIR}/bin/brew"
{
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -Eeuo pipefail'
    printf '%s\n' '[[ "${SHELL}" == /bin/bash ]] || exit 17'
    printf '%s\n' '[[ "${1:-}" == shellenv ]] || exit 18'
    printf '%s\n' 'printf '\''%s\n'\'' '\''export HOMEBREW_PREFIX="/test/homebrew";'\'''
} > "${BREW_STUB_PATH}"
chmod +x "${BREW_STUB_PATH}"

PATH="${TEST_TEMP_DIR}/bin:/usr/bin:/bin"
export PATH
SHELL=/opt/homebrew/bin/fish
export SHELL

# shellcheck source=scripts/common.sh
source "${PROJECT_ROOT}/scripts/common.sh"
activate_homebrew

assert_equals /test/homebrew "${HOMEBREW_PREFIX}" "Bash Homebrew shell environment"
