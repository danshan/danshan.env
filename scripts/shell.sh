#!/usr/bin/env bash

resolve_fish_shell() {
    local executable
    executable="$(command -v fish)" || {
        die "Fish is unavailable; run the Homebrew stage first."
        return 1
    }
    case "${executable}" in
        /*) ;;
        *) die "Fish must resolve to an absolute path: ${executable}"; return 1 ;;
    esac
    [[ -x "${executable}" ]] || { die "Fish is not executable: ${executable}"; return 1; }
    printf '%s\n' "${executable}"
}

read_login_shell() {
    local user record shell
    user="$(/usr/bin/id -un)" || { die "Failed to resolve the current user."; return 1; }
    record="$(/usr/bin/dscl . -read "/Users/${user}" UserShell)" || {
        die "Failed to read the current login Shell."
        return 1
    }
    case "${record}" in
        'UserShell: '/*) shell="${record#UserShell: }" ;;
        *) die "Invalid login Shell record: ${record}"; return 1 ;;
    esac
    case "${shell}" in
        *$'\n'*) die "Invalid multiline login Shell record."; return 1 ;;
    esac
    printf '%s\n' "${shell}"
}

is_registered_login_shell() {
    /usr/bin/grep -Fqx -- "$1" /etc/shells
}

register_login_shell() {
    local executable="$1"
    log_info "Registering login Shell: ${executable}"
    /usr/bin/sudo /bin/sh -c '/usr/bin/grep -Fqx -- "$1" /etc/shells || printf "%s\n" "$1" >> /etc/shells' sh "${executable}" || {
        die "Failed to register Fish in /etc/shells."
        return 1
    }
    is_registered_login_shell "${executable}" || {
        die "Fish registration was not persisted: ${executable}"
        return 1
    }
}

change_login_shell() {
    /usr/bin/chsh -s "$1"
}

apply_shell() {
    local fish_shell current_shell
    fish_shell="$(resolve_fish_shell)" || return 1
    if ! is_registered_login_shell "${fish_shell}"; then
        register_login_shell "${fish_shell}" || return 1
    fi
    current_shell="$(read_login_shell)" || return 1
    if [[ "${current_shell}" != "${fish_shell}" ]]; then
        log_info "Setting default login Shell: ${fish_shell}"
        change_login_shell "${fish_shell}" || { die "Failed to set Fish as the default login Shell."; return 1; }
        current_shell="$(read_login_shell)" || return 1
        [[ "${current_shell}" == "${fish_shell}" ]] || {
            die "Default login Shell did not change to Fish: ${current_shell}"
            return 1
        }
    fi
    export SHELL="${fish_shell}"
}

check_shell() {
    local fish_shell current_shell failed=0
    fish_shell="$(resolve_fish_shell)" || return 1
    if ! is_registered_login_shell "${fish_shell}"; then
        log_notice "UNMET: Fish is not registered in /etc/shells: ${fish_shell}"
        failed=1
    fi
    if current_shell="$(read_login_shell)"; then
        if [[ "${current_shell}" != "${fish_shell}" ]]; then
            log_notice "UNMET: Fish is not the default login Shell: ${current_shell}"
            failed=1
        fi
    else
        failed=1
    fi
    # Check downstream resources against the desired Shell without mutating the host.
    export SHELL="${fish_shell}"
    return "${failed}"
}
