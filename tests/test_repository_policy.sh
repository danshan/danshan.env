#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"

bash -n "${PROJECT_ROOT}/install.sh" "${PROJECT_ROOT}"/scripts/*.sh "${PROJECT_ROOT}"/scripts/lib/*.sh

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

if rg -n 'brew (install|upgrade).*--force' "${PROJECT_ROOT}/scripts"; then
    fail "Homebrew force installation bypass found."
fi

if rg -n '(bun add|npm install).*(--global|-g)' "${PROJECT_ROOT}/scripts"; then
    fail "Direct Bun or NPM global package ownership found."
fi

for mise_owned_formula in yarn starship uv agent-browser; do
    if grep -Fqx "${mise_owned_formula}" "${PROJECT_ROOT}/defaults/brew_pkgs.txt"; then
        fail "Mise-owned tool remains in the Homebrew manifest: ${mise_owned_formula}"
    fi
done

if grep -Fqx 1password-cli "${PROJECT_ROOT}/defaults/brew_pkgs.txt"; then
    fail "Cask-only package remains in the Homebrew Formula manifest: 1password-cli"
fi
grep -Fqx 1password-cli "${PROJECT_ROOT}/defaults/brew_casks.txt" ||
    fail "Missing Homebrew Cask package: 1password-cli"

for mise_tool in \
    '"aqua:astral-sh/uv" = "0.12.10"' \
    '"aqua:starship/starship" = "1.26.0"' \
    '"npm:@openai/codex" = "0.153.0"' \
    '"npm:oh-my-openagent" = { version = "4.19.1", trust_policy_excludes = ["effect@4.0.0-beta.66"] }' \
    '"npm:agent-browser" = "0.36.0"'; do
    grep -Fqx "${mise_tool}" "${PROJECT_ROOT}/dotfiles/mise/.config/mise/config.toml" ||
        fail "Missing pinned Mise tool: ${mise_tool}"
done

if rg -n 'trust_policy_excludes = \["effect"\]' \
    "${PROJECT_ROOT}/dotfiles/mise/.config/mise/config.toml"; then
    fail "Unbounded Mise NPM trust-policy exception found."
fi

[[ -f "${PROJECT_ROOT}/dotfiles/mise/.config/mise/mise.lock" ]] ||
    fail "Missing Mise lockfile."
if rg -n 'eval echo -- \$token' "${PROJECT_ROOT}/dotfiles/fish"; then
    fail "Fish command-line input is evaluated as code."
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

grep -Fqx 'localsend/localsend/localsend|LocalSend|migrate' "${PROJECT_ROOT}/defaults/brew_casks.txt" ||
    fail "LocalSend must migrate an existing application transactionally."
grep -Fqx 'thaw|Thaw|preserve|26' "${PROJECT_ROOT}/defaults/brew_casks.txt" ||
    fail "Thaw must require macOS 26 or newer."
for font_cask in \
    font-hack-nerd-font \
    font-fira-code-nerd-font \
    font-jetbrains-mono-nerd-font; do
    grep -Fqx "${font_cask}||migrate" "${PROJECT_ROOT}/defaults/brew_casks.txt" ||
        fail "Nerd Font cask must migrate existing artifacts transactionally: ${font_cask}"
done
if grep -Fqx 'localsend/localsend/localsend' "${PROJECT_ROOT}/defaults/brew_pkgs.txt"; then
    fail "LocalSend must not be classified as a formula."
fi

trust_stage_line="$(grep -n 'setup_brew_trust.sh' "${PROJECT_ROOT}/install.sh" | cut -d: -f1)"
formula_stage_line="$(grep -n 'install_brew_pkgs.sh' "${PROJECT_ROOT}/install.sh" | cut -d: -f1)"
cask_stage_line="$(grep -n 'install_brew_casks.sh' "${PROJECT_ROOT}/install.sh" | cut -d: -f1)"
[[ "${trust_stage_line}" -lt "${formula_stage_line}" ]] || fail "Trust stage must precede formula inventory."
[[ "${trust_stage_line}" -lt "${cask_stage_line}" ]] || fail "Trust stage must precede cask inventory."
