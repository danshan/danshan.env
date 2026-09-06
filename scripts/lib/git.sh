#!/usr/bin/env bash

git_worktree_is_clean() {
    local repository_path="$1"
    [[ -z "$(git -C "${repository_path}" status --porcelain)" ]]
}

validate_tracking_git_repository_identity_if_present() {
    local repository_name="$1"
    local repository_url="$2"
    local repository_path="$3"
    local actual_url

    [[ -e "${repository_path}" ]] || return 0
    require_command git
    git -C "${repository_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        die "Existing path is not a Git worktree: ${repository_path}"
        return 1
    }
    actual_url="$(git -C "${repository_path}" remote get-url origin)"
    [[ "${actual_url}" == "${repository_url}" ]] || {
        die "Unexpected origin for ${repository_name}: ${actual_url}"
        return 1
    }
}

ensure_pinned_git_repository() {
    local repository_name="$1" repository_url="$2" repository_path="$3" repository_ref="$4"
    local actual_url current_ref

    if [[ ! -e "${repository_path}" ]]; then
        if is_read_only_mode; then
            log_planned_action "clone ${repository_name} at pinned revision ${repository_ref}."
            return
        fi
        log_info "Cloning ${repository_name} at pinned revision ${repository_ref}."
        git clone --filter=blob:none "${repository_url}" "${repository_path}"
    fi
    git -C "${repository_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        die "Existing path is not a Git worktree: ${repository_path}"
        return 1
    }
    actual_url="$(git -C "${repository_path}" remote get-url origin)"
    [[ "${actual_url}" == "${repository_url}" ]] || {
        die "Unexpected origin for ${repository_name}: ${actual_url}"
        return 1
    }
    git_worktree_is_clean "${repository_path}" || {
        die "Refusing to update dirty Git worktree: ${repository_path}"
        return 1
    }
    current_ref="$(git -C "${repository_path}" rev-parse HEAD 2>/dev/null || true)"
    if [[ "${current_ref}" == "${repository_ref}" ]]; then
        log_success "Skipping current ${repository_name}: ${repository_ref}"
        return
    fi
    if is_read_only_mode; then
        log_planned_action "update ${repository_name} to pinned revision ${repository_ref}."
        return
    fi
    log_info "Updating ${repository_name} to pinned revision ${repository_ref}."
    git -C "${repository_path}" fetch --depth=1 origin "${repository_ref}"
    git -C "${repository_path}" checkout --detach "${repository_ref}"
}

update_git_repository() {
    local repository_name="$1" repository_path="$2"
    git -C "${repository_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        die "Existing path is not a Git worktree: ${repository_path}"
        return 1
    }
    if ! git_worktree_is_clean "${repository_path}"; then
        log_notice "Skipping update for dirty Git worktree: ${repository_path}"
        return 0
    fi
    if is_read_only_mode; then
        log_notice "Skipping network refresh in ${DANSHAN_MODE} mode: ${repository_name}"
        return
    fi
    log_info "Fast-forwarding ${repository_name}."
    git -C "${repository_path}" pull --ff-only
}

ensure_tracking_git_repository() {
    local repository_name="$1" repository_url="$2" repository_path="$3" actual_url
    if [[ ! -e "${repository_path}" ]]; then
        if is_read_only_mode; then
            log_planned_action "clone ${repository_name}."
            return
        fi
        log_info "Cloning ${repository_name}."
        git clone "${repository_url}" "${repository_path}"
        return
    fi
    git -C "${repository_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        die "Existing path is not a Git worktree: ${repository_path}"
        return 1
    }
    actual_url="$(git -C "${repository_path}" remote get-url origin)"
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
        return
    fi
    ln -s "${source_path}" "${target_path}"
    log_success "Created symlink: ${target_path}"
}
