#!/usr/bin/env bash
set -Eeuo pipefail
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == check ]]; then
    exec /usr/bin/sandbox-exec -f "${INSTALL_DIR}/config/check.sb" /bin/bash "${INSTALL_DIR}/scripts/bootstrap.sh" "$@"
fi
exec /bin/bash "${INSTALL_DIR}/scripts/bootstrap.sh" "$@"
