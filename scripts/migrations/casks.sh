#!/usr/bin/env bash

normalize_brew_name() {
    local package_name="${1##*/}"
    printf '%s\n' "${package_name}" | tr '[:upper:]' '[:lower:]'
}

brew_cask_is_registered() {
    local package="$1" inventory item expected
    inventory="$(brew list --cask -1)" || return 2
    expected="$(normalize_brew_name "${package}")" || return 2
    while IFS= read -r item || [[ -n "${item}" ]]; do
        [[ "${item##*/}" != "${expected}" ]] || return 0
    done <<< "${inventory}"
    return 1
}

application_root() { printf '/Applications\n'; }

application_bundle_path() {
    local application_name="$1"
    printf '%s/%s.app\n' "$(application_root)" "${application_name}"
}

validate_brew_application_name() {
    local package_name="$1"
    local application_name="$2"

    case "${application_name}" in
        '' ) return ;;
        '.'|'..'|*.app|*/*|*'|'*|*$'\n'*|*$'\r'*)
            die "Invalid application name for ${package_name}: ${application_name}"
            return 1
            ;;
    esac
}
append_brew_font_cask_targets() {
    local package_name="$1"
    local target_manifest="$2"
    local user_font_dir="$3"
    local info_file
    local artifact_count
    local font_count
    local artifact_index
    local target_path
    local relative_target

    require_command plutil || return 1
    info_file="$(mktemp "${TMPDIR:-/tmp}/danshan-font-cask.XXXXXX")" || return 1
    if ! brew info --cask --json=v2 "${package_name}" > "${info_file}"; then
        rm -f -- "${info_file}"
        die "Failed to inspect Homebrew font cask: ${package_name}"
        return 1
    fi
    if ! artifact_count="$(plutil -extract casks.0.artifacts raw -o - "${info_file}")" ||
        [[ "${artifact_count}" -lt 1 ]]; then
        rm -f -- "${info_file}"
        die "Failed to parse Homebrew font artifacts: ${package_name}"
        return 1
    fi

    artifact_index=0
    while [[ "${artifact_index}" -lt "${artifact_count}" ]]; do
        if ! font_count="$(plutil -extract "casks.0.artifacts.${artifact_index}.font" raw -o - "${info_file}" 2>/dev/null)" ||
            [[ "${font_count}" -lt 1 ]]; then
            rm -f -- "${info_file}"
            die "Migration cask contains a non-font artifact: ${package_name}"
            return 1
        fi
        if ! target_path="$(plutil -extract "casks.0.artifacts.${artifact_index}.target" raw -o - "${info_file}")"; then
            rm -f -- "${info_file}"
            die "Failed to parse Homebrew font target: ${package_name}"
            return 1
        fi

        case "${target_path}" in
            "${user_font_dir}/"*) ;;
            *)
                rm -f -- "${info_file}"
                die "Refusing unexpected Homebrew font target: ${target_path}"
                return 1
                ;;
        esac
        relative_target="${target_path#${user_font_dir}/}"
        case "${relative_target}" in
            ''|*/*|*'|'*)
                rm -f -- "${info_file}"
                die "Refusing unsafe Homebrew font target: ${target_path}"
                return 1
                ;;
            *.ttf|*.otf) ;;
            *)
                rm -f -- "${info_file}"
                die "Refusing unsupported Homebrew font target: ${target_path}"
                return 1
                ;;
        esac
        if ! printf '%s|%s\n' "${package_name}" "${target_path}" >> "${target_manifest}"; then
            rm -f -- "${info_file}"
            die "Failed to record Homebrew font target: ${target_path}"
            return 1
        fi
        artifact_index=$((artifact_index + 1))
    done
    rm -f -- "${info_file}"
}

