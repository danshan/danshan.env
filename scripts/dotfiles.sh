#!/usr/bin/env bash

validate_dotfile_config() {
    validate_table_file "${PROJECT_ROOT}/config/dotfiles.tsv" '\t' 2 || return 1
    local package shell extra seen=()
    while IFS=$'\t' read -r package shell extra || [[ -n "${package}" ]]; do
        case "${package}" in ''|'#'*) continue ;; esac
        case "${package}" in *[!a-zA-Z0-9_-]*) die "Invalid dotfile package: ${package}"; return 1 ;; esac
        case "${shell}" in all|bash|zsh|fish) ;; *) die "Invalid Shell selector: ${shell}"; return 1 ;; esac
        [[ -z "${extra}" && -d "${DOTFILES_DIR}/${package}" ]] || { die "Invalid dotfile entry: ${package}"; return 1; }
        if [[ "${#seen[@]}" -gt 0 ]] && array_contains "${package}" "${seen[@]}"; then
            die "Duplicate dotfile package: ${package}"; return 1
        fi
        seen+=("${package}")
    done < "${PROJECT_ROOT}/config/dotfiles.tsv"
}

deploy_dotfiles() {
    local mode="$1" package shell extra output failed=0
    if ! command -v stow >/dev/null 2>&1; then
        log_notice "UNKNOWN: Stow is missing; dotfile conflicts cannot be inspected."
        return 1
    fi
    while IFS=$'\t' read -r package shell extra || [[ -n "${package}" ]]; do
        case "${package}" in ''|'#'*) continue ;; esac
        shell_matches "${shell}" || continue
        log_info "${mode}: dotfile package ${package}"
        if [[ "${mode}" == check ]]; then
            if ! output="$(stow --dir "${DOTFILES_DIR}" --target "${HOME}" --stow --simulate --verbose "${package}" 2>&1)"; then
                failed=1
            elif printf '%s\n' "${output}" | grep -E '^(LINK|UNLINK|MKDIR|RMDIR):' >/dev/null; then
                failed=1
            fi
            [[ -z "${output}" ]] || printf '%s\n' "${output}"
        else
            stow --dir "${DOTFILES_DIR}" --target "${HOME}" --restow --verbose "${package}" || {
                die "Dotfile conflict: ${package}. Legacy ownership changes require the migrate command."
                return 1
            }
        fi
    done < "${PROJECT_ROOT}/config/dotfiles.tsv"
    return "${failed}"
}

apply_dotfiles() { deploy_dotfiles apply; }
check_dotfiles() { deploy_dotfiles check; }
