#!/usr/bin/env bash

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

move_to_snapshot() {
    local source="$1" destination="$2" source_device destination_device
    source_device="$(stat -f '%d' "${source}")" || return 1
    destination_device="$(stat -f '%d' "${destination%/*}")" || return 1
    [[ "${source_device}" == "${destination_device}" ]] || {
        die "Snapshot requires an atomic same-filesystem move: ${source}"; return 1
    }
    mv -- "${source}" "${destination}"
}

validate_snapshot_metadata() {
    local backup="$1" path
    [[ -d "${backup}" && ! -L "${backup}" && ! -L "${backup}/originals" ]] || {
        die "Unsafe migration snapshot: ${backup}"; return 1
    }
    for path in state manifest.txt; do
        [[ -f "${backup}/${path}" && ! -L "${backup}/${path}" ]] || {
            die "Incomplete migration metadata: ${backup}/${path}"; return 1
        }
    done
    if [[ -e "${backup}/format" || -L "${backup}/format" ]]; then
        [[ ! -L "${backup}/format" && "$(cat "${backup}/format")" == 2 ]] || {
            die "Unsupported migration format: ${backup}"; return 1
        }
    fi
}

validate_font_target() {
    local path="$1" name
    [[ "${path}" == "${HOME}/Library/Fonts/"* ]] || { die "Unexpected font target: ${path}"; return 1; }
    name="${path#${HOME}/Library/Fonts/}"
    case "${name}" in
        ''|*/*|*'|'*|*$'\n'*|*$'\r'*) die "Unsafe font target: ${path}"; return 1 ;;
        *.ttf|*.otf) ;;
        *) die "Unsupported font target: ${path}"; return 1 ;;
    esac
}

validate_cask_snapshot() {
    local kind="$1" backup="$2" package target presence extra count=0 seen=() parent app_root app_name original
    app_root="$(application_root)" || return 1
    validate_snapshot_metadata "${backup}" || return 1
    validate_private_path "${backup}" || return 1
    [[ ! -L "${app_root}" ]] || return 1
    while IFS='|' read -r package target presence extra || [[ -n "${package}${target}${presence}${extra}" ]]; do
        validate_brew_package_name "${package}" || return 1
        [[ -z "${extra}" ]] || { die "Unexpected migration manifest field."; return 1; }
        case "${presence}" in present|absent) ;; *) die "Invalid original presence: ${presence}"; return 1 ;; esac
        if [[ "${kind}" == app ]]; then
            [[ "${presence}" == present && "${target}" == "${app_root}/"*.app ]] || {
                die "Invalid application migration target: ${target}"; return 1
            }
            app_name="${target#${app_root}/}"
            validate_brew_application_name "${package}" "${app_name%.app}" || return 1
            parent="${backup}/originals"
            original="${parent}/${target##*/}"
            if [[ -e "${original}" || -L "${original}" ]]; then
                [[ -d "${original}" && ! -L "${original}" ]] || { die "Invalid original App bundle: ${original}"; return 1; }
            fi
            validate_private_path "${backup}/failed-install-artifact" || return 1
        else
            validate_font_target "${target}" || return 1
            validate_private_path "${target%/*}" || return 1
            parent="${backup}/originals/${package}"
            validate_private_path "${backup}/failed-install-artifacts/${package}" || return 1
        fi
        while [[ "${parent}" != "${backup}" ]]; do
            [[ ! -L "${parent}" ]] || { die "Symlinked snapshot path: ${parent}"; return 1; }
            parent="${parent%/*}"
        done
        if [[ "${#seen[@]}" -gt 0 ]] && array_contains "${target}" "${seen[@]}"; then
            die "Duplicate migration target: ${target}"; return 1
        fi
        seen+=("${target}")
        count=$((count + 1))
    done < "${backup}/manifest.txt"
    [[ "${count}" -gt 0 ]] || { die "Empty migration manifest: ${backup}"; return 1; }
    [[ "${kind}" != app || "${count}" -eq 1 ]] || { die "App snapshot must contain one target."; return 1; }
}

