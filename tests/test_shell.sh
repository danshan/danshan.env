#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
source "${PROJECT_ROOT}/scripts/lib/core.sh"
source "${PROJECT_ROOT}/scripts/shell.sh"

fish_path="${HOME}/bin/fish"
login_shell=/bin/zsh
registered=0
register_failure=0
chsh_failure=0
mkdir -p "${HOME}/bin"
printf '#!/usr/bin/env bash\n' > "${fish_path}"
chmod +x "${fish_path}"

resolve_fish_shell() { printf '%s\n' "${fish_path}"; }
read_login_shell() { printf '%s\n' "${login_shell}"; }
is_registered_login_shell() { [[ "${registered}" -eq 1 && "$1" == "${fish_path}" ]]; }
register_login_shell() {
    [[ "${register_failure}" -eq 0 ]] || return 7
    registered=1
}
change_login_shell() {
    [[ "$1" == "${fish_path}" ]] || return 8
    [[ "${chsh_failure}" -eq 0 ]] || return 9
    login_shell="$1"
}

export SHELL=/bin/zsh
apply_shell
assert_equals 1 "${registered}" 'Apply registers Fish'
assert_equals "${fish_path}" "${login_shell}" 'Apply changes the account login Shell'
assert_equals "${fish_path}" "${SHELL}" 'Apply updates the current Bootstrap environment'

registered=1
login_shell="${fish_path}"
chsh_failure=1
apply_shell

registered=0
login_shell=/bin/zsh
export SHELL=/bin/zsh
expect_failure check_shell
assert_equals "${fish_path}" "${SHELL}" 'Check evaluates downstream desired Fish resources'
assert_equals 0 "${registered}" 'Check does not register Fish'
assert_equals /bin/zsh "${login_shell}" 'Check does not change the account login Shell'

register_failure=1
expect_failure apply_shell
register_failure=0
registered=1
chsh_failure=1
expect_failure apply_shell
