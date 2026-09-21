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
policies = dict(line.split('\t') for line in (root / 'config/mise-policy.tsv').read_text().splitlines()
                if line and not line.startswith('#'))
assert policies.keys() == config['tools'].keys(), 'Every repository tool should document its policy'
assert policies['npm:@openai/codex'] == 'latest'
for name in ('java', 'node', 'python', 'bun', 'npm:oh-my-openagent', 'npm:@playwright/cli'):
    assert policies[name] == 'installed', f'Pinned tool must not opt into automatic refresh: {name}'
# This is an explicit supply-chain hold, not a general tool version assertion.
assert config['tools']['npm:@playwright/cli'] == '0.1.18', 'ADR 0009 trust hold changed without review'
assert lock['tools']['npm:@playwright/cli'][0]['version'] == config['tools']['npm:@playwright/cli'], 'Trust hold must resolve to its exact version'
for path, fields in [('dotfiles.tsv', 2), ('repositories.tsv', 5), ('links.tsv', 2)]:
    for line in (root / 'config' / path).read_text().splitlines():
        if not line or line.startswith('#'):
            continue
        values = line.split('\t')
        assert len(values) == fields and all(values), f'Invalid tabular row: {path}'
rayignore = (root / 'dotfiles/raycast/.rayignore').read_text().splitlines()
assert rayignore and all(line.startswith('**/') for line in rayignore), 'Raycast ignores must be recursive globs'
for pattern in ('**/*.go', '**/*.java', '**/*.py', '**/*.rs', '**/*.ts'):
    assert pattern in rayignore, f'Missing representative source ignore: {pattern}'
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
def tap(name, source, **options); $entries << [:tap, name, options.merge(source: source)]; end
[13, 14, 15, 25, 26, 27, 28].each do |major|
  ENV['TEST_MACOS_MAJOR'] = major.to_s
  $entries = []
  load ARGV.fetch(0)
  raise 'Duplicate package ownership' unless $entries.map { |type, name, _| name }.uniq.size == $entries.size
  $entries.each do |type, name, options|
    if type == :tap
      raise 'Unexpected tap source' unless name == 'danshan/env' && options == {source: File.dirname(ARGV.fetch(0))}
      next
    end
    raise 'Missing exact third-party trust' if name.include?('/') && options[:trusted] != true
    raise 'Broad or unknown Bundle option' unless (options.keys - [:trusted, :greedy]).empty?
  end
  raise 'Cask classification' unless $entries.any? { |type, name, _| type == :cask && name == '1password-cli' }
  raise 'Host CLI classification' unless $entries.any? { |type, name, _| type == :brew && name == 'starship' }
  raise 'GitHub CLI ownership' unless $entries.any? { |type, name, _| type == :brew && name == 'gh' }
  raise 'GitLab CLI ownership' unless $entries.any? { |type, name, _| type == :brew && name == 'glab' }
  legacy = major >= 14 && major < 26
  raise 'Current platform gate' unless $entries.any? { |_, name, _| name == 'thaw' } == (major == 26)
  raise 'Legacy platform gate' unless $entries.any? { |_, name, _| name == 'danshan/env/thaw@1' } == legacy
  raise 'Legacy tap gate' unless $entries.any? { |type, _, _| type == :tap } == legacy
  all = $entries.reject { |type, _, _| type == :tap }
  groups = %w[latest installed].map do |policy|
    ENV['DANSHAN_BREW_POLICY'] = policy
    $entries = []
    load ARGV.fetch(0)
    $entries.reject { |type, _, _| type == :tap }
  end
  raise 'Policy groups overlap' unless (groups[0] & groups[1]).empty?
  raise 'Policy groups lose inventory' unless (groups.flatten(1) - all).empty? && (all - groups.flatten(1)).empty?
  ENV.delete('DANSHAN_BREW_POLICY')
end
begin
  update_policy(:invalid)
  raise 'Invalid policy was accepted'
rescue ArgumentError
end
# Switching one Formula and one Cask must not affect their neighbors.
input = File.read(ARGV.fetch(0))
input = input.sub('brew "wget" if update_policy(:latest)', 'brew "wget" if update_policy(:installed)')
input = input.sub('cask "raycast" if update_policy(:installed)', 'cask "raycast", greedy: true if update_policy(:latest)')
%w[latest installed].each do |policy|
  ENV['DANSHAN_BREW_POLICY'] = policy
  $entries = []
  eval(input, binding, ARGV.fetch(0))
  names = $entries.map { |_, name, _| name }
  raise 'Formula policy is not independent' unless names.include?('wget') == (policy == 'installed')
  raise 'Neighbor Formula policy changed' unless names.include?('cloc') == (policy == 'latest')
  raise 'Cask policy is not independent' unless names.include?('raycast') == (policy == 'latest')
  raise 'Neighbor Cask policy changed' unless names.include?('visual-studio-code') == (policy == 'installed')
  if policy == 'latest'
    raise 'Cask greedy option lost' unless $entries.find { |_, name, _| name == 'raycast' }[2][:greedy]
  end
end
ENV['DANSHAN_BREW_POLICY'] = 'invalid'
begin
  load ARGV.fetch(0)
  raise 'Invalid policy selection was accepted'
rescue ArgumentError
end
ENV.delete('DANSHAN_BREW_POLICY')
RUBY
/usr/bin/ruby -c "${PROJECT_ROOT}/Casks/thaw@1.rb"
