#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"

if ! command -v fish >/dev/null 2>&1; then
    printf '%s\n' 'SKIP: fish is not available.'
    exit 0
fi

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-gtest.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
repository_path="${TEST_TEMP_DIR}/repository"
mkdir -p "${repository_path}"
git -C "${repository_path}" init --quiet
git -C "${repository_path}" config user.name Test
git -C "${repository_path}" config user.email test@example.com
printf '%s\n' initial > "${repository_path}/tracked.txt"
git -C "${repository_path}" add tracked.txt
git -C "${repository_path}" commit --quiet -m initial
printf '%s\n' stashed > "${repository_path}/tracked.txt"
git -C "${repository_path}" stash push --quiet
stash_before="$(git -C "${repository_path}" rev-parse refs/stash)"

set +e
fish -c "cd '${repository_path}'; source '${PROJECT_ROOT}/dotfiles/fish/.config/fish/functions/gtest.fish'; gtest true" >/dev/null 2>&1
gtest_exit_code=$?
set -e

stash_after="$(git -C "${repository_path}" rev-parse refs/stash)"
assert_equals 2 "${gtest_exit_code}" "gtest no-staged-change exit code"
assert_equals "${stash_before}" "${stash_after}" "Existing stash preservation"
assert_equals '' "$(git -C "${repository_path}" status --short)" "Worktree state after rejected gtest"
