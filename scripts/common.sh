#!/usr/bin/env bash

if [[ -n "${DANSHAN_COMMON_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly DANSHAN_COMMON_LOADED=1

COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${COMMON_SCRIPT_DIR}/.." && pwd)"
readonly DOTFILES_DIR="${PROJECT_ROOT}/dotfiles"

readonly COLOR_TITLE=$'\033[1;36m'
readonly COLOR_SUBTITLE=$'\033[1;33m'
readonly COLOR_SUCCESS=$'\033[0;32m'
readonly COLOR_INFO=$'\033[0;34m'
readonly COLOR_ERROR=$'\033[0;31m'
readonly COLOR_RESET=$'\033[0m'

log_title() {
    printf '%b%s%b\n' "${COLOR_TITLE}" "$1" "${COLOR_RESET}"
}

log_notice() {
    printf '%b%s%b\n' "${COLOR_SUBTITLE}" "$1" "${COLOR_RESET}"
}

log_info() {
    printf '%b%s%b\n' "${COLOR_INFO}" "$1" "${COLOR_RESET}"
}

log_success() {
    printf '%b%s%b\n' "${COLOR_SUCCESS}" "$1" "${COLOR_RESET}"
}

die() {
    printf '%bERROR: %s%b\n' "${COLOR_ERROR}" "$1" "${COLOR_RESET}" >&2
    return 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

activate_homebrew() {
    local brew_executable

    if command -v brew >/dev/null 2>&1; then
        brew_executable="$(command -v brew)"
    elif [[ -x /opt/homebrew/bin/brew ]]; then
        brew_executable=/opt/homebrew/bin/brew
    elif [[ -x /usr/local/bin/brew ]]; then
        brew_executable=/usr/local/bin/brew
    elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        brew_executable=/home/linuxbrew/.linuxbrew/bin/brew
    else
        die "Homebrew is not installed or cannot be located."
        return 1
    fi

    eval "$(env SHELL=/bin/bash "${brew_executable}" shellenv)"
    require_command brew
}

normalize_brew_name() {
    local package_name="${1##*/}"
    printf '%s\n' "${package_name}" | tr '[:upper:]' '[:lower:]'
}

array_contains() {
    local expected="$1"
    local item
    shift

    for item in "$@"; do
        if [[ "${item}" == "${expected}" ]]; then
            return 0
        fi
    done
    return 1
}

BREW_INSTALLED_ITEMS=()
BREW_OUTDATED_ITEMS=()
BREW_INSTALLED_COUNT=0
BREW_UPGRADED_COUNT=0
BREW_SKIPPED_COUNT=0
BREW_TRUSTED_FORMULAE=()
BREW_TRUSTED_CASKS=()
BREW_TRUST_ADDED_COUNT=0
BREW_TRUST_SKIPPED_COUNT=0

normalize_brew_trust_name() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

load_brew_trust_state() {
    local trust_file
    local formula_count
    local cask_count
    local index
    local item

    require_command plutil
    trust_file="$(mktemp "${TMPDIR:-/tmp}/danshan-brew-trust.XXXXXX")"
    if ! brew trust --json=v1 > "${trust_file}"; then
        rm -f -- "${trust_file}"
        die "Failed to read Homebrew trust state."
        return 1
    fi

    if ! formula_count="$(plutil -extract formulae raw -o - "${trust_file}")" ||
        ! cask_count="$(plutil -extract casks raw -o - "${trust_file}")"; then
        rm -f -- "${trust_file}"
        die "Failed to parse Homebrew trust state."
        return 1
    fi

    BREW_TRUSTED_FORMULAE=()
    BREW_TRUSTED_CASKS=()
    BREW_TRUST_ADDED_COUNT=0
    BREW_TRUST_SKIPPED_COUNT=0

    index=0
    while [[ "${index}" -lt "${formula_count}" ]]; do
        if ! item="$(plutil -extract "formulae.${index}" raw -o - "${trust_file}")"; then
            rm -f -- "${trust_file}"
            die "Failed to parse trusted Homebrew formulae."
            return 1
        fi
        BREW_TRUSTED_FORMULAE+=("$(normalize_brew_trust_name "${item}")")
        index=$((index + 1))
    done

    index=0
    while [[ "${index}" -lt "${cask_count}" ]]; do
        if ! item="$(plutil -extract "casks.${index}" raw -o - "${trust_file}")"; then
            rm -f -- "${trust_file}"
            die "Failed to parse trusted Homebrew casks."
            return 1
        fi
        BREW_TRUSTED_CASKS+=("$(normalize_brew_trust_name "${item}")")
        index=$((index + 1))
    done

    rm -f -- "${trust_file}"
}

reconcile_brew_trust() {
    local package_type="$1"
    local package_name="$2"
    local normalized_name
    normalized_name="$(normalize_brew_trust_name "${package_name}")"

    case "${package_type}" in
        formula)
            if array_contains "${normalized_name}" "${BREW_TRUSTED_FORMULAE[@]}"; then
                log_success "Skipping trusted formula: ${package_name}"
                BREW_TRUST_SKIPPED_COUNT=$((BREW_TRUST_SKIPPED_COUNT + 1))
                return
            fi
            ;;
        cask)
            if array_contains "${normalized_name}" "${BREW_TRUSTED_CASKS[@]}"; then
                log_success "Skipping trusted cask: ${package_name}"
                BREW_TRUST_SKIPPED_COUNT=$((BREW_TRUST_SKIPPED_COUNT + 1))
                return
            fi
            ;;
        *)
            die "Unsupported Homebrew trust type: ${package_type}"
            return 1
            ;;
    esac

    log_info "Trusting explicit ${package_type}: ${package_name}"
    if ! brew trust "--${package_type}" "${package_name}" </dev/null; then
        die "Failed to trust Homebrew ${package_type}: ${package_name}"
        return 1
    fi
    BREW_TRUST_ADDED_COUNT=$((BREW_TRUST_ADDED_COUNT + 1))
}