rollback_brew_font_migration() {
    local backup_dir="$1" migration_manifest="$2"
    shift 2
    local package target presence original failed state rollback_failed=0
    state="$(cat "${backup_dir}/state")" || return 1
    # Preserve replacement artifacts before Homebrew removes installed files.
    while IFS='|' read -r package target presence || [[ -n "${package}" ]]; do
        original="${backup_dir}/originals/${package}/${target##*/}"
        failed="${backup_dir}/failed-install-artifacts/${package}/${target##*/}"
        if [[ "${presence}" == present && ! -e "${original}" && ! -L "${original}" ]]; then
            [[ "${state}" == snapshotting ]] && [[ -e "${target}" || -L "${target}" ]] || {
                die "Original font snapshot is missing; leaving targets untouched: ${original}"; return 1
            }
            continue
        fi
        artifacts_match "${original}" "${target}" && continue
        preserve_artifact "${target}" "${failed}" || return 1
    done < "${migration_manifest}"
    write_migration_state "${backup_dir}" rolling-back || return 1
    for package in "$@"; do
        [[ "${state}" != snapshotting ]] || continue
        local registered=0
        brew_cask_is_registered "${package}" || registered=$?
        [[ "${registered}" -ne 2 ]] || { die "Failed to inspect Cask inventory during rollback."; return 1; }
        if [[ "${registered}" -eq 0 ]]; then
            brew uninstall --cask "${package}" </dev/null || rollback_failed=1
        fi
    done
    while IFS='|' read -r package target presence || [[ -n "${package}" ]]; do
        original="${backup_dir}/originals/${package}/${target##*/}"
        failed="${backup_dir}/failed-install-artifacts/${package}/${target##*/}"
        if [[ "${presence}" == present ]]; then
            if [[ ! -e "${original}" && ! -L "${original}" ]]; then
                [[ -e "${target}" || -L "${target}" ]] || rollback_failed=1
                continue
            fi
            restore_artifact "${original}" "${target}" "${failed}" || rollback_failed=1
        elif [[ -e "${target}" || -L "${target}" ]]; then
            mkdir -p -- "${failed%/*}" || return 1
            [[ ! -e "${failed}.residue" && ! -L "${failed}.residue" ]] || return 1
            mv -- "${target}" "${failed}.residue" || rollback_failed=1
        fi
    done < "${migration_manifest}"
    [[ "${rollback_failed}" -eq 0 ]]
}

rollback_brew_app_migration() {
    local backup_dir="$1" package="$2" target="$3" original="$4"
    local failed="${backup_dir}/failed-install-artifact/${target##*/}" rollback_failed=0
    # Never quarantine an untouched/restored original when the backup is absent.
    [[ -e "${original}" || -L "${original}" ]] || {
        die "Original snapshot is unavailable; leaving application target untouched: ${target}"; return 1
    }
    if ! artifacts_match "${original}" "${target}"; then
        preserve_artifact "${target}" "${failed}" || return 1
    fi
    write_migration_state "${backup_dir}" rolling-back || return 1
    local registered=0
    brew_cask_is_registered "${package}" || registered=$?
    [[ "${registered}" -ne 2 ]] || { die "Failed to inspect Cask inventory during rollback."; return 1; }
    if [[ "${registered}" -eq 0 ]]; then
        brew uninstall --cask "${package}" </dev/null || rollback_failed=1
    fi
    restore_artifact "${original}" "${target}" "${failed}" || rollback_failed=1
    [[ "${rollback_failed}" -eq 0 ]]
}

