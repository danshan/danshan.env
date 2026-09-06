#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
load_bootstrap_libraries
remote="${HOME}/remote"; target="${HOME}/pinned"
git init -q "${remote}"
git -C "${remote}" config user.name Test
git -C "${remote}" config user.email test@example.invalid
printf 'one\n' > "${remote}/file"
git -C "${remote}" add file; git -C "${remote}" commit -qm one
first="$(git -C "${remote}" rev-parse HEAD)"
DANSHAN_MODE=check
expect_failure ensure_pinned_git_repository example "${remote}" "${target}" "${first}"
[[ ! -e "${target}" ]] || fail 'Check cloned a repository.'
DANSHAN_MODE=apply
ensure_pinned_git_repository example "${remote}" "${target}" "${first}"
assert_equals one "$(cat "${target}/file")" 'Initial pinned checkout'
ensure_pinned_git_repository example "${remote}" "${target}" "${first}"
printf 'two\n' > "${remote}/file"
git -C "${remote}" commit -qam two
second="$(git -C "${remote}" rev-parse HEAD)"
DANSHAN_MODE=check
expect_failure ensure_pinned_git_repository example "${remote}" "${target}" "${second}"
assert_equals "${first}" "$(git -C "${target}" rev-parse HEAD)" 'Read-only pinned check'
DANSHAN_MODE=apply
ensure_pinned_git_repository example "${remote}" "${target}" "${second}"
expect_failure ensure_pinned_git_repository example "${remote}" "${target}" "${first}"
printf 'dirty\n' > "${target}/file"
expect_failure ensure_pinned_git_repository example "${remote}" "${target}" "${second}"
mkdir "${target}/nested"
expect_failure validate_tracking_git_repository_identity_if_present example "${remote}" "${target}/nested"
expect_failure validate_tracking_git_repository_identity_if_present example wrong-origin "${target}"
# Failed status cannot masquerade as a clean worktree.
git() { case "$*" in *'status --porcelain'*) return 3 ;; *) command git "$@" ;; esac; }
expect_failure update_git_repository example "${target}"
unset -f git
