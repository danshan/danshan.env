#!/usr/bin/env bash

repository_mise() (
    local setting
    # Keep registry credentials/proxies, but exclude caller-controlled Mise settings.
    for setting in ${!MISE_@} ${!__MISE_@}; do unset "${setting}"; done
    export MISE_GLOBAL_CONFIG_FILE="${DOTFILES_DIR}/mise/.config/mise/config.toml"
    export MISE_SYSTEM_CONFIG_FILE="${PROJECT_ROOT}/config/mise-system.toml"
    export MISE_CEILING_PATHS="${PROJECT_ROOT}"
    export MISE_AUTO_ENV=false
    export MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=""
    export MISE_AUTO_INSTALL=false
    export MISE_AUTO_UPDATE=false
    if is_read_only_mode; then export MISE_OFFLINE=true; fi
    mise --cd "${PROJECT_ROOT}" "$@"
)

verify_mise_deployment() {
    local name target
    for name in config.toml mise.lock; do
        target="${HOME}/.config/mise/${name}"
        [[ "$(resolve_file_path "${target}")" == "${DOTFILES_DIR}/mise/.config/mise/${name}" ]] || {
            die "Mise deployment differs from repository state: ${target}; run the dotfiles stage."
            return 1
        }
    done
}

validate_mise_policy() {
    local tool policy seen="|"
    validate_table_file "${PROJECT_ROOT}/config/mise-policy.tsv" '\t' 2 || return 1
    while IFS=$'\t' read -r tool policy || [[ -n "${tool}${policy}" ]]; do
        case "${tool}" in ''|'#'*) continue ;; esac
        [[ "${tool}" =~ ^[a-zA-Z0-9][a-zA-Z0-9:@_./+-]*$ ]] || {
            die "Invalid Mise policy tool: ${tool}"; return 1
        }
        case "${policy}" in latest|installed) ;; *) die "Invalid Mise update policy: ${policy}"; return 1 ;; esac
        [[ "${seen}" != *"|${tool}|"* ]] || { die "Duplicate Mise policy tool: ${tool}"; return 1; }
        seen="${seen}${tool}|"
    done < "${PROJECT_ROOT}/config/mise-policy.tsv"
}

verify_mise_policy_tools() {
    local inventory
    validate_mise_policy || return 1
    inventory="$(repository_mise ls --current --json)" || return 1
    printf '%s\n' "${inventory}" | /usr/bin/perl -MJSON::PP -e '
        use strict;
        use warnings;
        my $tools = decode_json(do { local $/; <STDIN> });
        die "Invalid Mise inventory: expected a JSON object\n" unless ref($tools) eq "HASH";
        open my $policy, "<", $ARGV[0] or die "Cannot read Mise policy: $!\n";
        while (<$policy>) {
            next if /^#/ || /^\s*$/;
            my ($tool) = split /\t/;
            die "Mise policy tool is not declared in repository config: $tool\n"
                unless exists $tools->{$tool};
        }
    ' "${PROJECT_ROOT}/config/mise-policy.tsv"
}

refresh_mise_lock() {
    repository_mise lock --global --bump --platform macos-arm64,macos-x64 "$@"
}

refresh_mise_latest() {
    local tool policy
    local tools=()
    while IFS=$'\t' read -r tool policy || [[ -n "${tool}${policy}" ]]; do
        case "${tool}" in ''|'#'*) continue ;; esac
        [[ "${policy}" != latest ]] || tools+=("${tool}")
    done < "${PROJECT_ROOT}/config/mise-policy.tsv"
    # An empty tool list would refresh every declaration, including install-only tools.
    [[ "${#tools[@]}" -gt 0 ]] || return 0
    refresh_mise_lock "${tools[@]}"
}

apply_mise() {
    activate_homebrew || return 1
    require_command mise || return 1
    verify_mise_deployment || return 1
    verify_mise_policy_tools || return 1
    refresh_mise_latest || return 1
    repository_mise install --yes || return 1
    repository_mise install --dry-run-code
}

check_mise() {
    if ! command -v mise >/dev/null 2>&1; then
        log_notice "UNKNOWN: Mise is missing; development tool state cannot be inspected."
        return 1
    fi
    local failed=0
    verify_mise_deployment || failed=1
    verify_mise_policy_tools || failed=1
    repository_mise ls --current || failed=1
    repository_mise install --dry-run-code || failed=1
    return "${failed}"
}
