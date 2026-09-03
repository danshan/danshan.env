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