artifacts_match() {
    [[ -e "$1" || -L "$1" ]] && [[ -e "$2" || -L "$2" ]] || return 1
    if [[ -L "$1" || -L "$2" ]]; then
        [[ -L "$1" && -L "$2" && "$(readlink "$1")" == "$(readlink "$2")" ]]
    else
        diff -qr -- "$1" "$2" >/dev/null 2>&1
    fi
}

preserve_artifact() {
    local target="$1" saved="$2"
    [[ -e "${target}" || -L "${target}" ]] || return 0
    [[ ! -L "${saved%/*}" ]] || return 1
    mkdir -p -- "${saved%/*}" || return 1
    if [[ -e "${saved}" || -L "${saved}" ]]; then
        artifacts_match "${target}" "${saved}" || {
            die "Refusing to overwrite retained artifact: ${saved}"; return 1
        }
    else
        cp -pR -- "${target}" "${saved}" || return 1
    fi
}

restore_artifact() {
    local original="$1" target="$2" failed="$3"
    [[ -e "${original}" || -L "${original}" ]] || return 1
    artifacts_match "${original}" "${target}" && return 0
    if [[ -e "${target}" || -L "${target}" ]]; then
        [[ ! -e "${failed}.residue" && ! -L "${failed}.residue" ]] || return 1
        mkdir -p -- "${failed%/*}" || return 1
        mv -- "${target}" "${failed}.residue" || return 1
    fi
    # Retain the original so recovery remains repeatable after another interruption.
    cp -pR -- "${original}" "${target}"
}