migrate_existing_brew_app_cask() {
    local package_name="$1"
    local application_name="$2"
    local backup_root="$3"
    local application_path
    local normalized_name
    local backup_dir
    local original_path
    local failure_message=""

    if ! validate_brew_application_name "${package_name}" "${application_name}"; then
        return 1
    fi
    if [[ -z "${application_name}" ]]; then
        die "Application migration requires an application name: ${package_name}"
        return 1
    fi
    application_path="$(application_bundle_path "${application_name}")"
    if [[ ! -d "${application_path}" || -L "${application_path}" ]]; then
        die "Application migration target is missing: ${application_path}"
        return 1
    fi

    validate_private_path "${backup_root}" || return 1
    [[ ! -L "$(application_root)" ]] || { die "Symlinked application root."; return 1; }
    normalized_name="$(normalize_brew_name "${package_name}")"
    if ! mkdir -p -- "${backup_root}"; then
        die "Failed to create application migration backup root: ${backup_root}"
        return 1
    fi
    if ! backup_dir="$(mktemp -d "${backup_root}/$(date '+%Y%m%dT%H%M%S')-${normalized_name}.XXXXXX")"; then
        die "Failed to create application migration backup for: ${package_name}"
        return 1
    fi
    original_path="${backup_dir}/originals/${application_name}.app"
    printf '2\n' > "${backup_dir}/format" || return 1

    if ! printf '%s|%s|present\n' "${package_name}" "${application_path}" > "${backup_dir}/manifest.txt" ||
        ! write_migration_state "${backup_dir}" prepared ||
        ! mkdir -p -- "${original_path%/*}"; then
        die "Failed to prepare application migration snapshot: ${backup_dir}"
        return 1
    fi
    if ! write_migration_state "${backup_dir}" snapshotting ||
        ! move_to_snapshot "${application_path}" "${original_path}"; then
        write_migration_state "${backup_dir}" snapshot-failed 2>/dev/null || true
        die "Failed to snapshot existing application: ${application_path}; inspect ${backup_dir}"
        return 1
    fi

    if ! write_migration_state "${backup_dir}" installing; then
        failure_message="Failed to persist application migration install state: ${backup_dir}"
    elif ! run_homebrew_step "Install migrated App Cask: ${package_name}" \
        brew install --cask "${package_name}" </dev/null; then
        failure_message="Failed to install migrated Homebrew cask: ${package_name}"
    elif ! write_migration_state "${backup_dir}" verifying; then
        failure_message="Failed to persist application migration verify state: ${backup_dir}"
    elif ! brew_cask_is_registered "${package_name}"; then
        failure_message="Homebrew did not register migrated application cask: ${package_name}"
    elif [[ ! -d "${application_path}" ]]; then
        failure_message="Migrated application target is missing: ${application_path}"
    elif ! write_migration_state "${backup_dir}" completed; then
        failure_message="Failed to persist completed application migration state: ${backup_dir}"
    fi

    if [[ -n "${failure_message}" ]]; then
        if ! rollback_brew_app_migration \
            "${backup_dir}" "${package_name}" "${application_path}" "${original_path}"; then
            write_migration_state "${backup_dir}" rollback-incomplete 2>/dev/null || true
            die "${failure_message}; rollback is incomplete, inspect ${backup_dir}"
            return 1
        fi
        write_migration_state "${backup_dir}" rolled-back || return 1
        die "${failure_message}; previous application was restored from ${backup_dir}"
        return 1
    fi

    log_success "Homebrew application migration completed; backup retained at ${backup_dir}"
}

