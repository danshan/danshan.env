#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "${TEST_DIR}/test_helper.sh"

required_directories=(
    standards
    architecture
    design
    adr
    development
    operations
    reviews
    archive
    assets
)

for directory_name in "${required_directories[@]}"; do
    [[ -d "${PROJECT_ROOT}/docs/${directory_name}" ]] || fail "Missing docs directory: ${directory_name}"
done

while IFS= read -r document_path; do
    document_name="$(basename "${document_path}")"
    case "${document_name}" in
        README.md|AGENTS.md) continue ;;
    esac

    [[ "$(sed -n '1p' "${document_path}")" == '---' ]] || fail "Missing front matter: ${document_path}"
    grep -Eq '^title: .+' "${document_path}" || fail "Missing title metadata: ${document_path}"
    grep -Eq '^status: (draft|active|superseded|archived)$' "${document_path}" || fail "Invalid status metadata: ${document_path}"
    grep -Eq '^owner: .+' "${document_path}" || fail "Missing owner metadata: ${document_path}"
    grep -Eq '^last_updated: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "${document_path}" || fail "Invalid last_updated metadata: ${document_path}"

    relative_path="${document_path#"${PROJECT_ROOT}/docs/"}"
    case "${relative_path}" in
        adr/*)
            [[ "${document_name}" =~ ^[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] || fail "Invalid ADR filename: ${document_name}"
            ;;
        reviews/*)
            [[ "${document_name}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] || fail "Invalid review filename: ${document_name}"
            ;;
        *)
            [[ "${document_name}" =~ ^[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] || fail "Invalid documentation filename: ${document_name}"
            ;;
    esac

    if grep -Eq '^status: active$' "${document_path}"; then
        grep -Fq "${relative_path}" "${PROJECT_ROOT}/docs/README.md" || fail "Active document missing from index: ${relative_path}"
    fi
done < <(find "${PROJECT_ROOT}/docs" -type f -name '*.md' -print | sort)

python3 - "${PROJECT_ROOT}" <<'PY'
import re
import sys
from pathlib import Path
root = Path(sys.argv[1])
for path in [root / 'README.md', root / 'CONTEXT.md', *(root / 'docs').rglob('*.md')]:
    text = path.read_text()
    if text.startswith('---\n'):
        metadata = text.split('---', 2)[1]
        for target in re.findall(r'^  - (.+)$', metadata, flags=re.M):
            assert (path.parent / target).exists(), f'Broken related link: {path.relative_to(root)} -> {target}'
    body = re.sub(r'```.*?```', '', text, flags=re.S)
    for target in re.findall(r'\]\(([^)]+)\)', body):
        if re.match(r'^[a-z]+://', target) or target.startswith('#'):
            continue
        target = target.split('#')[0]
        assert (path.parent / target).exists(), f'Broken link: {path.relative_to(root)} -> {target}'
for path in (root / 'config').iterdir():
    text = path.read_text()
    prefix = ';' if path.suffix == '.sb' else '#'
    header = []
    for line in text.splitlines():
        if not line.startswith(prefix):
            break
        header.append(line)
    content = '\n'.join(header)
    for required in ('Purpose:', 'Format:', 'Example'):
        assert required in content, f'Incomplete format header: {path.name}: {required}'
PY
