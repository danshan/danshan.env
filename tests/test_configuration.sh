#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
original_root="${PROJECT_ROOT}"
fixture="${HOME}/repository"
mkdir -p "${fixture}"
cp -R "${original_root}/scripts" "${original_root}/config" "${fixture}/"
ln -s "${original_root}/dotfiles" "${fixture}/dotfiles"
# Source the fixture core before the shared loader to resolve fixture configuration.
source "${fixture}/scripts/lib/core.sh"
load_bootstrap_libraries
export SHELL=/bin/bash
validate_dotfile_config
validate_repository_config
validate_migration_config
load_homebrew_install_config
printf 'HOMEBREW_INSTALL_REF=latest\n' > "${fixture}/config/bootstrap.env"
expect_failure load_homebrew_install_config
printf 'HOMEBREW_INSTALL_REF=$(touch "$HOME/unexpected")\n' > "${fixture}/config/bootstrap.env"
expect_failure load_homebrew_install_config
[[ ! -e "${HOME}/unexpected" ]] || fail 'Installer configuration was executed as Shell.'
printf 'mise\tall\nmise\tbash\n' > "${fixture}/config/dotfiles.tsv"
expect_failure validate_dotfile_config
printf 'mise\tunknown\n' > "${fixture}/config/dotfiles.tsv"
expect_failure validate_dotfile_config
printf 'example\thttps://example.invalid/repo.git\t../outside\ttracking\tall\n' > "${fixture}/config/repositories.tsv"
expect_failure validate_repository_config
printf 'example\thttps://example.invalid/repo.git\t.one\ttracking\tall\nexample\thttps://example.invalid/repo.git\t.two\ttracking\tall\n' > "${fixture}/config/repositories.tsv"
expect_failure validate_repository_config
printf '# No repositories\n' > "${fixture}/config/repositories.tsv"
printf '.one\t.target\n.two\t.target\n' > "${fixture}/config/links.tsv"
expect_failure validate_repository_config
printf 'app|one|Example\napp|two|Example\n' > "${fixture}/config/migrations.txt"
expect_failure validate_migration_config
printf 'font|font-a|Some.ttf\n' > "${fixture}/config/migrations.txt"
expect_failure validate_migration_config
# The runner checks the entire allowlist before any transaction and skips owned Casks.
printf 'app|vendor/tap/one|Example\nfont|vendor/tap/font-a|-\n' > "${fixture}/config/migrations.txt"
MIGRATION_CALLS=0
bundle() { printf 'one\nfont-a\n'; }
brew() {
    case "$*" in
        'list --cask -1') printf 'one\nfont-a\n' ;;
        'trust --cask --json=v1') printf '["vendor/tap/one","vendor/tap/font-a"]\n' ;;
        *) return 90 ;;
    esac
}
migrate_brew_font_casks() { MIGRATION_CALLS=$((MIGRATION_CALLS + 1)); }
migrate_existing_brew_app_cask() { MIGRATION_CALLS=$((MIGRATION_CALLS + 1)); }
run_migrations
run_migrations
assert_equals 0 "${MIGRATION_CALLS}" 'Owned Casks never migrate again'
printf 'app|one|Example\nfont|not-in-brewfile|-\n' > "${fixture}/config/migrations.txt"
expect_failure run_migrations
assert_equals 0 "${MIGRATION_CALLS}" 'Validate the entire allowlist before mutation'
