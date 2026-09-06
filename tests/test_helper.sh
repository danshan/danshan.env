#!/usr/bin/env bash

set -Eeuo pipefail

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    return 1
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "${expected}" != "${actual}" ]]; then
        fail "${message}: expected=${expected}, actual=${actual}"
    fi
}

assert_contains() {
    local expected="$1"
    local file_path="$2"
    local message="$3"

    grep -Fq -- "${expected}" "${file_path}" || fail "${message}: missing '${expected}'"
}

assert_not_contains() {
    local unexpected="$1"
    local file_path="$2"
    local message="$3"

    if grep -Fq -- "${unexpected}" "${file_path}"; then
        fail "${message}: found '${unexpected}'"
    fi
}

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-test.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
export HOME="${TEST_TEMP_DIR}/home"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CACHE_HOME="${HOME}/.cache"
export DANSHAN_NO_COLOR=1
mkdir -p -- "${HOME}"

load_bootstrap_libraries() {
    local module
    source "${PROJECT_ROOT}/scripts/lib/core.sh"
    for module in homebrew mise dotfiles repositories migrations/transaction migrations/casks migrations/legacy-mise migrations/runner preflight; do
        source "${PROJECT_ROOT}/scripts/${module}.sh"
    done
}

expect_failure() {
    if "$@"; then fail "Expected failure: $*"; fi
}
