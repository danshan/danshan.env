#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"
# shellcheck source=scripts/common.sh
source "${PROJECT_ROOT}/scripts/common.sh"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-preflight.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT

formula_manifest="${TEST_TEMP_DIR}/formulae.txt"
printf '%s\n' git Git > "${formula_manifest}"
if validate_brew_formula_manifest "${formula_manifest}"; then
    fail "Duplicate normalized Formula entries must fail preflight."
fi

trust_manifest="${TEST_TEMP_DIR}/trust.txt"
printf '%s\n' 'tap|owner/repository' > "${trust_manifest}"
if validate_brew_trust_manifest "${trust_manifest}"; then
    fail "Unsupported trust type must fail preflight."
fi

dotfile_manifest="${TEST_TEMP_DIR}/dotfiles.txt"
printf '%s\n' missing-package > "${dotfile_manifest}"
if validate_dotfile_manifest "${dotfile_manifest}"; then
    fail "Missing dotfile package must fail preflight."
fi

SHELL=/bin/unsupported
if validate_login_shell; then
    fail "Unsupported login Shell must fail preflight."
fi

zed_repository="${TEST_TEMP_DIR}/zed"
git init --quiet "${zed_repository}"
git -C "${zed_repository}" remote add origin git@github.com:danshan/zed-config.git
validate_tracking_git_repository_identity_if_present \
    "Zed configuration" "git@github.com:danshan/zed-config.git" "${zed_repository}"
printf '%s\n' dirty > "${zed_repository}/settings.json"
validate_tracking_git_repository_identity_if_present \
    "Zed configuration" "git@github.com:danshan/zed-config.git" "${zed_repository}"
update_git_repository "Zed configuration" "${zed_repository}"
[[ -f "${zed_repository}/settings.json" ]] || fail "Dirty repository content must be preserved."
