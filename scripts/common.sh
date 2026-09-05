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

application_bundle_exists() {
    local application_name="$1"
    local application_path
    application_path="$(application_bundle_path "${application_name}")"
    [[ -d "${application_path}" ]]
}

application_bundle_path() {
    local application_name="$1"
    printf '/Applications/%s.app\n' "${application_name}"
}

BREW_INSTALLED_ITEMS=()
BREW_OUTDATED_ITEMS=()
BREW_INSTALLED_COUNT=0
BREW_UPGRADED_COUNT=0
BREW_SKIPPED_COUNT=0
BREW_RECONCILED_ITEMS=()
BREW_FONT_MIGRATION_BACKUP_DIR=""
BREW_APP_MIGRATION_BACKUP_DIR=""
MACOS_MAJOR_VERSION=""
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
            if [[ "${#BREW_TRUSTED_FORMULAE[@]}" -gt 0 ]] &&
                array_contains "${normalized_name}" "${BREW_TRUSTED_FORMULAE[@]}"; then
                log_success "Skipping trusted formula: ${package_name}"
                BREW_TRUST_SKIPPED_COUNT=$((BREW_TRUST_SKIPPED_COUNT + 1))
                return
            fi
            ;;
        cask)
            if [[ "${#BREW_TRUSTED_CASKS[@]}" -gt 0 ]] &&
                array_contains "${normalized_name}" "${BREW_TRUSTED_CASKS[@]}"; then
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
    BREW_RECONCILED_ITEMS=()
    BREW_FONT_MIGRATION_BACKUP_DIR=""
    BREW_APP_MIGRATION_BACKUP_DIR=""
    while IFS= read -r item; do
        if [[ -n "${item}" ]]; then
            BREW_INSTALLED_ITEMS+=("$(normalize_brew_name "${item}")")
        fi
    done <<< "${installed_output}"
    while IFS= read -r item; do
        if [[ -n "${item}" ]]; then
            BREW_OUTDATED_ITEMS+=("$(normalize_brew_name "${item}")")
        fi
    done <<< "${outdated_output}"
}

validate_brew_cask_manifest() {
    local manifest_path="$1"
    local package_name
    local application_name
    local existing_artifact_policy
    local minimum_macos_major

    while IFS='|' read -r package_name application_name existing_artifact_policy minimum_macos_major ||
        [[ -n "${package_name}${application_name}${existing_artifact_policy}${minimum_macos_major}" ]]; do
        case "${package_name}" in
            ''|'#'*) continue ;;
        esac
        if ! validate_brew_application_name "${package_name}" "${application_name}"; then
            return 1
        fi
        case "${existing_artifact_policy:-preserve}" in
            preserve|adopt|migrate) ;;
            *)
                die "Unsupported existing artifact policy for ${package_name}: ${existing_artifact_policy}"
                return 1
                ;;
        esac
        if ! validate_macos_major_requirement "${package_name}" "${minimum_macos_major}"; then
            return 1
        fi
    done < "${manifest_path}"
}

