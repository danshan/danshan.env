#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
load_bootstrap_libraries
DANSHAN_MODE=check
lock_bootstrap
[[ ! -e "${STATE_ROOT}" ]] || fail 'Check created state.'
DANSHAN_MODE=apply
lock_bootstrap
expect_failure /usr/bin/lockf -k -t 0 "${STATE_ROOT}/locks/bootstrap.lock" /usr/bin/true
exec 9>&-
/usr/bin/lockf -k -t 0 "${STATE_ROOT}/locks/bootstrap.lock" /usr/bin/true
# The descriptor lock survives the acquiring helper and serializes independent processes.
/usr/bin/lockf -k -t 0 "${STATE_ROOT}/locks/bootstrap.lock" /bin/sh -c 'echo ready > "$1"; sleep 2' sh "${HOME}/ready" &
owner=$!
for attempt in {1..100}; do [[ ! -f "${HOME}/ready" ]] || break; sleep 0.02; done
[[ -f "${HOME}/ready" ]] || fail 'Lock holder did not start.'
DANSHAN_MODE=check
expect_failure lock_bootstrap
exec 9<&-
wait "${owner}"
lock_bootstrap
exec 9<&-
mkdir -p "${STATE_ROOT}/locks/cask-migration.lock"
expect_failure lock_bootstrap
printf '%s\n' "$$" > "${STATE_ROOT}/locks/cask-migration.lock/pid"
expect_failure lock_bootstrap
