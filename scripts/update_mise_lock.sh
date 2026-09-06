#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/core.sh"
source "${SCRIPT_DIR}/mise.sh"
source "${SCRIPT_DIR}/migrations/transaction.sh"
DANSHAN_MODE=lock
require_command mise
lock_bootstrap
repository_mise lock --global --bump --platform macos-arm64,macos-x64 "$@"
