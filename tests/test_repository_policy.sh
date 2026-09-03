#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"

bash -n "${PROJECT_ROOT}/install.sh" "${PROJECT_ROOT}"/scripts/*.sh

while IFS= read -r fish_file; do
    if command -v fish >/dev/null 2>&1; then
        fish -n "${fish_file}"
    fi
done < <(find "${PROJECT_ROOT}/dotfiles/fish" -type f -name '*.fish' -print)

if rg -n 'sky_pat_|/Users/honghao\.shan|@latest' \
    "${PROJECT_ROOT}/install.sh" \
    "${PROJECT_ROOT}/scripts" \
    "${PROJECT_ROOT}/defaults" \
    "${PROJECT_ROOT}/dotfiles"; then
    fail "Forbidden credential, absolute user path, or mutable package reference found."
fi

if rg -n 'curl[^|]*\|[[:space:]]*(sh|bash)' "${PROJECT_ROOT}/scripts"; then
    fail "Direct remote script pipeline found."
fi

if rg -n 'HOMEBREW_NO_REQUIRE_TAP_TRUST|(^|[^[:alnum:]_])brew trust[[:space:]]+[A-Za-z0-9]' \
    "${PROJECT_ROOT}/install.sh" \
    "${PROJECT_ROOT}/scripts"; then
    fail "Broad Homebrew trust bypass found."
fi

while IFS='|' read -r package_type package_name || [[ -n "${package_type}${package_name}" ]]; do
    case "${package_type}" in
        ''|'#'*) continue ;;
        formula|cask) ;;
        *) fail "Invalid Homebrew trust type: ${package_type}" ;;
    esac
    [[ "${package_name}" == */* ]] || fail "Homebrew trust entry is not qualified: ${package_name}"
    case "${package_type}" in
        formula)
            grep -Fqx "${package_name}" "${PROJECT_ROOT}/defaults/brew_pkgs.txt" ||
                fail "Trusted formula is absent from the package manifest: ${package_name}"
            ;;
        cask)
            grep -Fq "${package_name}|" "${PROJECT_ROOT}/defaults/brew_casks.txt" ||
                grep -Fqx "${package_name}" "${PROJECT_ROOT}/defaults/brew_casks.txt" ||
                fail "Trusted cask is absent from the package manifest: ${package_name}"
            ;;
    esac
done < "${PROJECT_ROOT}/defaults/brew_trust.txt"

while IFS= read -r package_name || [[ -n "${package_name}" ]]; do
    case "${package_name}" in
        ''|'#'*) continue ;;
        */*) ;;
        *) continue ;;
    esac
    grep -Fqx "formula|${package_name}" "${PROJECT_ROOT}/defaults/brew_trust.txt" ||
        fail "Tap-qualified formula lacks explicit trust: ${package_name}"
done < "${PROJECT_ROOT}/defaults/brew_pkgs.txt"

while IFS='|' read -r package_name _application_name || [[ -n "${package_name}" ]]; do
    case "${package_name}" in
        ''|'#'*) continue ;;
        */*) ;;
        *) continue ;;
    esac
    grep -Fqx "cask|${package_name}" "${PROJECT_ROOT}/defaults/brew_trust.txt" ||
        fail "Tap-qualified cask lacks explicit trust: ${package_name}"
done < "${PROJECT_ROOT}/defaults/brew_casks.txt"

grep -Fqx 'localsend/localsend/localsend|LocalSend' "${PROJECT_ROOT}/defaults/brew_casks.txt" ||
    fail "LocalSend must be classified as a cask."
if grep -Fqx 'localsend/localsend/localsend' "${PROJECT_ROOT}/defaults/brew_pkgs.txt"; then
    fail "LocalSend must not be classified as a formula."
fi

trust_stage_line="$(grep -n 'setup_brew_trust.sh' "${PROJECT_ROOT}/install.sh" | cut -d: -f1)"
formula_stage_line="$(grep -n 'install_brew_pkgs.sh' "${PROJECT_ROOT}/install.sh" | cut -d: -f1)"
cask_stage_line="$(grep -n 'install_brew_casks.sh' "${PROJECT_ROOT}/install.sh" | cut -d: -f1)"
[[ "${trust_stage_line}" -lt "${formula_stage_line}" ]] || fail "Trust stage must precede formula inventory."
[[ "${trust_stage_line}" -lt "${cask_stage_line}" ]] || fail "Trust stage must precede cask inventory."
