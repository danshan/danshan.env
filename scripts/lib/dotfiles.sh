#!/usr/bin/env bash

source_has_simple_toml_tool() {
    local config_path="$1"
    local expected_key="$2"
    local expected_value="$3"
    local line key value

    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" =~ ^[[:space:]]*([A-Za-z0-9._-]+)[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            if [[ "${key}" == "${expected_key}" && "${value}" == "${expected_value}" ]]; then
                return 0
            fi
        fi
    done < "${config_path}"
    return 1
}

legacy_toml_tools_are_source_subset() {
    local legacy_path="$1"
    local source_path="$2"
    local line key value
    local tools_section_seen=0
    local assignment_count=0
    local seen_keys=()

    [[ -s "${legacy_path}" && -f "${source_path}" ]] || return 1
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
        if [[ "${line}" == '[tools]' ]]; then
            [[ "${tools_section_seen}" -eq 0 ]] || return 1
            tools_section_seen=1
            continue
        fi
        [[ "${tools_section_seen}" -eq 1 ]] || return 1
        if [[ "${line}" =~ ^[[:space:]]*([A-Za-z0-9._-]+)[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        else
            return 1
        fi
        if [[ "${#seen_keys[@]}" -gt 0 ]] && array_contains "${key}" "${seen_keys[@]}"; then
            return 1
        fi
        source_has_simple_toml_tool "${source_path}" "${key}" "${value}" || return 1
        seen_keys+=("${key}")
        assignment_count=$((assignment_count + 1))
    done < "${legacy_path}"
    [[ "${tools_section_seen}" -eq 1 && "${assignment_count}" -gt 0 ]]
}

rollback_stow_file_migration() {
    local backup_dir="$1"
    local package_name="$2"
    local relative_path="$3"
    local target_path="${HOME}/${relative_path}"
    local original_path="${backup_dir}/originals/${relative_path}"
    local rollback_failed=0

    stow --dir "${DOTFILES_DIR}" --target "${HOME}" --delete "${package_name}" \
        >/dev/null 2>&1 || rollback_failed=1
    if [[ -e "${target_path}" || -L "${target_path}" ]]; then
        log_notice "Stow migration target remains occupied during rollback: ${target_path}"
        rollback_failed=1
    elif [[ -f "${original_path}" ]]; then
        mkdir -p -- "${target_path%/*}" || rollback_failed=1
        mv -- "${original_path}" "${target_path}" || rollback_failed=1
    else
        log_notice "Stow migration snapshot is missing: ${original_path}"
        rollback_failed=1
    fi
    [[ "${rollback_failed}" -eq 0 ]]
}

recover_interrupted_stow_migrations() {
    local backup_root="$1"
    local backup_dir state package_name relative_path extra_field
    local source_path target_path original_path

    [[ -d "${backup_root}" ]] || return 0
    for backup_dir in "${backup_root}"/*; do
        [[ -d "${backup_dir}" ]] || continue
        [[ -f "${backup_dir}/state" && -f "${backup_dir}/manifest.txt" ]] || {
            die "Incomplete Stow migration metadata: ${backup_dir}"
            return 1
        }
        state="$(sed -n '1p' "${backup_dir}/state")"
        case "${state}" in
            completed|rolled-back) continue ;;
            rollback-incomplete)
                die "Stow migration requires manual recovery: ${backup_dir}"
                return 1
                ;;
            prepared|snapshotting|reconciling|verifying) ;;
            *)
                die "Unknown Stow migration state '${state}': ${backup_dir}"
                return 1
                ;;
        esac
        IFS='|' read -r package_name relative_path extra_field < "${backup_dir}/manifest.txt"
        case "${relative_path}" in
            ''|/*|*'..'*|*'|'*)
                die "Invalid Stow migration manifest: ${backup_dir}/manifest.txt"
                return 1
                ;;
        esac
        [[ -n "${package_name}" && -z "${extra_field}" ]] || {
            die "Invalid Stow migration manifest: ${backup_dir}/manifest.txt"
            return 1
        }
        source_path="${DOTFILES_DIR}/${package_name}/${relative_path}"
        target_path="${HOME}/${relative_path}"
        original_path="${backup_dir}/originals/${relative_path}"
        if [[ -L "${target_path}" ]] && cmp -s "${source_path}" "${target_path}"; then
            if is_read_only_mode; then
                log_planned_action "mark completed Stow migration: ${backup_dir}."
            else
                write_migration_state "${backup_dir}" completed
            fi
            continue
        fi
        if [[ "${state}" == prepared && ! -e "${original_path}" && -f "${target_path}" ]]; then
            if is_read_only_mode; then
                log_planned_action "mark untouched Stow migration as rolled back: ${backup_dir}."
            else
                write_migration_state "${backup_dir}" rolled-back
            fi
            continue
        fi
        if is_read_only_mode; then
            log_planned_action "recover interrupted Stow migration: ${backup_dir}."
            continue
        fi
        if ! rollback_stow_file_migration "${backup_dir}" "${package_name}" "${relative_path}"; then
            write_migration_state "${backup_dir}" rollback-incomplete || true
            die "Interrupted Stow migration rollback is incomplete: ${backup_dir}"
            return 1
        fi
        write_migration_state "${backup_dir}" rolled-back
    done
}

migrate_legacy_stow_file() {
    local package_name="$1"
    local relative_path="$2"
    local backup_root="$3"
    local source_path="${DOTFILES_DIR}/${package_name}/${relative_path}"
    local target_path="${HOME}/${relative_path}"
    local backup_dir original_path failure_message=""

    [[ -f "${target_path}" && ! -L "${target_path}" ]] || return 2
    legacy_toml_tools_are_source_subset "${target_path}" "${source_path}" || {
        die "Refusing to migrate unrecognized existing configuration: ${target_path}"
        return 1
    }
    if is_read_only_mode; then
        log_planned_action "migrate legacy Stow target with retained snapshot: ${target_path}."
        return 0
    fi
    mkdir -p -- "${backup_root}"
    backup_dir="$(mktemp -d "${backup_root}/$(date '+%Y%m%dT%H%M%S')-${package_name}.XXXXXX")"
    original_path="${backup_dir}/originals/${relative_path}"
    mkdir -p -- "${original_path%/*}"
    printf '%s|%s\n' "${package_name}" "${relative_path}" > "${backup_dir}/manifest.txt"
    write_migration_state "${backup_dir}" prepared
    write_migration_state "${backup_dir}" snapshotting
    mv -- "${target_path}" "${original_path}"
    write_migration_state "${backup_dir}" reconciling
    if ! stow --dir "${DOTFILES_DIR}" --target "${HOME}" --restow --verbose "${package_name}"; then
        failure_message="Failed to stow migrated package: ${package_name}"
    elif ! write_migration_state "${backup_dir}" verifying; then
        failure_message="Failed to persist Stow migration verify state: ${backup_dir}"
    elif [[ ! -L "${target_path}" ]] || ! cmp -s "${source_path}" "${target_path}"; then
        failure_message="Migrated Stow target did not converge: ${target_path}"
    elif ! write_migration_state "${backup_dir}" completed; then
        failure_message="Failed to persist completed Stow migration state: ${backup_dir}"
    fi
    if [[ -n "${failure_message}" ]]; then
        if ! rollback_stow_file_migration "${backup_dir}" "${package_name}" "${relative_path}"; then
            write_migration_state "${backup_dir}" rollback-incomplete || true
            die "${failure_message}; rollback is incomplete, inspect ${backup_dir}"
            return 1
        fi
        write_migration_state "${backup_dir}" rolled-back
        die "${failure_message}; previous configuration was restored from ${backup_dir}"
        return 1
    fi
    log_success "Stow ownership migration completed; backup retained at ${backup_dir}"
}
