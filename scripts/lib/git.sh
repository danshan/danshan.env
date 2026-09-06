#!/usr/bin/env bash

validate_git_worktree() {
    local path="$1" root physical
    [[ -d "${path}" && ! -L "${path}" ]] || { die "Invalid Git directory: ${path}"; return 1; }
    root="$(git -C "${path}" rev-parse --show-toplevel 2>/dev/null)" || { die "Not a Git worktree: ${path}"; return 1; }
    physical="$(cd -P "${path}" && pwd)" || return 1
    [[ "${root}" == "${physical}" ]] || { die "Path is not the Git worktree root: ${path}"; return 1; }
}

git_worktree_is_clean() {
    local repository_path="$1"
    local output
    output="$(git -C "${repository_path}" status --porcelain)" || return 2
    [[ -z "${output}" ]]
}

validate_tracking_git_repository_identity_if_present() {
    local repository_name="$1"
    local repository_url="$2"
    local repository_path="$3"
    local actual_url

    [[ -e "${repository_path}" || -L "${repository_path}" ]] || return 0
    require_command git || return 1
    validate_git_worktree "${repository_path}" || return 1
    actual_url="$(git -C "${repository_path}" remote get-url origin)" || return 1
    [[ "${actual_url}" == "${repository_url}" ]] || {
        die "Unexpected origin for ${repository_name}: ${actual_url}"
        return 1
    }
}

ensure_pinned_git_repository() {
    local repository_name="$1" repository_url="$2" repository_path="$3" repository_ref="$4"
    local actual_url current_ref newly_cloned=0

    if [[ ! -e "${repository_path}" && ! -L "${repository_path}" ]]; then
        if is_read_only_mode; then
            log_planned_action "clone ${repository_name} at pinned revision ${repository_ref}."
            return 1
        fi
        log_info "Cloning ${repository_name} at pinned revision ${repository_ref}."
        git clone --filter=blob:none --no-checkout "${repository_url}" "${repository_path}" || return 1
        newly_cloned=1
    fi
    validate_git_worktree "${repository_path}" || return 1
    actual_url="$(git -C "${repository_path}" remote get-url origin)" || return 1
    [[ "${actual_url}" == "${repository_url}" ]] || {
        die "Unexpected origin for ${repository_name}: ${actual_url}"
        return 1
    }
    if [[ "${newly_cloned}" -eq 0 ]]; then
        git_worktree_is_clean "${repository_path}" || {
            die "Refusing to update dirty or unreadable Git worktree: ${repository_path}"
            return 1
        }
    fi
    current_ref="$(git -C "${repository_path}" rev-parse HEAD)" || return 1
    if [[ "${newly_cloned}" -eq 0 && "${current_ref}" == "${repository_ref}" ]]; then
        log_success "Skipping current ${repository_name}: ${repository_ref}"
        return
    fi
    if is_read_only_mode; then
        log_planned_action "update ${repository_name} to pinned revision ${repository_ref}."
        return 1
    fi
    log_info "Updating ${repository_name} to pinned revision ${repository_ref}."
    git -C "${repository_path}" fetch origin "${repository_ref}" || return 1
    if [[ "${newly_cloned}" -eq 0 ]]; then
        git -C "${repository_path}" merge-base --is-ancestor HEAD "${repository_ref}" || {
            die "Pinned update is not a fast-forward: ${repository_path}"; return 1
        }
    fi
    git -C "${repository_path}" checkout --detach "${repository_ref}" || return 1
    [[ "$(git -C "${repository_path}" rev-parse HEAD)" == "${repository_ref}" ]]
}

update_git_repository() {
    local repository_name="$1" repository_path="$2"
    validate_git_worktree "${repository_path}" || return 1
    local clean_status=0
    git_worktree_is_clean "${repository_path}" || clean_status=$?
    case "${clean_status}" in
        0) ;;
        1) log_notice "Skipping update for dirty Git worktree: ${repository_path}"; return 0 ;;
        *) die "Failed to inspect Git worktree: ${repository_path}"; return 1 ;;
    esac
    if is_read_only_mode; then
        log_notice "Skipping network refresh in ${DANSHAN_MODE} mode: ${repository_name}"
        return
    fi
    log_info "Fast-forwarding ${repository_name}."
    git -C "${repository_path}" pull --ff-only
}

ensure_tracking_git_repository() {
    local repository_name="$1" repository_url="$2" repository_path="$3" actual_url
    if [[ ! -e "${repository_path}" && ! -L "${repository_path}" ]]; then
        if is_read_only_mode; then
            log_planned_action "clone ${repository_name}."
            return 1
        fi
        log_info "Cloning ${repository_name}."
        git clone "${repository_url}" "${repository_path}" || return 1
        return
    fi
    validate_git_worktree "${repository_path}" || return 1
    actual_url="$(git -C "${repository_path}" remote get-url origin)" || return 1
    [[ "${actual_url}" == "${repository_url}" ]] || {
        die "Unexpected origin for ${repository_name}: ${actual_url}"
        return 1
    }
    update_git_repository "${repository_name}" "${repository_path}"
}

ensure_symlink() {
    local source_path="$1" target_path="$2" current_target
    if [[ -L "${target_path}" ]]; then
        current_target="$(readlink "${target_path}")"
        if [[ "${current_target}" == "${source_path}" ]]; then
            log_success "Skipping current symlink: ${target_path}"
            return
        fi
        die "Refusing to replace existing symlink: ${target_path} -> ${current_target}"
        return 1
    fi
    [[ ! -e "${target_path}" ]] || {
        die "Refusing to replace existing path: ${target_path}"
        return 1
    }
    if is_read_only_mode; then
        log_planned_action "create symlink: ${target_path} -> ${source_path}."
        return 1
    fi
    [[ -e "${source_path}" ]] || { die "Symlink source is missing: ${source_path}"; return 1; }
    ln -s "${source_path}" "${target_path}" || return 1
    log_success "Created symlink: ${target_path}"
}