print_brew_trust_summary() {
    log_success "Homebrew trust summary: added=${BREW_TRUST_ADDED_COUNT}, skipped=${BREW_TRUST_SKIPPED_COUNT}"
}

load_brew_state() {
    local package_type="$1"
    local installed_output
    local outdated_output
    local item

    installed_output="$(brew list "--${package_type}" -1)" || die "Failed to list installed ${package_type} packages."
    outdated_output="$(brew outdated --quiet "--${package_type}")" || die "Failed to list outdated ${package_type} packages."

    BREW_INSTALLED_ITEMS=()
    BREW_OUTDATED_ITEMS=()
    BREW_INSTALLED_COUNT=0
    BREW_UPGRADED_COUNT=0
    BREW_SKIPPED_COUNT=0
    while IFS= read -r item; do
        [[ -n "${item}" ]] && BREW_INSTALLED_ITEMS+=("$(normalize_brew_name "${item}")")
    done <<< "${installed_output}"
    while IFS= read -r item; do
        [[ -n "${item}" ]] && BREW_OUTDATED_ITEMS+=("$(normalize_brew_name "${item}")")
    done <<< "${outdated_output}"
}

reconcile_brew_package() {
    local package_type="$1"
    local package_name="$2"
    local application_name="${3:-}"
    local normalized_name
    normalized_name="$(normalize_brew_name "${package_name}")"

    if ! array_contains "${normalized_name}" "${BREW_INSTALLED_ITEMS[@]}"; then
        log_info "Installing missing ${package_type}: ${package_name}"
        if [[ "${package_type}" == cask ]]; then
            if [[ -n "${application_name}" ]]; then
                brew install --quiet --cask --adopt "${package_name}" </dev/null
            else
                brew install --quiet --cask "${package_name}" </dev/null
            fi
        else
            brew install --quiet "${package_name}" </dev/null
        fi
        BREW_INSTALLED_COUNT=$((BREW_INSTALLED_COUNT + 1))
        return
    fi

    if array_contains "${normalized_name}" "${BREW_OUTDATED_ITEMS[@]}"; then
        log_info "Upgrading outdated ${package_type}: ${package_name}"
        if [[ "${package_type}" == cask ]]; then
            brew upgrade --quiet --cask "${package_name}" </dev/null
        else
            brew upgrade --quiet "${package_name}" </dev/null
        fi
        BREW_UPGRADED_COUNT=$((BREW_UPGRADED_COUNT + 1))
        return
    fi

    log_success "Skipping current ${package_type}: ${package_name}"
    BREW_SKIPPED_COUNT=$((BREW_SKIPPED_COUNT + 1))
}

