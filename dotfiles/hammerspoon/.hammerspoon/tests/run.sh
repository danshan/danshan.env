#!/bin/bash

set -u

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly HS_BIN="${HS_BIN:-$(command -v hs)}"

if [[ -z "${HS_BIN}" ]]; then
    echo "hs is required" >&2
    exit 1
fi

run_hs() {
    local output

    if ! output="$("${HS_BIN}" "$@" 2>&1)"; then
        echo "${output}" >&2
        return 1
    fi

    if [[ "${output}" == *"can't access Hammerspoon message port"* ]]; then
        echo "${output}" >&2
        return 1
    fi
}

while IFS= read -r file; do
    if ! run_hs -t 2 -q -c "assert(loadfile([[${file}]]))"; then
        echo "Lua syntax check failed: ${file}" >&2
        exit 1
    fi
done < <(find "${ROOT_DIR}" -type f -name '*.lua' -not -path '*/Spoons/*' | sort)

run_hs -t 2 -q "${ROOT_DIR}/tests/windows_test.lua"

echo "All checks passed"
