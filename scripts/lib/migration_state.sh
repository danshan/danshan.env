#!/usr/bin/env bash

DANSHAN_MIGRATION_LOCK_HELD=0
DANSHAN_MIGRATION_LOCK_DIR=""

write_migration_state() {
    local backup_dir="$1"
    local state="$2"
    local state_path="${backup_dir}/state"
    local temporary_path

    temporary_path="$(mktemp "${state_path}.XXXXXX")" || return 1
    if ! printf '%s\n' "${state}" > "${temporary_path}" ||
        ! mv -- "${temporary_path}" "${state_path}"; then
        rm -f -- "${temporary_path}"
        return 1
    fi
}

validate_completed_legacy_font_migration() {
    local backup_dir="$1"
    local manifest_path="${backup_dir}/manifest.txt"
    local package_name target_path backup_path extra_field
    local relative_target expected_backup_path
    local entry_count=0
    local migration_casks=()

    [[ -s "${manifest_path}" ]] || {
        die "Legacy font migration manifest is missing or empty: ${manifest_path}"
        return 1
    }
    while IFS='|' read -r package_name target_path backup_path extra_field ||
        [[ -n "${package_name}${target_path}${backup_path}${extra_field}" ]]; do
        [[ -n "${package_name}" && -n "${target_path}" && -n "${backup_path}" && -z "${extra_field}" ]] || {
            die "Invalid legacy font migration manifest entry: ${manifest_path}"
            return 1
        }
        validate_brew_package_name "${package_name}" "legacy Homebrew font" || return 1
        case "${target_path}" in
            "${HOME}/Library/Fonts/"*) ;;
            *)
                die "Unexpected legacy font migration target: ${target_path}"
                return 1
                ;;
        esac
        relative_target="${target_path#${HOME}/Library/Fonts/}"
        case "${relative_target}" in
            ''|*/*|*'|'*)
                die "Unsafe legacy font migration target: ${target_path}"
                return 1
                ;;
            *.ttf|*.otf) ;;
            *)
                die "Unsupported legacy font migration target: ${target_path}"
                return 1
                ;;
        esac
        expected_backup_path="${backup_dir}/${package_name}/${relative_target}"
        [[ "${backup_path}" == "${expected_backup_path}" && -f "${backup_path}" ]] || {
            die "Invalid legacy font migration backup: ${backup_path}"
            return 1
        }
        [[ -f "${target_path}" ]] || {
            die "Completed legacy font migration target is missing: ${target_path}"
            return 1
        }
        if [[ "${#migration_casks[@]}" -eq 0 ]] ||
            ! array_contains "${package_name}" "${migration_casks[@]}"; then
            migration_casks+=("${package_name}")
        fi
        entry_count=$((entry_count + 1))
    done < "${manifest_path}"
    [[ "${entry_count}" -gt 0 ]] || {
        die "Legacy font migration manifest is empty: ${manifest_path}"
        return 1
    }
    for package_name in "${migration_casks[@]}"; do
        brew list --cask "${package_name}" >/dev/null 2>&1 || {
            die "Legacy font migration cask is not installed: ${package_name}"
            return 1
        }
    done
}

check_brew_migration_lock() {
    local lock_dir="$1"
    local owner_pid=""

    [[ -d "${lock_dir}" ]] || return 0
    if [[ -f "${lock_dir}/pid" ]]; then
        owner_pid="$(sed -n '1p' "${lock_dir}/pid")"
    fi
    case "${owner_pid}" in
        ''|*[!0-9]*)
            log_notice "Stale migration lock requires recovery: ${lock_dir}"
            return
            ;;
    esac
    if kill -0 "${owner_pid}" 2>/dev/null; then
        die "Another Homebrew migration is active with PID ${owner_pid}: ${lock_dir}"
        return 1
    fi
    log_notice "Stale migration lock requires recovery: ${lock_dir}"
}

acquire_brew_migration_lock() {
    local lock_root="$1"
    local lock_dir="${lock_root}/cask-migration.lock"
    local owner_pid=""

    if is_read_only_mode; then
        check_brew_migration_lock "${lock_dir}"
        return
    fi
    mkdir -p -- "${lock_root}"
    if ! mkdir -- "${lock_dir}" 2>/dev/null; then
        if [[ -f "${lock_dir}/pid" ]]; then
            owner_pid="$(sed -n '1p' "${lock_dir}/pid")"
        fi
        case "${owner_pid}" in
            ''|*[!0-9]*) ;;
            *)
                if kill -0 "${owner_pid}" 2>/dev/null; then
                    die "Another Homebrew migration is active with PID ${owner_pid}: ${lock_dir}"
                    return 1
                fi
                ;;
        esac
        if [[ -n "$(find "${lock_dir}" -mindepth 1 -maxdepth 1 ! -name pid -print -quit 2>/dev/null)" ]]; then
            die "Refusing to remove a migration lock containing unexpected files: ${lock_dir}"
            return 1
        fi
        rm -f -- "${lock_dir}/pid"
        if ! rmdir "${lock_dir}" || ! mkdir -- "${lock_dir}"; then
            die "Failed to recover stale migration lock: ${lock_dir}"
            return 1
        fi
        log_notice "Recovered stale migration lock: ${lock_dir}"
    fi
    if ! printf '%s\n' "$$" > "${lock_dir}/pid"; then
        rmdir "${lock_dir}" 2>/dev/null || true
        die "Failed to persist migration lock owner: ${lock_dir}"
        return 1
    fi
    DANSHAN_MIGRATION_LOCK_DIR="${lock_dir}"
    DANSHAN_MIGRATION_LOCK_HELD=1
}

release_brew_migration_lock() {
    if [[ "${DANSHAN_MIGRATION_LOCK_HELD}" -ne 1 ]]; then
        return
    fi
    rm -f -- "${DANSHAN_MIGRATION_LOCK_DIR}/pid"
    rmdir "${DANSHAN_MIGRATION_LOCK_DIR}" 2>/dev/null || true
    DANSHAN_MIGRATION_LOCK_HELD=0
    DANSHAN_MIGRATION_LOCK_DIR=""
}

recover_interrupted_app_migration() {
    local backup_dir="$1"
    local state package_name application_path original_state original_path

    [[ -f "${backup_dir}/state" && -f "${backup_dir}/manifest.txt" ]] || {
        die "Incomplete application migration metadata: ${backup_dir}"
        return 1
    }
    state="$(sed -n '1p' "${backup_dir}/state")"
    case "${state}" in
        completed|rolled-back) return ;;
        rollback-incomplete)
            die "Application migration requires manual recovery: ${backup_dir}"
            return 1
            ;;
        prepared|snapshotting|snapshot-failed|installing|verifying) ;;
        *)
            die "Unknown application migration state '${state}': ${backup_dir}"
            return 1
            ;;
    esac
    IFS='|' read -r package_name application_path original_state < "${backup_dir}/manifest.txt"
    [[ -n "${package_name}" && -n "${application_path}" && "${original_state}" == present ]] || {
        die "Invalid application migration manifest: ${backup_dir}/manifest.txt"
        return 1
    }
    original_path="${backup_dir}/originals/${application_path##*/}"
    if is_read_only_mode; then
        log_planned_action "recover interrupted application migration: ${backup_dir}."
        return
    fi
    log_notice "Recovering interrupted application migration: ${backup_dir}"
    if [[ "${state}" == prepared && ! -e "${original_path}" && ! -L "${original_path}" ]]; then
        write_migration_state "${backup_dir}" rolled-back
        return
    fi
    if [[ "${state}" == snapshotting && ! -e "${original_path}" && ! -L "${original_path}" ]] &&
        [[ -e "${application_path}" || -L "${application_path}" ]]; then
        write_migration_state "${backup_dir}" rolled-back
        return
    fi
    if ! rollback_brew_app_migration \
        "${backup_dir}" "${package_name}" "${application_path}" "${original_path}"; then
        write_migration_state "${backup_dir}" rollback-incomplete || true
        die "Interrupted application migration rollback is incomplete: ${backup_dir}"
        return 1
    fi
    write_migration_state "${backup_dir}" rolled-back || {
        die "Failed to persist recovered application migration state: ${backup_dir}"
        return 1
    }
}

