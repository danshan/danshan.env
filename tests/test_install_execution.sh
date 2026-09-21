#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
fixture="${TEST_TEMP_DIR}/repository"
mkdir -p "${fixture}" "${HOME}/bin"
cp -R "${PROJECT_ROOT}/scripts" "${PROJECT_ROOT}/config" "${fixture}/"
cp "${PROJECT_ROOT}/install.sh" "${PROJECT_ROOT}/Brewfile" "${fixture}/"
cat > "${fixture}/scripts/shell.sh" <<'STUB'
#!/usr/bin/env bash
apply_shell() {
    [[ "${FAIL_STAGE:-}" != shell ]] || return 3
    touch "${HOME}/shell-registered" "${HOME}/login-shell"
    export SHELL="${HOME}/bin/fish"
}
check_shell() {
    export SHELL="${HOME}/bin/fish"
    [[ -f "${HOME}/shell-registered" && -f "${HOME}/login-shell" ]]
}
STUB
mkdir -p "${fixture}/dotfiles/mise/.config/mise"
cp "${PROJECT_ROOT}/dotfiles/mise/.config/mise/config.toml" "${PROJECT_ROOT}/dotfiles/mise/.config/mise/mise.lock" "${fixture}/dotfiles/mise/.config/mise/"
printf 'mise\tall\n' > "${fixture}/config/dotfiles.tsv"
printf '# No repositories in the integration fixture\n' > "${fixture}/config/repositories.tsv"
printf '# No links in the integration fixture\n' > "${fixture}/config/links.tsv"
printf '# No migrations in the integration fixture\n' > "${fixture}/config/migrations.txt"
cat > "${HOME}/bin/brew" <<'STUB'
#!/usr/bin/env bash
set -eu
case "$1" in
    shellenv) printf 'export PATH="%s/bin:%s"\n' "${HOME}" "${PATH}" ;;
    update) [[ "${FAIL_STAGE:-}" != homebrew ]] ;;
    bundle)
        if [[ "$2" == install ]]; then touch "${HOME}/brew-installed";
        elif [[ "$2" == check ]]; then [[ -f "${HOME}/brew-installed" ]]; fi ;;
    *) exit 93 ;;
esac
STUB
cat > "${HOME}/bin/stow" <<'STUB'
#!/usr/bin/env bash
set -eu
[[ "${FAIL_STAGE:-}" != dotfiles ]] || exit 4
if [[ "$*" == *--simulate* ]]; then
    [[ -L "${HOME}/.config/mise" ]] || printf 'LINK: .config/mise => repository\n' >&2
    exit 0
fi
[[ -f "${HOME}/login-shell" ]] || exit 6
mkdir -p "${HOME}/.config"
[[ -L "${HOME}/.config/mise" ]] || ln -s "$2/mise/.config/mise" "${HOME}/.config/mise"
STUB
cat > "${HOME}/bin/mise" <<'STUB'
#!/usr/bin/env bash
set -eu
[[ "${FAIL_STAGE:-}" != mise ]] || exit 5
case "$*" in
    *'ls --current --json')
        printf '{"java":[],"maven":[],"node":[],"python":[],"bun":[],"aqua:astral-sh/uv":[],"npm:@openai/codex":[],"npm:@google/gemini-cli":[],"npm:@anthropic-ai/claude-code":[],"npm:opencode-ai":[],"npm:oh-my-openagent":[],"npm:@earendil-works/pi-coding-agent":[],"npm:ctx7":[],"npm:@playwright/cli":[],"npm:agent-browser":[]}\n' ;;
    *'lock --global --bump --platform '*) touch "${HOME}/mise-refreshed" ;;
    *'install --yes') touch "${HOME}/mise-installed" ;;
    *'install --dry-run-code') [[ -f "${HOME}/mise-installed" ]] ;;
    *'ls --current') ;;
    *) exit 94 ;;
esac
STUB
cat > "${HOME}/bin/fish" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "${HOME}/bin/"*
export PATH="${HOME}/bin:/usr/bin:/bin:/usr/sbin:/sbin" SHELL=/bin/bash
export GIT_CONFIG_NOSYSTEM=1
output="${TEST_TEMP_DIR}/output"
expect_failure /bin/bash "${fixture}/install.sh" check > "${output}" 2>&1
[[ ! -e "${HOME}/Library" && ! -e "${HOME}/brew-installed" && ! -e "${HOME}/mise-installed" ]] || fail 'Fresh check mutated HOME.'
assert_contains 'check: mise' "${output}" 'Check must continue through unmet stages'
/bin/bash "${fixture}/install.sh" apply > "${output}" 2>&1
assert_contains 'Bootstrap apply complete.' "${output}" 'Complete apply'
assert_contains 'apply: shell' "${output}" 'Shell stage runs before Shell configuration'
[[ -f "${HOME}/login-shell" && -f "${HOME}/shell-registered" ]] || fail 'Apply did not configure the default login Shell.'
/bin/bash "${fixture}/install.sh" apply > "${output}" 2>&1
before="$(find "${HOME}" -type f -exec shasum {} \; | sort)"
/bin/bash "${fixture}/install.sh" check > "${output}" 2>&1
assert_equals "${before}" "$(find "${HOME}" -type f -exec shasum {} \; | sort)" 'Check preserves all HOME files'
/bin/bash "${fixture}/install.sh" apply --stage mise > "${output}" 2>&1
assert_not_contains 'apply: homebrew' "${output}" 'Selected stage'
/bin/bash "${fixture}/install.sh" apply --from dotfiles > "${output}" 2>&1
assert_not_contains 'apply: repositories' "${output}" 'From skips earlier stages'
assert_contains 'apply: mise' "${output}" 'From includes remaining stages'
for stage in homebrew shell dotfiles mise; do
    export FAIL_STAGE="${stage}"
    expect_failure /bin/bash "${fixture}/install.sh" apply > "${output}" 2>&1
    assert_not_contains 'Bootstrap apply complete.' "${output}" 'Failure cannot report completion'
    assert_contains "Bootstrap failed in ${stage}" "${output}" 'Failure stage propagation'
done
unset FAIL_STAGE
expect_failure /bin/bash "${fixture}/install.sh" apply --stage bad > "${output}" 2>&1
expect_failure /bin/bash "${fixture}/install.sh" migrate --stage mise > "${output}" 2>&1
expect_failure /bin/bash "${fixture}/install.sh" apply --stage mise --from dotfiles > "${output}" 2>&1
# Apply and check must surface pending snapshots without recovering them.
backup="${HOME}/Library/Application Support/danshan.env/app-backups/interrupted"
mkdir -p "${backup}"
printf 'installing\n' > "${backup}/state"
expect_failure /bin/bash "${fixture}/install.sh" apply > "${output}" 2>&1
expect_failure /bin/bash "${fixture}/install.sh" check > "${output}" 2>&1
assert_equals installing "$(cat "${backup}/state")" 'No implicit recovery'
