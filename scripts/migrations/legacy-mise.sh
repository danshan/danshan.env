#!/usr/bin/env bash

source_has_simple_toml_tool() {
    local config_path="$1"
    local expected_key="$2"
    local expected_value="$3"
    local line key value section=""

    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == \[* ]]; then section="${line}"; continue; fi
        [[ "${section}" == '[tools]' ]] || continue
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

validate_mise_snapshot() {
    local backup="$1" metadata
    validate_snapshot_metadata "${backup}" || return 1
    metadata="$(cat "${backup}/manifest.txt")" || return 1
    [[ "${metadata}" == 'mise|.config/mise/config.toml' ]] || {
        die "Unsupported legacy configuration snapshot: ${backup}"; return 1
    }
    validate_private_path "${backup}/originals/.config/mise" || return 1
    if [[ -e "${backup}/lock-state" ]]; then
        [[ ! -L "${backup}/lock-state" ]] || return 1
        case "$(cat "${backup}/lock-state")" in absent|owned) ;; *) return 1 ;; esac
    fi
}

rollback_stow_file_migration() {
    local backup="$1" package="$2" relative="$3"
    local original="${backup}/originals/${relative}" target="${HOME}/${relative}"
    local config_dir="${HOME}/.config/mise" name path resolved lock_state=absent
    [[ -f "${original}" && ! -L "${original}" ]] || { die "Legacy original is unavailable: ${original}"; return 1; }
    [[ ! -f "${backup}/lock-state" ]] || lock_state="$(cat "${backup}/lock-state")"
    validate_private_path "${HOME}/.config" || return 1
    if [[ -L "${config_dir}" ]]; then
        # Older Stow transactions could fold the whole directory into one link.
        [[ "$(cd -P "${config_dir}" && pwd)" == "${DOTFILES_DIR}/mise/.config/mise" ]] || return 1
        rm -- "${config_dir}" || return 1
    fi
    mkdir -p -- "${config_dir}" || return 1
    for name in config.toml mise.lock; do
        path="${config_dir}/${name}"
        if [[ -L "${path}" ]]; then
            resolved="$(resolve_file_path "${path}")" || return 1
            [[ "${resolved}" == "${DOTFILES_DIR}/mise/.config/mise/"* ]] || {
                die "Refusing to remove an unrecognized Stow link: ${path}"; return 1
            }
            rm -- "${path}" || return 1
        elif [[ -e "${path}" ]]; then
            [[ "${name}" == config.toml ]] && artifacts_match "${original}" "${path}" || {
                die "Refusing to overwrite a configuration created during migration: ${path}"; return 1
            }
        fi
    done
    write_migration_state "${backup}" rolling-back || return 1
    if [[ ! -e "${target}" ]]; then cp -p -- "${original}" "${target}" || return 1; fi
    if [[ "${lock_state}" == owned && ! -e "${config_dir}/mise.lock" ]]; then
        ln -s "${DOTFILES_DIR}/mise/.config/mise/mise.lock" "${config_dir}/mise.lock" || return 1
    fi
    artifacts_match "${original}" "${target}"
}

recover_interrupted_stow_migrations() {
    local root="$1" backup state original target="${HOME}/.config/mise/config.toml"
    [[ ! -L "${root}" ]] || { die "Symlinked Stow snapshot root."; return 1; }
    [[ -d "${root}" ]] || return 0
    for backup in "${root}"/*; do
        [[ -d "${backup}" || -L "${backup}" ]] || continue
        validate_mise_snapshot "${backup}" || return 1
        state="$(cat "${backup}/state")" || return 1
        case "${state}" in
            completed|rolled-back) continue ;;
            prepared|snapshotting|reconciling|verifying|rolling-back) ;;
            *) die "Stow migration requires manual recovery (${state}): ${backup}"; return 1 ;;
        esac
        original="${backup}/originals/.config/mise/config.toml"
        if [[ ( "${state}" == prepared || "${state}" == snapshotting ) && ! -e "${original}" && ! -L "${original}" ]]; then
            validate_private_path "${HOME}/.config/mise" || return 1
            [[ -f "${target}" && ! -L "${target}" ]] &&
                legacy_toml_tools_are_source_subset "${target}" "${DOTFILES_DIR}/mise/.config/mise/config.toml" || return 1
        elif ! rollback_stow_file_migration "${backup}" mise .config/mise/config.toml; then
            write_migration_state "${backup}" rollback-incomplete || true
            die "Interrupted Stow migration rollback is incomplete: ${backup}"; return 1
        fi
        write_migration_state "${backup}" rolled-back || return 1
    done
}

migrate_legacy_stow_file() {
    local package="$1" relative="$2" root="$3"
    local source="${DOTFILES_DIR}/${package}/${relative}" target="${HOME}/${relative}"
    local backup original lock_state=absent failure=""
    [[ "${package}|${relative}" == 'mise|.config/mise/config.toml' ]] || return 1
    [[ "$(resolve_file_path "${target}" || true)" != "${source}" ]] || return 2
    [[ -e "${target}" || -L "${target}" ]] || return 2
    validate_private_path "${target%/*}" || return 1
    [[ -f "${target}" && ! -L "${target}" ]] && legacy_toml_tools_are_source_subset "${target}" "${source}" || {
        die "Refusing to migrate unrecognized existing configuration: ${target}"; return 1
    }
    if [[ -e "${HOME}/.config/mise/mise.lock" || -L "${HOME}/.config/mise/mise.lock" ]]; then
        [[ "$(resolve_file_path "${HOME}/.config/mise/mise.lock")" == "${DOTFILES_DIR}/mise/.config/mise/mise.lock" ]] || {
            die "Unrecognized existing Mise lockfile."; return 1
        }
        lock_state=owned
    fi
    validate_private_path "${root}" || return 1
    mkdir -p -- "${root}" || return 1
    backup="$(mktemp -d "${root}/$(date '+%Y%m%dT%H%M%S')-mise.XXXXXX")" || return 1
    original="${backup}/originals/${relative}"
    mkdir -p -- "${original%/*}" || return 1
    printf '2\n' > "${backup}/format" || return 1
    printf '%s|%s\n' "${package}" "${relative}" > "${backup}/manifest.txt" || return 1
    printf '%s\n' "${lock_state}" > "${backup}/lock-state" || return 1
    write_migration_state "${backup}" prepared || return 1
    write_migration_state "${backup}" snapshotting || return 1
    move_to_snapshot "${target}" "${original}" || return 1
    if ! write_migration_state "${backup}" reconciling; then
        failure="Failed to persist Stow reconciliation state."
    elif ! stow --dir "${DOTFILES_DIR}" --target "${HOME}" --restow --no-folding --verbose "${package}"; then
        failure="Failed to stow migrated package: ${package}"
    elif ! write_migration_state "${backup}" verifying; then
        failure="Failed to persist Stow verification state."
    elif ! verify_mise_deployment; then
        failure="Migrated Stow package did not converge."
    elif ! write_migration_state "${backup}" completed; then
        failure="Failed to persist completed Stow state."
    fi
    if [[ -n "${failure}" ]]; then
        if ! rollback_stow_file_migration "${backup}" "${package}" "${relative}"; then
            write_migration_state "${backup}" rollback-incomplete || true
            die "${failure}; rollback is incomplete, inspect ${backup}"; return 1
        fi
        write_migration_state "${backup}" rolled-back || return 1
        die "${failure}; previous configuration restored; snapshot retained at ${backup}"; return 1
    fi
    log_success "Stow ownership migration completed; backup retained at ${backup}"
}
