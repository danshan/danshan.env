#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
while IFS= read -r script; do /bin/bash -n "${script}"; done < <(rg --files "${PROJECT_ROOT}/scripts" "${TEST_DIR}" -g '*.sh')
/bin/bash -n "${PROJECT_ROOT}/install.sh"
/bin/bash -n "${PROJECT_ROOT}/dotfiles/bash/.bashrc"
/bin/bash -n "${PROJECT_ROOT}/dotfiles/bash/.bash_profile"
/bin/zsh -n "${PROJECT_ROOT}/dotfiles/zsh/.zshrc"
command -v fish >/dev/null || fail 'Fish is required for Shell syntax verification.'
while IFS= read -r script; do fish -n "${script}"; done < <(rg --files --hidden "${PROJECT_ROOT}/dotfiles/fish" -g '*.fish')
if rg -n '(bun add|npm install).*(--global|-g)|brew (install|upgrade).*--force|curl[^|]*\|[[:space:]]*(sh|bash)' "${PROJECT_ROOT}/scripts"; then
    fail 'Forbidden direct global package, force install or remote execution pipeline.'
fi
if rg -n 'NVM_DIR|VIRTUALENVWRAPPER_PYTHON|\.rvm/bin|\.bun/bin|\.opencode/bin|\.local/bin/env.fish' "${PROJECT_ROOT}/dotfiles/bash/.bashrc" "${PROJECT_ROOT}/dotfiles/zsh/.zshrc" "${PROJECT_ROOT}/dotfiles/fish/.config/fish/config.fish"; then
    fail 'Obsolete runtime ownership remains in Shell initialization.'
fi
python3 - "${PROJECT_ROOT}" <<'PY'
import re
import sys
import tomllib
from pathlib import Path
root = Path(sys.argv[1])
config = tomllib.loads((root / 'dotfiles/mise/.config/mise/config.toml').read_text())
lock = tomllib.loads((root / 'dotfiles/mise/.config/mise/mise.lock').read_text())
assert config['settings']['lockfile'] is True
assert tomllib.loads((root / 'config/mise-system.toml').read_text()) == {}, 'Bootstrap system layer must stay empty'
assert config['tools'].keys() == lock['tools'].keys(), 'Lockfile inventory drift'
for name, value in config['tools'].items():
    version = value['version'] if isinstance(value, dict) else value
    entries = lock['tools'][name]
    assert len(entries) == 1, f'Ambiguous locked versions: {name}'
    entry = entries[0]
    assert version in entry['specifiers'], f'Selector missing from lock: {name}'
    assert entry['version'] != 'latest', f'Unresolved locked version: {name}'
    for platform in (() if name.startswith('npm:') else ('macos-arm64', 'macos-x64')):
        data = entry['platforms.' + platform]
        assert data['url'].startswith('https://') and data['checksum'], f'Incomplete platform integrity: {name}/{platform}'
    if isinstance(value, dict) and 'trust_policy_excludes' in value:
        assert name == 'npm:oh-my-openagent' and version == '4.19.1'
        assert value['trust_policy_excludes'] == ['effect@4.0.0-beta.66']
for name in ('java', 'node', 'python', 'bun'):
    assert config['tools'][name] != 'latest', f'Runtime must declare an explicit version: {name}'
assert 'aqua:starship/starship' not in config['tools']
assert config['tools']['npm:@openai/codex'] == 'latest'
# This is an explicit supply-chain hold, not a general tool version assertion.
assert config['tools']['npm:@playwright/cli'] == '0.1.18', 'ADR 0009 trust hold changed without review'
assert lock['tools']['npm:@playwright/cli'][0]['version'] == config['tools']['npm:@playwright/cli'], 'Trust hold must resolve to its exact version'
for path, fields in [('dotfiles.tsv', 2), ('repositories.tsv', 5), ('links.tsv', 2)]:
    for line in (root / 'config' / path).read_text().splitlines():
        if not line or line.startswith('#'):
            continue
        values = line.split('\t')
        assert len(values) == fields and all(values), f'Invalid tabular row: {path}'
# Track only repository-owned source paths, never package-specific script inventories.
assert not (root / 'defaults').exists()
assert not (root / 'scripts/common.sh').exists()
for p in [root / 'install.sh', *(root / 'scripts').rglob('*.sh')]:
    assert 'brew trust --tap' not in p.read_text()
PY
/usr/bin/ruby - "${PROJECT_ROOT}/Brewfile" <<'RUBY'
require 'ostruct'
module MacOS
  def self.version; OpenStruct.new(major: ENV.fetch('TEST_MACOS_MAJOR')); end
end
$entries = []
def brew(name, **options); $entries << [:brew, name, options]; end
def cask(name, **options); $entries << [:cask, name, options]; end
[25, 26].each do |major|
  ENV['TEST_MACOS_MAJOR'] = major.to_s
  $entries = []
  load ARGV.fetch(0)
  raise 'Duplicate package ownership' unless $entries.map { |type, name, _| name }.uniq.size == $entries.size
  $entries.each do |type, name, options|
    raise 'Missing exact third-party trust' if name.include?('/') && options[:trusted] != true
    raise 'Broad or unknown Bundle option' unless (options.keys - [:trusted]).empty?
  end
  raise 'Cask classification' unless $entries.any? { |type, name, _| type == :cask && name == '1password-cli' }
  raise 'Host CLI classification' unless $entries.any? { |type, name, _| type == :brew && name == 'starship' }
  raise 'Platform gate' unless $entries.any? { |_, name, _| name == 'thaw' } == (major >= 26)
end
RUBY