validate_brew_application_name() {
    local package_name="$1"
    local application_name="$2"

    case "${application_name}" in
        '' ) return ;;
        '.'|'..'|*/*)
            die "Invalid application name for ${package_name}: ${application_name}"
            return 1
            ;;
    esac
}

validate_macos_major_requirement() {
    local package_name="$1"
    local minimum_macos_major="$2"

    if [[ -z "${minimum_macos_major}" ]]; then
        return
    fi
    case "${minimum_macos_major}" in
        *[!0-9]*)
            die "Invalid minimum macOS major for ${package_name}: ${minimum_macos_major}"
            return 1
            ;;
    esac
    if [[ "${minimum_macos_major}" -lt 1 ]]; then
        die "Invalid minimum macOS major for ${package_name}: ${minimum_macos_major}"
        return 1
    fi
}

load_macos_state() {
    local product_version
    local major_version

    MACOS_MAJOR_VERSION=""
    require_command sw_vers
    if ! product_version="$(sw_vers -productVersion)"; then
        die "Failed to read the current macOS version."
        return 1
    fi
    major_version="${product_version%%.*}"
    if ! validate_macos_major_requirement "current system" "${major_version}"; then
        return 1
    fi
    MACOS_MAJOR_VERSION="${major_version}"
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

    require_command plutil
    info_file="$(mktemp "${TMPDIR:-/tmp}/danshan-font-cask.XXXXXX")"
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
    local backup_dir="$1"
    local migration_manifest="$2"
    local package_name
    local target_path
    local original_state
    local backup_path
    local failed_path
    local rollback_failed=0
    shift 2

    log_notice "Rolling back Homebrew font migration."
    for package_name in "$@"; do
        if brew list --cask "${package_name}" >/dev/null 2>&1; then
            if ! brew uninstall --cask "${package_name}" </dev/null; then
                log_notice "Failed to uninstall migrated cask during rollback: ${package_name}"
                rollback_failed=1
            fi
        fi
    done

    while IFS='|' read -r package_name target_path original_state ||
        [[ -n "${package_name}${target_path}${original_state}" ]]; do
        backup_path="${backup_dir}/originals/${package_name}/${target_path##*/}"
        if [[ "${original_state}" == present ]]; then
            if [[ ! -e "${backup_path}" && ! -L "${backup_path}" ]]; then
                if [[ ! -e "${target_path}" && ! -L "${target_path}" ]]; then
                    log_notice "Font and its backup are both missing during rollback: ${target_path}"
                    rollback_failed=1
                fi
                continue
            fi
            if [[ -e "${target_path}" || -L "${target_path}" ]]; then
                failed_path="${backup_dir}/failed-install-artifacts/${package_name}/${target_path##*/}"
                if ! mkdir -p -- "${failed_path%/*}" || ! mv -- "${target_path}" "${failed_path}"; then
                    log_notice "Failed to preserve a replacement font during rollback: ${target_path}"
                    rollback_failed=1
                    continue
                fi
            fi
            if ! mv -- "${backup_path}" "${target_path}"; then
                log_notice "Failed to restore font backup: ${target_path}"
                rollback_failed=1
            fi
        elif [[ -e "${target_path}" || -L "${target_path}" ]]; then
            failed_path="${backup_dir}/failed-install-artifacts/${package_name}/${target_path##*/}"
            if ! mkdir -p -- "${failed_path%/*}" || ! mv -- "${target_path}" "${failed_path}"; then
                log_notice "Failed to preserve a new font during rollback: ${target_path}"
                rollback_failed=1
            fi
        fi
    done < "${migration_manifest}"

    [[ "${rollback_failed}" -eq 0 ]]
}

