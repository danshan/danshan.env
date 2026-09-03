#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_count=0

for test_script in "${TEST_DIR}"/test_*.sh; do
    if [[ "${test_script}" == *'/test_helper.sh' ]]; then
        continue
    fi
    printf 'RUN %s\n' "$(basename "${test_script}")"
    /bin/bash "${test_script}"
    test_count=$((test_count + 1))
done

printf 'PASS %s test files\n' "${test_count}"
