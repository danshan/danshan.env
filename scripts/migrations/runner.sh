#!/usr/bin/env bash

validate_brew_package_name() {
    case "$1" in
        ''|-*|*[!A-Za-z0-9@+._/-]*|/*|*/|*//*|*'..'*) die "Invalid Cask name: $1"; return 1 ;;
    esac
}

validate_migration_config() {
    validate_table_file "${PROJECT_ROOT}/config/migrations.txt" '[|]' 3 || return 1
    local kind resource target extra key seen=() seen_targets=()
    while IFS='|' read -r kind resource target extra || [[ -n "${kind}" ]]; do
        case "${kind}" in ''|'#'*) continue ;; esac
        [[ -n "${resource}" && -n "${target}" && -z "${extra}" ]] || { die "Invalid migration entry: ${kind}"; return 1; }
        case "${kind}" in
            app)
                validate_brew_package_name "${resource}" || return 1
                validate_brew_application_name "${resource}" "${target}" || return 1 ;;
            font)
                validate_brew_package_name "${resource}" || return 1
                [[ "${target}" == - ]] || { die "Font targets must come from Homebrew metadata."; return 1; } ;;
            dotfile)
                [[ "${resource}|${target}" == 'mise|.config/mise/config.toml' ]] || {
                    die "No legacy migration adapter for: ${resource}|${target}"; return 1
                } ;;
            *) die "Unknown migration kind: ${kind}"; return 1 ;;
        esac
        if [[ "${kind}" == app ]]; then
            if [[ "${#seen_targets[@]}" -gt 0 ]] && array_contains "${target}" "${seen_targets[@]}"; then
                die "Multiple Casks claim the same App target: ${target}"; return 1
            fi
            seen_targets+=("${target}")
        fi
        key="${resource}"
        if [[ "${#seen[@]}" -gt 0 ]] && array_contains "${key}" "${seen[@]}"; then
            die "Duplicate migration resource: ${resource}"; return 1
        fi
        seen+=("${key}")
    done < "${PROJECT_ROOT}/config/migrations.txt"
}

assert_no_pending_migrations() {
    local type root backup state failed=0
    for type in app font dotfile; do
        root="${STATE_ROOT}/${type}-backups"
        [[ ! -L "${root}" ]] || { die "Symlinked migration root: ${root}"; return 1; }
        [[ -d "${root}" ]] || continue
        for backup in "${root}"/*; do
            [[ -d "${backup}" || -L "${backup}" ]] || continue
            if [[ -L "${backup}" ]]; then die "Symlinked migration snapshot: ${backup}"; return 1; fi
            if [[ "${type}" == font && ! -e "${backup}/state" && -f "${backup}/manifest.txt" ]]; then
                if find_homebrew >/dev/null && activate_homebrew && validate_completed_legacy_font_migration "${backup}"; then
                    continue
                fi
            fi
            state=""
            if [[ -f "${backup}/state" && ! -L "${backup}/state" ]]; then state="$(cat "${backup}/state")" || return 1; fi
            case "${state}" in
                completed|rolled-back) ;;
                *) log_notice "PENDING: ${backup} (${state:-unrecognized}); run recover before apply/migrate."; failed=1 ;;
            esac
        done
    done
    return "${failed}"
}

run_migrations() {
    local kind resource target extra configured installed item
    local fonts=()
    configured="$(bundle list --cask)" || return 1
    installed="$(brew list --cask -1)" || return 1
    while IFS='|' read -r kind resource target extra || [[ -n "${kind}" ]]; do
        case "${kind}" in ''|'#'*|dotfile) continue ;; esac
        item="$(normalize_brew_name "${resource}")"
        printf '%s\n' "${configured}" | grep -Fx -- "${item}" >/dev/null || {
            die "Migration Cask is absent or platform-excluded from Brewfile: ${resource}"; return 1
        }
        case "${resource}" in
            */*)
                local trusted
                trusted="$(brew trust --cask --json=v1)" || return 1
                # Trust output contains JSON strings; Cask tokens cannot contain escapes.
                printf '%s\n' "${trusted}" | grep -F "\"${resource}\"" >/dev/null || {
                    die "Missing package-level trust for ${resource}; apply must grant Brewfile trust first."; return 1
                } ;;
        esac
    done < "${PROJECT_ROOT}/config/migrations.txt"
    while IFS='|' read -r kind resource target extra || [[ -n "${kind}" ]]; do
        case "${kind}" in ''|'#'*) continue ;; esac
        if [[ "${kind}" != dotfile ]]; then
            item="$(normalize_brew_name "${resource}")"
            if printf '%s\n' "${installed}" | awk -F/ '{ print $NF }' | grep -Fx -- "${item}" >/dev/null; then
                log_success "Skipping Homebrew-owned Cask: ${resource}"
                continue
            fi
        fi
        case "${kind}" in
            font) fonts+=("${resource}") ;;
            app)
                if [[ -d "$(application_bundle_path "${target}")" ]]; then
                    migrate_existing_brew_app_cask "${resource}" "${target}" "${STATE_ROOT}/app-backups" || return 1
                else
                    log_notice "No external App to migrate: ${resource}; apply will install it."
                fi ;;
            dotfile)
                require_command stow || return 1
                local result=0
                migrate_legacy_stow_file "${resource}" "${target}" "${STATE_ROOT}/dotfile-backups" || result=$?
                [[ "${result}" -eq 0 || "${result}" -eq 2 ]] || return "${result}" ;;
        esac
    done < "${PROJECT_ROOT}/config/migrations.txt"
    if [[ "${#fonts[@]}" -gt 0 ]]; then
        migrate_brew_font_casks "${HOME}/Library/Fonts" "${STATE_ROOT}/font-backups" "${fonts[@]}"
    fi
}

recover_migrations() {
    if [[ -d "${STATE_ROOT}/app-backups" || -d "${STATE_ROOT}/font-backups" ]]; then
        activate_homebrew || return 1
    fi
    recover_interrupted_brew_migrations "${STATE_ROOT}/app-backups" "${STATE_ROOT}/font-backups" || return 1
    if [[ -d "${STATE_ROOT}/dotfile-backups" ]]; then
        recover_interrupted_stow_migrations "${STATE_ROOT}/dotfile-backups" || return 1
    fi
    assert_no_pending_migrations
}