rollback_brew_app_migration() {
    local backup_dir="$1"
    local package_name="$2"
    local application_path="$3"
    local original_path="$4"
    local failed_path="${backup_dir}/failed-install-artifact/${application_path##*/}"
    local rollback_failed=0

    log_notice "Rolling back Homebrew application migration: ${package_name}"
    if brew list --cask "${package_name}" >/dev/null 2>&1; then
        if ! brew uninstall --cask "${package_name}" </dev/null; then
            log_notice "Failed to uninstall migrated cask during rollback: ${package_name}"
            rollback_failed=1
        fi
    fi

    if [[ -e "${application_path}" || -L "${application_path}" ]]; then
        if ! mkdir -p -- "${failed_path%/*}" || ! mv -- "${application_path}" "${failed_path}"; then
            log_notice "Failed to preserve application artifact during rollback: ${application_path}"
            rollback_failed=1
        fi
    fi
    if [[ ! -e "${original_path}" && ! -L "${original_path}" ]]; then
        log_notice "Application migration snapshot is missing: ${original_path}"
        rollback_failed=1
    elif [[ -e "${application_path}" || -L "${application_path}" ]]; then
        log_notice "Application target remains occupied during rollback: ${application_path}"
        rollback_failed=1
    elif ! mv -- "${original_path}" "${application_path}"; then
        log_notice "Failed to restore application snapshot: ${application_path}"
        rollback_failed=1
    fi

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
    if [[ ! -d "${application_path}" ]]; then
        die "Application migration target is missing: ${application_path}"
        return 1
    fi

    normalized_name="$(normalize_brew_name "${package_name}")"
    if ! mkdir -p -- "${backup_root}"; then
        die "Failed to create application migration backup root: ${backup_root}"
        return 1
    fi
    if ! backup_dir="$(mktemp -d "${backup_root}/$(date '+%Y%m%dT%H%M%S')-${normalized_name}.XXXXXX")"; then
        die "Failed to create application migration backup for: ${package_name}"
        return 1
    fi
    BREW_APP_MIGRATION_BACKUP_DIR="${backup_dir}"
    original_path="${backup_dir}/originals/${application_name}.app"

    if ! printf '%s|%s|present\n' "${package_name}" "${application_path}" > "${backup_dir}/manifest.txt" ||
        ! printf '%s\n' prepared > "${backup_dir}/state" ||
        ! mkdir -p -- "${original_path%/*}"; then
        die "Failed to prepare application migration snapshot: ${backup_dir}"
        return 1
    fi
    if ! printf '%s\n' snapshotting > "${backup_dir}/state" ||
        ! mv -- "${application_path}" "${original_path}"; then
        printf '%s\n' snapshot-failed > "${backup_dir}/state" 2>/dev/null || true
        die "Failed to snapshot existing application: ${application_path}; inspect ${backup_dir}"
        return 1
    fi

    log_info "Installing migrated Homebrew cask: ${package_name}"
    if ! printf '%s\n' installing > "${backup_dir}/state"; then
        failure_message="Failed to persist application migration install state: ${backup_dir}"
    elif ! brew install --quiet --cask "${package_name}" </dev/null; then
        failure_message="Failed to install migrated Homebrew cask: ${package_name}"
    elif ! printf '%s\n' verifying > "${backup_dir}/state"; then
        failure_message="Failed to persist application migration verify state: ${backup_dir}"
    elif ! brew list --cask "${package_name}" >/dev/null 2>&1; then
        failure_message="Homebrew did not register migrated application cask: ${package_name}"
    elif [[ ! -d "${application_path}" ]]; then
        failure_message="Migrated application target is missing: ${application_path}"
    elif ! printf '%s\n' completed > "${backup_dir}/state"; then
        failure_message="Failed to persist completed application migration state: ${backup_dir}"
    fi

    if [[ -n "${failure_message}" ]]; then
        if ! rollback_brew_app_migration \
            "${backup_dir}" "${package_name}" "${application_path}" "${original_path}"; then
            printf '%s\n' rollback-incomplete > "${backup_dir}/state" 2>/dev/null || true
            die "${failure_message}; rollback is incomplete, inspect ${backup_dir}"
            return 1
        fi
        printf '%s\n' rolled-back > "${backup_dir}/state"
        die "${failure_message}; previous application was restored from ${backup_dir}"
        return 1
    fi

    log_success "Homebrew application migration completed; backup retained at ${backup_dir}"
}