recover_interrupted_font_migration() {
    local backup_dir="$1"
    local state package_name target_path original_state
    local migration_casks=()

    if [[ ! -e "${backup_dir}/state" && -f "${backup_dir}/manifest.txt" ]]; then
        validate_completed_legacy_font_migration "${backup_dir}" || {
            die "Unverified stateless font migration snapshot: ${backup_dir}"
            return 1
        }
        log_success "Skipping verified completed legacy font migration: ${backup_dir}"
        return
    fi
    [[ -f "${backup_dir}/state" && -f "${backup_dir}/manifest.txt" ]] || {
        die "Incomplete font migration metadata: ${backup_dir}"
        return 1
    }
    state="$(sed -n '1p' "${backup_dir}/state")"
    case "${state}" in
        completed|rolled-back) return ;;
        rollback-incomplete)
            die "Font migration requires manual recovery: ${backup_dir}"
            return 1
            ;;
        prepared|snapshotting|installing|verifying) ;;
        *)
            die "Unknown font migration state '${state}': ${backup_dir}"
            return 1
            ;;
    esac
    if is_read_only_mode; then
        log_planned_action "recover interrupted font migration: ${backup_dir}."
        return
    fi
    if [[ "${state}" == prepared ]]; then
        write_migration_state "${backup_dir}" rolled-back
        return
    fi
    while IFS='|' read -r package_name target_path original_state ||
        [[ -n "${package_name}${target_path}${original_state}" ]]; do
        [[ -n "${package_name}" && -n "${target_path}" ]] || {
            die "Invalid font migration manifest: ${backup_dir}/manifest.txt"
            return 1
        }
        if [[ "${#migration_casks[@]}" -eq 0 ]] ||
            ! array_contains "${package_name}" "${migration_casks[@]}"; then
            migration_casks+=("${package_name}")
        fi
    done < "${backup_dir}/manifest.txt"
    [[ "${#migration_casks[@]}" -gt 0 ]] || {
        die "Empty interrupted font migration manifest: ${backup_dir}/manifest.txt"
        return 1
    }
    log_notice "Recovering interrupted font migration: ${backup_dir}"
    if ! rollback_brew_font_migration \
        "${backup_dir}" "${backup_dir}/manifest.txt" "${migration_casks[@]}"; then
        write_migration_state "${backup_dir}" rollback-incomplete || true
        die "Interrupted font migration rollback is incomplete: ${backup_dir}"
        return 1
    fi
    write_migration_state "${backup_dir}" rolled-back || {
        die "Failed to persist recovered font migration state: ${backup_dir}"
        return 1
    }
}

recover_interrupted_brew_migrations() {
    local app_backup_root="$1"
    local font_backup_root="$2"
    local backup_dir

    if [[ -d "${app_backup_root}" ]]; then
        for backup_dir in "${app_backup_root}"/*; do
            [[ -d "${backup_dir}" ]] || continue
            recover_interrupted_app_migration "${backup_dir}"
        done
    fi
    if [[ -d "${font_backup_root}" ]]; then
        for backup_dir in "${font_backup_root}"/*; do
            [[ -d "${backup_dir}" ]] || continue
            recover_interrupted_font_migration "${backup_dir}"
        done
    fi
}
