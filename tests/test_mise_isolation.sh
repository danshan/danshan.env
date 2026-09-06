#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
command -v mise >/dev/null || fail 'Mise is required for configuration isolation verification.'
fixture="${HOME}/parent/repository"
mkdir -p "${fixture}/scripts/lib" "${fixture}/config" "${fixture}/dotfiles/mise/.config/mise" "${HOME}/.config/mise/conf.d"
cp "${PROJECT_ROOT}/scripts/lib/core.sh" "${fixture}/scripts/lib/core.sh"
cp "${PROJECT_ROOT}/scripts/mise.sh" "${fixture}/scripts/mise.sh"
printf '# Repository global config\n' > "${fixture}/dotfiles/mise/.config/mise/config.toml"
cp "${PROJECT_ROOT}/config/mise-system.toml" "${fixture}/config/mise-system.toml"
cp "${PROJECT_ROOT}/config/check.sb" "${fixture}/config/check.sb"
for path in "${HOME}/.config/mise/config.toml" "${HOME}/.config/mise/conf.d/extra.toml" "${HOME}/.miserc.toml" "${fixture}/mise.toml" "${fixture}/.miserc.toml" "${HOME}/parent/mise.toml" "${HOME}/host.toml"; do
    printf '[tools]\nunrelated-test-tool = "1"\n' > "${path}"
done
export MISE_CONFIG_FILE="${HOME}/host.toml" MISE_ENV=host MISE_SYSTEM_CONFIG_FILE="${HOME}/host.toml" MISE_GLOBAL_CONFIG_FILE="${HOME}/host.toml"
export MISE_OVERRIDE_CONFIG_FILENAMES=host.toml
source "${fixture}/scripts/lib/core.sh"
source "${fixture}/scripts/mise.sh"
DANSHAN_MODE=check
before="$(find "${HOME}" -type f -exec shasum {} \; | sort)"
output="$(/usr/bin/sandbox-exec -f "${PROJECT_ROOT}/config/check.sb" /bin/bash -c '
    source "$1/scripts/lib/core.sh"
    source "$1/scripts/mise.sh"
    DANSHAN_MODE=check
    repository_mise config ls --json
' bash "${PROJECT_ROOT}")"
[[ "${output}" != *unrelated-test-tool* ]] || fail 'Mise loaded caller or local tools.'
[[ "${output}" == *dotfiles/mise/.config/mise/config.toml* ]] || fail 'Repository config missing.'
[[ "${before}" == "$(find "${HOME}" -type f -exec shasum {} \; | sort)" ]] || fail 'Mise check wrote files.'
# Stow directory folding must still count as the exact repository deployment.
printf '# Lock\n' > "${DOTFILES_DIR}/mise/.config/mise/mise.lock"
rm -rf "${HOME}/.config/mise"
ln -s "${DOTFILES_DIR}/mise/.config/mise" "${HOME}/.config/mise"
verify_mise_deployment