validate_completed_legacy_font_migration() {
    local backup_dir="$1"
    local manifest_path="${backup_dir}/manifest.txt"
    local package_name target_path backup_path extra_field
    local relative_target expected_backup_path
    local entry_count=0
    local migration_casks=()

    [[ ! -L "${backup_dir}" && ! -L "${manifest_path}" && -s "${manifest_path}" ]] || {
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
        validate_font_target "${target_path}" || return 1
        validate_private_path "${target_path%/*}" || return 1
        validate_private_path "${backup_dir}/${package_name}" || return 1
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
        brew_cask_is_registered "${package_name}" || {
            die "Legacy font migration cask is not installed: ${package_name}"
            return 1
        }
    done
}

acquire_file_lock() {
    LC_ALL=C /usr/bin/perl "$1" "$2"
}

lock_bootstrap() {
    local lock_root="${STATE_ROOT}/locks" lock_path="${STATE_ROOT}/locks/bootstrap.lock"
    local lock_helper="${PROJECT_ROOT}/scripts/lib/lock.pl"
    local legacy="${STATE_ROOT}/locks/cask-migration.lock" owner="" lock_status
    [[ -x /usr/bin/perl ]] || { die "Required system command not found: /usr/bin/perl"; return 1; }
    [[ -f "${lock_helper}" && ! -L "${lock_helper}" ]] || { die "Bootstrap lock helper is missing or unsafe: ${lock_helper}"; return 1; }
    validate_private_path "${lock_root}" || return 1
    [[ ! -L "${legacy}" ]] || { die "Symlinked legacy lock."; return 1; }
    if [[ -d "${legacy}" ]]; then
        [[ -f "${legacy}/pid" && ! -L "${legacy}/pid" ]] || { die "Unrecognized legacy migration lock: ${legacy}"; return 1; }
        owner="$(cat "${legacy}/pid")" || return 1
        [[ "${owner}" =~ ^[1-9][0-9]*$ ]] || { die "Invalid legacy lock owner: ${legacy}"; return 1; }
        if kill -0 "${owner}" 2>/dev/null; then
            die "A legacy migration is active: ${legacy}"; return 1
        fi
    fi
    [[ ! -L "${lock_path}" && ! -L "${lock_root}" ]] || { die "Refusing symlinked Bootstrap lock."; return 1; }
    if is_read_only_mode; then
        [[ -e "${lock_path}" ]] || return 0
        [[ -f "${lock_path}" ]] || { die "Invalid Bootstrap lock file."; return 1; }
        exec 9<"${lock_path}" || return 1
    else
        mkdir -p -- "${lock_root}" || return 1
        [[ ! -e "${lock_path}" || -f "${lock_path}" ]] || { die "Invalid Bootstrap lock file."; return 1; }
        exec 9>"${lock_path}" || return 1
    fi
    # The inherited descriptor keeps the kernel lock alive for this process tree.
    if acquire_file_lock "${lock_helper}" 9; then
        return 0
    else
        lock_status=$?
    fi
    if [[ "${lock_status}" -eq 1 ]]; then
        die "Another Bootstrap operation holds ${lock_path}"
    else
        die "Failed to acquire Bootstrap lock ${lock_path} (helper exit ${lock_status})"
    fi
    return 1
}

recover_interrupted_app_migration() {
    local backup_dir="$1"
    local state package_name application_path original_state original_path

    [[ -f "${backup_dir}/state" && -f "${backup_dir}/manifest.txt" ]] || {
        die "Incomplete application migration metadata: ${backup_dir}"
        return 1
    }
    state="$(cat "${backup_dir}/state")" || return 1
    case "${state}" in
        completed|rolled-back) return ;;
        rollback-incomplete)
            die "Application migration requires manual recovery: ${backup_dir}"
            return 1
            ;;
        prepared|snapshotting|snapshot-failed|installing|verifying|rolling-back) ;;
        *)
            die "Unknown application migration state '${state}': ${backup_dir}"
            return 1
            ;;
    esac
    validate_cask_snapshot app "${backup_dir}" || return 1
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
    if [[ "${state}" == prepared && ! -e "${original_path}" && ! -L "${original_path}" && -d "${application_path}" ]]; then
        write_migration_state "${backup_dir}" rolled-back
        return
    fi
    if [[ ( "${state}" == snapshotting || "${state}" == snapshot-failed ) && ! -e "${original_path}" && ! -L "${original_path}" ]] &&
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
    state="$(cat "${backup_dir}/state")" || return 1
    case "${state}" in
        completed|rolled-back) return ;;
        rollback-incomplete)
            die "Font migration requires manual recovery: ${backup_dir}"
            return 1
            ;;
        prepared|snapshotting|installing|verifying|rolling-back) ;;
        *)
            die "Unknown font migration state '${state}': ${backup_dir}"
            return 1
            ;;
    esac
    if is_read_only_mode; then
        log_planned_action "recover interrupted font migration: ${backup_dir}."
        return
    fi
    validate_cask_snapshot font "${backup_dir}" || return 1
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

    [[ ! -L "${app_backup_root}" && ! -L "${font_backup_root}" ]] || { die "Symlinked migration root."; return 1; }
    if [[ -d "${app_backup_root}" ]]; then
        for backup_dir in "${app_backup_root}"/*; do
            [[ ! -L "${backup_dir}" ]] || { die "Symlinked migration snapshot."; return 1; }
            [[ -d "${backup_dir}" ]] || continue
            recover_interrupted_app_migration "${backup_dir}" || return 1
        done
    fi
    if [[ -d "${font_backup_root}" ]]; then
        for backup_dir in "${font_backup_root}"/*; do
            [[ ! -L "${backup_dir}" ]] || { die "Symlinked migration snapshot."; return 1; }
            [[ -d "${backup_dir}" ]] || continue
            recover_interrupted_font_migration "${backup_dir}" || return 1
        done
    fi
}

validate_private_path() {
    local path="$1"
    [[ "${path}" == "${HOME}/"* ]] || { die "Path is outside the migration home: ${path}"; return 1; }
    while [[ "${path}" != "${HOME}" ]]; do
        [[ ! -L "${path}" ]] || { die "Symlinked migration path: ${path}"; return 1; }
        path="${path%/*}"
    done
}
