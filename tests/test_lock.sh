#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
load_bootstrap_libraries
LOCK_HELPER="${PROJECT_ROOT}/scripts/lib/lock.pl"

lock_path() {
    /bin/bash -c '
        exec 8>"$1"
        LC_ALL=C exec /usr/bin/perl "$2" 8
    ' sh "$1" "${LOCK_HELPER}"
}

DANSHAN_MODE=check
lock_bootstrap
[[ ! -e "${STATE_ROOT}" ]] || fail 'Check created state.'
DANSHAN_MODE=apply
lock_bootstrap
expect_failure lock_path "${STATE_ROOT}/locks/bootstrap.lock"
exec 9>&-
/bin/bash -c '
    exec 8>"$1"
    LC_ALL=C /usr/bin/perl "$2" 8
' sh "${STATE_ROOT}/locks/bootstrap.lock" "${LOCK_HELPER}"
# The descriptor lock survives the acquiring helper and serializes independent processes.
/bin/bash -c '
    exec 8>"$1"
    LC_ALL=C /usr/bin/perl "$2" 8 || exit
    echo ready > "$3"
    sleep 2
' sh "${STATE_ROOT}/locks/bootstrap.lock" "${LOCK_HELPER}" "${HOME}/ready" &
owner=$!
for attempt in {1..100}; do [[ ! -f "${HOME}/ready" ]] || break; sleep 0.02; done
[[ -f "${HOME}/ready" ]] || fail 'Lock holder did not start.'
DANSHAN_MODE=check
expect_failure lock_bootstrap
exec 9<&-
wait "${owner}"
lock_bootstrap
exec 9<&-
helper_output="${TEST_TEMP_DIR}/lock-helper-output"
if acquire_file_lock "${LOCK_HELPER}" 99 > "${helper_output}" 2>&1; then
    fail 'Invalid helper descriptor succeeded.'
else
    helper_status=$?
fi
assert_equals 2 "${helper_status}" 'Helper failure status'
assert_contains 'Lock helper failed:' "${helper_output}" 'Helper failure diagnostic'
if (
    acquire_file_lock() { return 2; }
    lock_bootstrap
) > "${helper_output}" 2>&1; then
    fail 'Bootstrap accepted a lock helper failure.'
fi
assert_contains 'Failed to acquire Bootstrap lock' "${helper_output}" 'Bootstrap helper failure diagnostic'
assert_not_contains 'Another Bootstrap operation holds' "${helper_output}" 'Bootstrap helper failure is not contention'
mkdir -p "${STATE_ROOT}/locks/cask-migration.lock"
expect_failure lock_bootstrap
printf '%s\n' "$$" > "${STATE_ROOT}/locks/cask-migration.lock/pid"
expect_failure lock_bootstrap
