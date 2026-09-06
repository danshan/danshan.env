#!/usr/bin/env bash

source "${PROJECT_ROOT}/scripts/lib/git.sh"

validate_repository_config() {
    validate_table_file "${PROJECT_ROOT}/config/repositories.tsv" '\t' 5 || return 1
    validate_table_file "${PROJECT_ROOT}/config/links.tsv" '\t' 2 || return 1
    local id url target revision shell extra source seen=() seen_ids=() link_targets=()
    while IFS=$'\t' read -r id url target revision shell extra || [[ -n "${id}" ]]; do
        case "${id}" in ''|'#'*) continue ;; *[!a-zA-Z0-9_-]*) die "Invalid repository id: ${id}"; return 1 ;; esac
        [[ -n "${url}" && -z "${extra}" ]] || { die "Invalid repository entry: ${id}"; return 1; }
        validate_relative_path "${target}" || return 1
        case "${url}" in https://*|git@*) ;; *) die "Unsupported Git URL: ${url}"; return 1 ;; esac
        case "${shell}" in all|bash|zsh|fish) ;; *) die "Invalid Shell selector: ${shell}"; return 1 ;; esac
        [[ "${revision}" == tracking || "${revision}" =~ ^[0-9a-f]{40}$ ]] || {
            die "Git revision must be a commit or tracking: ${id}"; return 1
        }
        if [[ "${#seen[@]}" -gt 0 ]] && array_contains "${target}" "${seen[@]}"; then
            die "Duplicate Git target: ${target}"; return 1
        fi
        if [[ "${#seen_ids[@]}" -gt 0 ]] && array_contains "${id}" "${seen_ids[@]}"; then
            die "Duplicate Git repository id: ${id}"; return 1
        fi
        seen_ids+=("${id}")
        seen+=("${target}")
        shell_matches "${shell}" || continue
        validate_tracking_git_repository_identity_if_present "${id}" "${url}" "${HOME}/${target}" || return 1
    done < "${PROJECT_ROOT}/config/repositories.tsv"
    while IFS=$'\t' read -r source target extra || [[ -n "${source}" ]]; do
        case "${source}" in ''|'#'*) continue ;; esac
        validate_relative_path "${source}" && validate_relative_path "${target}" || return 1
        [[ -z "${extra}" ]] || { die "Unexpected link field: ${source}"; return 1; }
        if [[ "${#link_targets[@]}" -gt 0 ]] && array_contains "${target}" "${link_targets[@]}"; then
            die "Duplicate link target: ${target}"; return 1
        fi
        link_targets+=("${target}")
    done < "${PROJECT_ROOT}/config/links.tsv"
}

reconcile_repositories() {
    local id url target revision shell extra source failed=0
    while IFS=$'\t' read -r id url target revision shell extra || [[ -n "${id}" ]]; do
        case "${id}" in ''|'#'*) continue ;; esac
        shell_matches "${shell}" || continue
        if [[ "${revision}" == tracking ]]; then
            ensure_tracking_git_repository "${id}" "${url}" "${HOME}/${target}" || failed=1
        else
            ensure_pinned_git_repository "${id}" "${url}" "${HOME}/${target}" "${revision}" || failed=1
        fi
        if [[ "${failed}" -ne 0 ]] && ! is_read_only_mode; then return 1; fi
    done < "${PROJECT_ROOT}/config/repositories.tsv"
    while IFS=$'\t' read -r source target extra || [[ -n "${source}" ]]; do
        case "${source}" in ''|'#'*) continue ;; esac
        ensure_symlink "${HOME}/${source}" "${HOME}/${target}" || failed=1
        if [[ "${failed}" -ne 0 ]] && ! is_read_only_mode; then return 1; fi
    done < "${PROJECT_ROOT}/config/links.tsv"
    return "${failed}"
}

apply_repositories() { reconcile_repositories; }
check_repositories() { reconcile_repositories; }
