#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"
# shellcheck source=defaults/tool_versions.env
source "${PROJECT_ROOT}/defaults/tool_versions.env"

TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/danshan-install-execution.XXXXXX")"
trap 'rm -rf -- "${TEST_TEMP_DIR}"' EXIT
STUB_DIR="${TEST_TEMP_DIR}/bin"
CALL_LOG="${TEST_TEMP_DIR}/calls.log"
mkdir -p -- "${STUB_DIR}"
: > "${CALL_LOG}"

cat > "${STUB_DIR}/brew" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'brew %s\n' "$*" >> "${CALL_LOG}"
case "$*" in
    shellenv)
        printf 'export PATH="%s:$PATH"\n' "$(cd "$(dirname "$0")" && pwd)"
        ;;
    update\ --quiet) ;;
    trust\ --json=v1)
        printf '%s\n' '{"formulae":["daipeihust/tap/im-select"],"casks":["detachhead/tap/rebased","muxy-app/tap/muxy","localsend/localsend/localsend"]}'
        ;;
    list\ --formula\ -1)
        /usr/bin/awk -F/ 'NF && $0 !~ /^#/ { print $NF }' "${PROJECT_UNDER_TEST}/defaults/brew_pkgs.txt"
        ;;
    list\ --cask\ -1)
        /usr/bin/awk -F'|' '$1 !~ /^#/ && $1 != "" { count=split($1, parts, "/"); print parts[count] }' \
            "${PROJECT_UNDER_TEST}/defaults/brew_casks.txt"
        ;;
    outdated\ --quiet\ --formula|outdated\ --quiet\ --cask) ;;
    *)
        printf 'Unexpected brew invocation: %s\n' "$*" >&2
        exit 90
        ;;
esac
STUB

cat > "${STUB_DIR}/sw_vers" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == -productVersion ]]
printf '%s\n' '26.0'
STUB

cat > "${STUB_DIR}/git" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'git %s\n' "$*" >> "${CALL_LOG}"
if [[ "${1:-}" == -C ]]; then
    repository_path="$2"
    shift 2
    case "$*" in
        'rev-parse --is-inside-work-tree') printf '%s\n' true ;;
        'remote get-url origin') sed -n '1p' "${repository_path}/.origin" ;;
        'status --porcelain') ;;
        'rev-parse HEAD') sed -n '1p' "${repository_path}/.head" ;;
        *) printf 'Unexpected git -C invocation: %s\n' "$*" >&2; exit 91 ;;
    esac
    exit
fi
if [[ "${1:-}" == clone ]]; then
    previous=""
    for argument in "$@"; do
        destination="${argument}"
        if [[ -n "${previous}" ]]; then
            repository_url="${previous}"
        fi
        previous="${argument}"
    done
    mkdir -p -- "${destination}/.git"
    printf '%s\n' "${repository_url}" > "${destination}/.origin"
    case "${repository_url}" in
        *ohmyzsh*) printf '%s\n' "${OH_MY_ZSH_REF}" > "${destination}/.head" ;;
        *gpakosz*)
            printf '%s\n' "${OH_MY_TMUX_REF}" > "${destination}/.head"
            : > "${destination}/.tmux.conf"
            ;;
        *) printf '%s\n' tracking > "${destination}/.head" ;;
    esac
    exit
fi
printf 'Unexpected git invocation: %s\n' "$*" >&2
exit 92
STUB

cat > "${STUB_DIR}/stow" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'stow %s\n' "$*" >> "${CALL_LOG}"
dotfiles_dir=""
target_dir=""
package_name=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dir) dotfiles_dir="$2"; shift 2 ;;
        --target) target_dir="$2"; shift 2 ;;
        --*) shift ;;
        *) package_name="$1"; shift ;;
    esac
done
if [[ "${DANSHAN_MODE}" == apply && "${package_name}" == mise ]]; then
    mkdir -p -- "${target_dir}/.config/mise"
    ln -s "${dotfiles_dir}/mise/.config/mise/config.toml" \
        "${target_dir}/.config/mise/config.toml"
    ln -s "${dotfiles_dir}/mise/.config/mise/mise.lock" \
        "${target_dir}/.config/mise/mise.lock"
fi
STUB

cat > "${STUB_DIR}/mise" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'mise %s\n' "$*" >> "${CALL_LOG}"
case "$*" in
    'install --yes'|'install --dry-run-code'|'install --dry-run') ;;
    'ls --current') printf '%s\n' 'All configured tools are current.' ;;
    *) printf 'Unexpected mise invocation: %s\n' "$*" >&2; exit 93 ;;
