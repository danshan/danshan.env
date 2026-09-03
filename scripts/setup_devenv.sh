#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_tool_versions

activate_homebrew
require_command mise

log_title "Reconciling mise runtimes."
mise use --global "java@${MISE_JAVA_VERSION}"
mise use --global "maven@${MISE_MAVEN_VERSION}"
mise use --global "node@${MISE_NODE_VERSION}"
mise use --global "python@${MISE_PYTHON_VERSION}"
mise use --global "bun@${MISE_BUN_VERSION}"

eval "$(mise activate bash --shims)"
require_command bun
require_command node
export PATH="${BUN_INSTALL:-${HOME}/.bun}/bin:${PATH}"

BUN_PACKAGES_TO_INSTALL=()

queue_bun_package() {
    local package_name="$1"
    local package_version="$2"
    local package_root="${BUN_INSTALL:-${HOME}/.bun}/install/global/node_modules"
    local package_json="${package_root}/${package_name}/package.json"
    local installed_version=""

    if [[ -f "${package_json}" ]]; then
        installed_version="$(node -e 'const fs = require("fs"); console.log(JSON.parse(fs.readFileSync(process.argv[1], "utf8")).version)' "${package_json}")"
    fi

    if [[ "${installed_version}" == "${package_version}" ]]; then
        log_success "Skipping current global package: ${package_name}@${package_version}"
        return
    fi

    if [[ -n "${installed_version}" ]]; then
        log_info "Queuing global package upgrade: ${package_name}@${installed_version} -> ${package_version}"
    else
        log_info "Queuing missing global package: ${package_name}@${package_version}"
    fi
    BUN_PACKAGES_TO_INSTALL+=("${package_name}@${package_version}")
}

log_title "Reconciling pinned global CLI packages."
queue_bun_package "@openai/codex" "${CODEX_PACKAGE_VERSION}"
queue_bun_package "@google/gemini-cli" "${GEMINI_PACKAGE_VERSION}"
queue_bun_package "@anthropic-ai/claude-code" "${CLAUDE_PACKAGE_VERSION}"
queue_bun_package "opencode-ai" "${OPENCODE_PACKAGE_VERSION}"
queue_bun_package "oh-my-openagent" "${OPENAGENT_PACKAGE_VERSION}"
queue_bun_package "@earendil-works/pi-coding-agent" "${PI_PACKAGE_VERSION}"
queue_bun_package "ctx7" "${CONTEXT7_PACKAGE_VERSION}"
queue_bun_package "@playwright/cli" "${PLAYWRIGHT_CLI_PACKAGE_VERSION}"

if [[ ${#BUN_PACKAGES_TO_INSTALL[@]} -gt 0 ]]; then
    bun add --global "${BUN_PACKAGES_TO_INSTALL[@]}"
else
    log_success "All pinned global CLI packages are current."
fi

for required_package in \
    "@openai/codex@${CODEX_PACKAGE_VERSION}" \
    "@google/gemini-cli@${GEMINI_PACKAGE_VERSION}" \
    "@anthropic-ai/claude-code@${CLAUDE_PACKAGE_VERSION}" \
    "opencode-ai@${OPENCODE_PACKAGE_VERSION}" \
    "oh-my-openagent@${OPENAGENT_PACKAGE_VERSION}" \
    "@earendil-works/pi-coding-agent@${PI_PACKAGE_VERSION}" \
    "ctx7@${CONTEXT7_PACKAGE_VERSION}" \
    "@playwright/cli@${PLAYWRIGHT_CLI_PACKAGE_VERSION}"; do
    package_name="${required_package%@*}"
    if [[ "${required_package}" == @*/*@* ]]; then
        package_name="${required_package%@*}"
    fi
    package_version="${required_package##*@}"
    package_json="${BUN_INSTALL:-${HOME}/.bun}/install/global/node_modules/${package_name}/package.json"
    [[ -f "${package_json}" ]] || die "Global package metadata not found: ${package_name}"
    installed_version="$(node -e 'const fs = require("fs"); console.log(JSON.parse(fs.readFileSync(process.argv[1], "utf8")).version)' "${package_json}")"
    [[ "${installed_version}" == "${package_version}" ]] || die "Unexpected global package version for ${package_name}: ${installed_version}"
done

if [[ "${DANSHAN_RUN_CONTEXT7_SETUP:-0}" == 1 ]]; then
    require_command ctx7
    ctx7 setup
else
    log_notice "Skipping interactive Context7 setup. Set DANSHAN_RUN_CONTEXT7_SETUP=1 to enable it."
fi

log_success "Development environment setup complete."