migrate_missing_brew_font_casks() {
    local manifest_path="$1"
    local user_font_dir="$2"
    local backup_root="$3"
    local package_name
    local application_name
    local existing_artifact_policy
    local minimum_macos_major
    local normalized_name
    local target_path
    local original_state
    local backup_path
    local migration_id
    local backup_dir
    local target_manifest
    local migration_manifest
    local failure_message=""
    local migration_casks=()

    while IFS='|' read -r package_name application_name existing_artifact_policy minimum_macos_major ||
        [[ -n "${package_name}${application_name}${existing_artifact_policy}${minimum_macos_major}" ]]; do
        case "${package_name}" in
            ''|'#'*) continue ;;
        esac
        [[ "${existing_artifact_policy:-preserve}" == migrate ]] || continue
        [[ -z "${application_name}" ]] || continue
        if [[ -n "${minimum_macos_major}" ]]; then
            if [[ -z "${MACOS_MAJOR_VERSION}" ]]; then
                die "Current macOS version is not loaded for cask: ${package_name}"
                return 1
            fi
            if [[ "${MACOS_MAJOR_VERSION}" -lt "${minimum_macos_major}" ]]; then
                continue
            fi
        fi
        normalized_name="$(normalize_brew_name "${package_name}")"
        if [[ "${#BREW_INSTALLED_ITEMS[@]}" -gt 0 ]] &&
            array_contains "${normalized_name}" "${BREW_INSTALLED_ITEMS[@]}"; then
            continue
        fi
        migration_casks+=("${package_name}")
    done < "${manifest_path}"

    if [[ "${#migration_casks[@]}" -eq 0 ]]; then
        return
    fi

    target_manifest="$(mktemp "${TMPDIR:-/tmp}/danshan-font-targets.XXXXXX")"
    : > "${target_manifest}"
    for package_name in "${migration_casks[@]}"; do
        if ! append_brew_font_cask_targets "${package_name}" "${target_manifest}" "${user_font_dir}"; then
            rm -f -- "${target_manifest}"
            return 1
        fi
    done
    while IFS='|' read -r package_name target_path || [[ -n "${package_name}${target_path}" ]]; do
        if [[ -e "${target_path}" || -L "${target_path}" ]] &&
            [[ ! -f "${target_path}" && ! -L "${target_path}" ]]; then
            rm -f -- "${target_manifest}"
            die "Refusing non-file Homebrew font target: ${target_path}"
            return 1
        fi
    done < "${target_manifest}"

    migration_id="$(date '+%Y%m%dT%H%M%S')-$$"
    backup_dir="${backup_root}/${migration_id}"
    if ! mkdir -p -- "${backup_root}" || ! mkdir -- "${backup_dir}"; then
        rm -f -- "${target_manifest}"
        die "Failed to create font migration backup: ${backup_dir}"
        return 1
    fi
    BREW_FONT_MIGRATION_BACKUP_DIR="${backup_dir}"
    migration_manifest="${backup_dir}/manifest.txt"
    if ! printf '%s\n' prepared > "${backup_dir}/state" || ! : > "${migration_manifest}"; then
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

    if ! printf '%s\n' snapshotting > "${backup_dir}/state"; then
        die "Failed to persist font migration snapshot state: ${backup_dir}"
        return 1
    fi
    log_info "Snapshotting external fonts before Homebrew migration: ${backup_dir}"
    while IFS='|' read -r package_name target_path original_state ||
        [[ -n "${package_name}${target_path}${original_state}" ]]; do
        [[ "${original_state}" == present ]] || continue
        backup_path="${backup_dir}/originals/${package_name}/${target_path##*/}"
        if ! mkdir -p -- "${backup_path%/*}" || ! mv -- "${target_path}" "${backup_path}"; then
            failure_message="Failed to snapshot external font: ${target_path}"
            break
        fi
    done < "${migration_manifest}"

    if [[ -z "${failure_message}" ]]; then
        if ! printf '%s\n' installing > "${backup_dir}/state"; then
            failure_message="Failed to persist font migration install state: ${backup_dir}"
        fi
    fi
    if [[ -z "${failure_message}" ]]; then
        for package_name in "${migration_casks[@]}"; do
            log_info "Installing migrated Homebrew font cask: ${package_name}"
            if ! brew install --quiet --cask "${package_name}" </dev/null; then
                failure_message="Failed to install migrated Homebrew font cask: ${package_name}"
                break
            fi
        done
    fi

    if [[ -z "${failure_message}" ]]; then
        if ! printf '%s\n' verifying > "${backup_dir}/state"; then
            failure_message="Failed to persist font migration verify state: ${backup_dir}"
        fi
    fi
    if [[ -z "${failure_message}" ]]; then
        for package_name in "${migration_casks[@]}"; do
            if ! brew list --cask "${package_name}" >/dev/null 2>&1; then
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
        ! printf '%s\n' completed > "${backup_dir}/state"; then
        failure_message="Failed to persist completed font migration state: ${backup_dir}"
    fi

    if [[ -n "${failure_message}" ]]; then
        if ! rollback_brew_font_migration \
            "${backup_dir}" "${migration_manifest}" "${migration_casks[@]}"; then
            printf '%s\n' rollback-incomplete > "${backup_dir}/state"
            die "${failure_message}; rollback is incomplete, inspect ${backup_dir}"
            return 1
        fi
        printf '%s\n' rolled-back > "${backup_dir}/state"
        die "${failure_message}; previous fonts were restored from ${backup_dir}"
        return 1
    fi

    for package_name in "${migration_casks[@]}"; do
        normalized_name="$(normalize_brew_name "${package_name}")"
        BREW_INSTALLED_ITEMS+=("${normalized_name}")
        BREW_RECONCILED_ITEMS+=("${normalized_name}")
        BREW_INSTALLED_COUNT=$((BREW_INSTALLED_COUNT + 1))
    done
    log_success "Homebrew font migration completed; backup retained at ${backup_dir}"
}