migrate_brew_font_casks() {
    local user_font_dir="$1" backup_root="$2"
    shift 2
    local migration_casks=("$@")
    local package_name target_path original_state backup_path migration_id backup_dir
    local target_manifest migration_manifest failure_message="" seen_targets=()
    [[ "${#migration_casks[@]}" -gt 0 ]] || return 0

    validate_private_path "${user_font_dir}" || return 1
    validate_private_path "${backup_root}" || return 1
    target_manifest="$(mktemp "${TMPDIR:-/tmp}/danshan-font-targets.XXXXXX")" || return 1
    : > "${target_manifest}"
    for package_name in "${migration_casks[@]}"; do
        if ! append_brew_font_cask_targets "${package_name}" "${target_manifest}" "${user_font_dir}"; then
            rm -f -- "${target_manifest}"
            return 1
        fi
    done
    while IFS='|' read -r package_name target_path || [[ -n "${package_name}${target_path}" ]]; do
        validate_font_target "${target_path}" || { rm -f -- "${target_manifest}"; return 1; }
        if [[ "${#seen_targets[@]}" -gt 0 ]] && array_contains "${target_path}" "${seen_targets[@]}"; then
            rm -f -- "${target_manifest}"; die "Duplicate font target: ${target_path}"; return 1
        fi
        seen_targets+=("${target_path}")
        if [[ -e "${target_path}" || -L "${target_path}" ]] &&
            [[ ! -f "${target_path}" && ! -L "${target_path}" ]]; then
            rm -f -- "${target_manifest}"
            die "Refusing non-file Homebrew font target: ${target_path}"
            return 1
        fi
    done < "${target_manifest}"

    migration_id="$(date '+%Y%m%dT%H%M%S')-$$"
    if ! mkdir -p -- "${backup_root}" || ! backup_dir="$(mktemp -d "${backup_root}/${migration_id}.XXXXXX")"; then
        rm -f -- "${target_manifest}"
        die "Failed to create font migration backup: ${backup_dir}"
        return 1
    fi
    migration_manifest="${backup_dir}/manifest.txt"
    printf '2\n' > "${backup_dir}/format" || return 1
    if ! write_migration_state "${backup_dir}" prepared || ! : > "${migration_manifest}"; then
        rm -f -- "${target_manifest}"
        die "Failed to create font migration manifest: ${migration_manifest}"
        return 1
    fi

    while IFS='|' read -r package_name target_path || [[ -n "${package_name}${target_path}" ]]; do
        original_state=absent
        if [[ -e "${target_path}" || -L "${target_path}" ]]; then
            original_state=present
        fi
        if ! printf '%s|%s|%s\n' \
            "${package_name}" "${target_path}" "${original_state}" >> "${migration_manifest}"; then
            rm -f -- "${target_manifest}"
            die "Failed to record font migration state: ${target_path}"
            return 1
        fi
    done < "${target_manifest}"
    rm -f -- "${target_manifest}"

    if ! write_migration_state "${backup_dir}" snapshotting; then
        die "Failed to persist font migration snapshot state: ${backup_dir}"
        return 1
    fi
    log_info "Snapshotting external fonts before Homebrew migration: ${backup_dir}"
    while IFS='|' read -r package_name target_path original_state ||
        [[ -n "${package_name}${target_path}${original_state}" ]]; do
        [[ "${original_state}" == present ]] || continue
        backup_path="${backup_dir}/originals/${package_name}/${target_path##*/}"
        if ! mkdir -p -- "${backup_path%/*}" || ! move_to_snapshot "${target_path}" "${backup_path}"; then
            failure_message="Failed to snapshot external font: ${target_path}"
            break
        fi
    done < "${migration_manifest}"

    if [[ -z "${failure_message}" ]]; then
        if ! write_migration_state "${backup_dir}" installing; then
            failure_message="Failed to persist font migration install state: ${backup_dir}"
        fi
    fi
    if [[ -z "${failure_message}" ]]; then
        for package_name in "${migration_casks[@]}"; do
            if ! run_homebrew_step "Install migrated font Cask: ${package_name}" \
                brew install --cask "${package_name}" </dev/null; then
                failure_message="Failed to install migrated Homebrew font cask: ${package_name}"
                break
            fi
        done
    fi

    if [[ -z "${failure_message}" ]]; then
        if ! write_migration_state "${backup_dir}" verifying; then
            failure_message="Failed to persist font migration verify state: ${backup_dir}"
        fi
    fi
    if [[ -z "${failure_message}" ]]; then
        for package_name in "${migration_casks[@]}"; do
            if ! brew_cask_is_registered "${package_name}"; then
                failure_message="Homebrew did not register migrated font cask: ${package_name}"
                break
            fi
        done
    fi
    if [[ -z "${failure_message}" ]]; then
        while IFS='|' read -r package_name target_path original_state ||
            [[ -n "${package_name}${target_path}${original_state}" ]]; do
            if [[ ! -f "${target_path}" ]]; then
                failure_message="Migrated Homebrew font target is missing: ${target_path}"
                break
            fi
        done < "${migration_manifest}"
    fi
    if [[ -z "${failure_message}" ]] &&
        ! write_migration_state "${backup_dir}" completed; then
        failure_message="Failed to persist completed font migration state: ${backup_dir}"
    fi

    if [[ -n "${failure_message}" ]]; then
        if ! rollback_brew_font_migration \
            "${backup_dir}" "${migration_manifest}" "${migration_casks[@]}"; then
            write_migration_state "${backup_dir}" rollback-incomplete
            die "${failure_message}; rollback is incomplete, inspect ${backup_dir}"
            return 1
        fi
        write_migration_state "${backup_dir}" rolled-back || return 1
        die "${failure_message}; previous fonts were restored from ${backup_dir}"
        return 1
    fi

    log_success "Homebrew font migration completed; backup retained at ${backup_dir}"
}
