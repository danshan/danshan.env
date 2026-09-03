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