reconcile_brew_package() {
    local package_type="$1"
    local package_name="$2"
    local application_name="${3:-}"
    local existing_artifact_policy="${4:-preserve}"
    local minimum_macos_major="${5:-}"
    local application_migration_backup_root="${6:-${HOME}/Library/Application Support/danshan.env/app-backups}"
    local normalized_name
    normalized_name="$(normalize_brew_name "${package_name}")"

    if [[ "${package_type}" == cask ]]; then
        if ! validate_macos_major_requirement "${package_name}" "${minimum_macos_major}"; then
            return 1
        fi
        case "${existing_artifact_policy}" in
            preserve|adopt|migrate) ;;
            *)
                die "Unsupported existing artifact policy for ${package_name}: ${existing_artifact_policy}"
                return 1
                ;;
        esac
        if [[ -n "${minimum_macos_major}" ]]; then
            if [[ -z "${MACOS_MAJOR_VERSION}" ]]; then
                die "Current macOS version is not loaded for cask: ${package_name}"
                return 1
            fi
            if [[ "${MACOS_MAJOR_VERSION}" -lt "${minimum_macos_major}" ]]; then
                log_success "Skipping incompatible cask: ${package_name} (requires macOS ${minimum_macos_major} or newer; current ${MACOS_MAJOR_VERSION})"
                BREW_SKIPPED_COUNT=$((BREW_SKIPPED_COUNT + 1))
                return
            fi
        fi
    fi

    if [[ "${#BREW_INSTALLED_ITEMS[@]}" -eq 0 ]] ||
        ! array_contains "${normalized_name}" "${BREW_INSTALLED_ITEMS[@]}"; then
        if [[ "${package_type}" == cask ]]; then
            if [[ -n "${application_name}" ]] && application_bundle_exists "${application_name}"; then
                if [[ "${existing_artifact_policy}" == preserve ]]; then
                    log_success "Skipping Homebrew adoption for existing application: ${application_name}.app"
                    BREW_SKIPPED_COUNT=$((BREW_SKIPPED_COUNT + 1))
                    return
                fi
                if [[ "${existing_artifact_policy}" == migrate ]]; then
                    log_info "Migrating existing application into Homebrew ownership: ${package_name}"
                    if ! migrate_existing_brew_app_cask \
                        "${package_name}" "${application_name}" "${application_migration_backup_root}"; then
                        return 1
                    fi
                else
                    log_info "Adopting existing cask: ${package_name}"
                    if ! brew install --quiet --cask --adopt "${package_name}" </dev/null; then
                        die "Failed to adopt Homebrew cask: ${package_name}"
                        return 1
                    fi
                fi
            elif [[ "${existing_artifact_policy}" == adopt ]]; then
                log_info "Installing or adopting cask: ${package_name}"
                if ! brew install --quiet --cask --adopt "${package_name}" </dev/null; then
                    die "Failed to install or adopt Homebrew cask: ${package_name}"
                    return 1
                fi
            else
                log_info "Installing missing cask: ${package_name}"
                if ! brew install --quiet --cask "${package_name}" </dev/null; then
                    die "Failed to install Homebrew cask: ${package_name}"
                    return 1
                fi
            fi
        else
            log_info "Installing missing formula: ${package_name}"
            if ! brew install --quiet "${package_name}" </dev/null; then
                die "Failed to install Homebrew formula: ${package_name}"
                return 1
            fi
        fi
        BREW_INSTALLED_COUNT=$((BREW_INSTALLED_COUNT + 1))
        return
    fi

    if [[ "${#BREW_OUTDATED_ITEMS[@]}" -gt 0 ]] &&
        array_contains "${normalized_name}" "${BREW_OUTDATED_ITEMS[@]}"; then
        log_info "Upgrading outdated ${package_type}: ${package_name}"
        if [[ "${package_type}" == cask ]]; then
            if ! brew upgrade --quiet --cask "${package_name}" </dev/null; then
                die "Failed to upgrade Homebrew cask: ${package_name}"
                return 1
            fi
        else
            if ! brew upgrade --quiet "${package_name}" </dev/null; then
                die "Failed to upgrade Homebrew formula: ${package_name}"
                return 1
            fi
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