esac
STUB

chmod +x "${STUB_DIR}/brew" "${STUB_DIR}/sw_vers" "${STUB_DIR}/git" \
    "${STUB_DIR}/stow" "${STUB_DIR}/mise"
export CALL_LOG PROJECT_UNDER_TEST="${PROJECT_ROOT}" OH_MY_ZSH_REF OH_MY_TMUX_REF

APPLY_HOME="${TEST_TEMP_DIR}/apply-home"
PLAN_HOME="${TEST_TEMP_DIR}/plan-home"
mkdir -p -- "${APPLY_HOME}/.config/mise" "${PLAN_HOME}"
printf '%s\n' \
    '[tools]' \
    'bun = "1.3.14"' \
    'java = "zulu-17.66.19.0"' \
    'maven = "3.9.9"' \
    'node = "24.18.0"' \
    'python = "3.12.12"' \
    > "${APPLY_HOME}/.config/mise/config.toml"
apply_output="${TEST_TEMP_DIR}/apply.log"
plan_output="${TEST_TEMP_DIR}/plan.log"

if ! HOME="${APPLY_HOME}" SHELL=/bin/zsh PATH="${STUB_DIR}:/usr/bin:/bin" \
    /bin/bash "${PROJECT_ROOT}/install.sh" apply --no-color > "${apply_output}" 2>&1; then
    sed -n '1,240p' "${apply_output}" >&2
    fail "Full isolated apply failed."
fi

assert_contains 'danshan.env installation complete.' "${apply_output}" "Full apply completion"
assert_contains 'Bootstrap Stage complete: devenv' "${apply_output}" "Final stage completion"
assert_contains 'brew update --quiet' "${CALL_LOG}" "Single Homebrew metadata refresh"
assert_contains 'mise install --yes' "${CALL_LOG}" "Mise apply"
assert_contains 'mise install --dry-run-code' "${CALL_LOG}" "Mise convergence verification"
assert_not_contains 'brew install ' "${CALL_LOG}" "Current Homebrew resources"
[[ -L "${APPLY_HOME}/.config/mise/config.toml" ]] || fail "Mise global config was not installed."
[[ -L "${APPLY_HOME}/.config/mise/mise.lock" ]] || fail "Mise lockfile was not installed."
stow_backup="$(find "${APPLY_HOME}/Library/Application Support/danshan.env/dotfile-backups" \
    -mindepth 1 -maxdepth 1 -type d -print -quit)"
[[ -n "${stow_backup}" ]] || fail "Legacy Mise config snapshot was not retained."
assert_equals completed "$(sed -n '1p' "${stow_backup}/state")" \
    "Legacy Mise config migration state"
assert_contains 'bun = "1.3.14"' \
    "${stow_backup}/originals/.config/mise/config.toml" \
    "Legacy Mise config snapshot"

: > "${CALL_LOG}"
if ! HOME="${PLAN_HOME}" SHELL=/bin/zsh PATH="${STUB_DIR}:/usr/bin:/bin" \
    /bin/bash "${PROJECT_ROOT}/install.sh" plan --no-color > "${plan_output}" 2>&1; then
    sed -n '1,240p' "${plan_output}" >&2
    fail "Full isolated plan failed."
fi

assert_contains 'plan complete; no managed state was changed.' "${plan_output}" "Plan completion"
assert_contains 'mise install --dry-run' "${CALL_LOG}" "Mise plan"
assert_not_contains 'brew update --quiet' "${CALL_LOG}" "Plan metadata mutation"
[[ ! -e "${PLAN_HOME}/.bin" ]] || fail "Plan mode created the base directory."
[[ ! -e "${PLAN_HOME}/.config/mise/config.toml" ]] || fail "Plan mode installed Mise config."

: > "${CALL_LOG}"
status_output="${TEST_TEMP_DIR}/status.log"
if ! HOME="${PLAN_HOME}" SHELL=/bin/zsh PATH="${STUB_DIR}:/usr/bin:/bin" \
    /bin/bash "${PROJECT_ROOT}/install.sh" status --stage devenv --no-color > "${status_output}" 2>&1; then
    sed -n '1,240p' "${status_output}" >&2
    fail "Isolated status mode failed."
fi
assert_contains 'mise ls --current' "${CALL_LOG}" "Mise status"
assert_not_contains 'brew update' "${CALL_LOG}" "Status metadata mutation"
assert_not_contains 'brew list' "${CALL_LOG}" "Stage selection package inventory"
assert_not_contains 'brew trust' "${CALL_LOG}" "Stage selection trust inventory"
