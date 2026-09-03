#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-install-test.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
mkdir -p "${TEST_TEMP_DIR}/bin" "${TEST_TEMP_DIR}/home"

cat > "${TEST_TEMP_DIR}/bin/bash" <<'STUB'
#!/bin/bash
exit 17
STUB
chmod +x "${TEST_TEMP_DIR}/bin/bash"

output_file="${TEST_TEMP_DIR}/output.log"
set +e
HOME="${TEST_TEMP_DIR}/home" PATH="${TEST_TEMP_DIR}/bin:/usr/bin:/bin" \
    /bin/bash "${PROJECT_ROOT}/install.sh" >"${output_file}" 2>&1
exit_code=$?
set -e

assert_equals 17 "${exit_code}" "Top-level failure propagation"
assert_contains 'Installation failed with exit code 17.' "${output_file}" "Failure message"
assert_not_contains 'danshan.env installation complete.' "${output_file}" "Success banner after failure"