print_brew_summary() {
    local package_type="$1"
    log_success "${package_type} summary: installed=${BREW_INSTALLED_COUNT}, upgraded=${BREW_UPGRADED_COUNT}, skipped=${BREW_SKIPPED_COUNT}"
}

load_tool_versions() {
    local version_file="${PROJECT_ROOT}/defaults/tool_versions.env"
    [[ -f "${version_file}" ]] || die "Tool version manifest not found: ${version_file}"
    # shellcheck disable=SC1090
    source "${version_file}"
}

git_worktree_is_clean() {
    local repository_path="$1"
    [[ -z "$(git -C "${repository_path}" status --porcelain)" ]]
}

ensure_pinned_git_repository() {
    local repository_name="$1"
    local repository_url="$2"
    local repository_path="$3"
    local repository_ref="$4"
    local actual_url
    local current_ref

    if [[ ! -e "${repository_path}" ]]; then
        log_info "Cloning ${repository_name} at pinned revision ${repository_ref}."
        git clone --filter=blob:none "${repository_url}" "${repository_path}"
    fi

    git -C "${repository_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        die "Existing path is not a Git worktree: ${repository_path}"
        return 1
    }
    actual_url="$(git -C "${repository_path}" remote get-url origin)"
    if [[ "${actual_url}" != "${repository_url}" ]]; then
        die "Unexpected origin for ${repository_name}: ${actual_url}"
        return 1
    fi

    if ! git_worktree_is_clean "${repository_path}"; then
        die "Refusing to update dirty Git worktree: ${repository_path}"
        return 1
    fi

    current_ref="$(git -C "${repository_path}" rev-parse HEAD 2>/dev/null || true)"
    if [[ "${current_ref}" == "${repository_ref}" ]]; then
        log_success "Skipping current ${repository_name}: ${repository_ref}"
        return
    fi

    log_info "Updating ${repository_name} to pinned revision ${repository_ref}."
    git -C "${repository_path}" fetch --depth=1 origin "${repository_ref}"
    git -C "${repository_path}" checkout --detach "${repository_ref}"
}

update_git_repository() {
    local repository_name="$1"
    local repository_path="$2"

    git -C "${repository_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        die "Existing path is not a Git worktree: ${repository_path}"
        return 1
    }

    log_info "Fast-forwarding ${repository_name}."
    git -C "${repository_path}" pull --ff-only
}

ensure_tracking_git_repository() {
    local repository_name="$1"
    local repository_url="$2"
    local repository_path="$3"
    local actual_url

    if [[ ! -e "${repository_path}" ]]; then
        log_info "Cloning ${repository_name}."
        git clone "${repository_url}" "${repository_path}"
        return
    fi

    git -C "${repository_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        die "Existing path is not a Git worktree: ${repository_path}"
        return 1
    }
    actual_url="$(git -C "${repository_path}" remote get-url origin)"
    if [[ "${actual_url}" != "${repository_url}" ]]; then
        die "Unexpected origin for ${repository_name}: ${actual_url}"
        return 1
    fi

    update_git_repository "${repository_name}" "${repository_path}"
}

ensure_symlink() {
    local source_path="$1"
    local target_path="$2"
    local current_target

    if [[ -L "${target_path}" ]]; then
        current_target="$(readlink "${target_path}")"
        if [[ "${current_target}" == "${source_path}" ]]; then
            log_success "Skipping current symlink: ${target_path}"
            return
        fi
        die "Refusing to replace existing symlink: ${target_path} -> ${current_target}"
        return 1
    fi
    if [[ -e "${target_path}" ]]; then
        die "Refusing to replace existing path: ${target_path}"
        return 1
    fi

    ln -s "${source_path}" "${target_path}"
    log_success "Created symlink: ${target_path}"
}
