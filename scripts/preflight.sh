#!/usr/bin/env bash
bootstrap_preflight() {
    local file
    [[ "$(uname -s)" == Darwin ]] || { die "This Bootstrap requires macOS."; return 1; }
    [[ "${DANSHAN_MODE:-apply}" != recover ]] || return 0
    case "${SHELL:-}" in */bash|*/zsh|*/fish) ;; *) die "Unsupported login Shell: ${SHELL:-unset}"; return 1 ;; esac
    for file in Brewfile config/mise-system.toml config/bootstrap.env config/dotfiles.tsv config/repositories.tsv config/links.tsv config/migrations.txt \
        dotfiles/mise/.config/mise/config.toml dotfiles/mise/.config/mise/mise.lock; do
        [[ -f "${PROJECT_ROOT}/${file}" ]] || { die "Required configuration is missing: ${file}"; return 1; }
    done
    validate_dotfile_config || return 1
    validate_repository_config || return 1
    validate_migration_config || return 1
    load_homebrew_install_config || return 1
    [[ "${HOMEBREW_INSTALL_REF:-}" =~ ^[0-9a-f]{40}$ ]] || { die "Homebrew installer revision must be a commit."; return 1; }
}
