#!/usr/bin/env bash

validate_brew_package_name() {
    local package_name="$1"
    local context="$2"

    case "${package_name}" in
        ''|*[!A-Za-z0-9@+._/-]*|/*|*/|*//*|*'..'*)
            die "Invalid ${context} package name: ${package_name:-empty}"
            return 1
            ;;
    esac
}
validate_brew_formula_manifest() {
    local manifest_path="$1"
    local package_name normalized_name
    local seen_items=()

    while IFS= read -r package_name || [[ -n "${package_name}" ]]; do
        case "${package_name}" in
            ''|'#'*) continue ;;
        esac
        validate_brew_package_name "${package_name}" "Homebrew formula" || return 1
        normalized_name="$(normalize_brew_name "${package_name}")"
        if [[ "${#seen_items[@]}" -gt 0 ]] && array_contains "${normalized_name}" "${seen_items[@]}"; then
            die "Duplicate Homebrew formula manifest entry: ${package_name}"
            return 1
        fi
        seen_items+=("${normalized_name}")
    done < "${manifest_path}"
}

validate_brew_trust_manifest() {
    local manifest_path="$1"
    local package_type package_name extra
    local normalized_entry
    local seen_items=()

    while IFS='|' read -r package_type package_name extra ||
        [[ -n "${package_type}${package_name}${extra}" ]]; do
        case "${package_type}" in
            ''|'#'*) continue ;;
            formula|cask) ;;
            *)
                die "Unsupported Homebrew trust type: ${package_type}"
                return 1
                ;;
        esac
        [[ -z "${extra}" ]] || {
            die "Unexpected Homebrew trust manifest field: ${package_type}|${package_name}|${extra}"
            return 1
        }
        validate_brew_package_name "${package_name}" "Homebrew trust" || return 1
        [[ "${package_name}" == */* ]] || {
            die "Homebrew trust package must be tap-qualified: ${package_name}"
            return 1
        }
        normalized_entry="${package_type}|$(normalize_brew_trust_name "${package_name}")"
        if [[ "${#seen_items[@]}" -gt 0 ]] && array_contains "${normalized_entry}" "${seen_items[@]}"; then
            die "Duplicate Homebrew trust manifest entry: ${normalized_entry}"
            return 1
        fi
        seen_items+=("${normalized_entry}")
    done < "${manifest_path}"
}

validate_dotfile_manifest() {
    local manifest_path="$1"
    local package_name
    local seen_items=()

    while IFS= read -r package_name || [[ -n "${package_name}" ]]; do
        case "${package_name}" in
            ''|'#'*) continue ;;
            *[!A-Za-z0-9._-]*)
                die "Invalid dotfile package name: ${package_name}"
                return 1
                ;;
        esac
        [[ -d "${DOTFILES_DIR}/${package_name}" ]] || {
            die "Dotfile package not found: ${package_name}"
            return 1
        }
        if [[ "${#seen_items[@]}" -gt 0 ]] && array_contains "${package_name}" "${seen_items[@]}"; then
            die "Duplicate dotfile package manifest entry: ${package_name}"
            return 1
        fi
        seen_items+=("${package_name}")
    done < "${manifest_path}"
}

validate_login_shell() {
    case "${SHELL:-}" in
        */zsh|*/bash|*/fish) ;;
        *)
            die "Unsupported or unset login shell: ${SHELL:-unset}"
            return 1
            ;;
    esac
}
