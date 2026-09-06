#!/usr/bin/env bash

load_tool_versions() {
    local version_file="${PROJECT_ROOT}/defaults/tool_versions.env"
    [[ -f "${version_file}" ]] || die "Tool version manifest not found: ${version_file}"
    # shellcheck disable=SC1090
    source "${version_file}"
}
