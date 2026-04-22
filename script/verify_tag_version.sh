#!/usr/bin/env bash
# Verify pushed Git tag matches mix.exs project version (GIT-04 / D-923).
#
# Reads `version: "…"` from mix.exs (no Mix.Project / compile required).
#
# CI: expects GITHUB_REF_NAME (e.g. v0.1.0) from GitHub Actions on tag push.
# Local: bash script/verify_tag_version.sh 0.1.0 v0.1.0
#
# Exit 0 when tag (without leading v) equals mix.exs version.
# Exit 1 on mismatch with both values on stderr.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read_mix_version() {
  local v
  v="$(grep -E '^\s*version:\s*"' "$ROOT/mix.exs" | head -1 | sed -E 's/.*version: "([^"]+)".*/\1/')"
  if [[ -z "${v}" ]]; then
    echo "verify_tag_version: could not parse version from mix.exs" >&2
    exit 1
  fi
  printf '%s' "$v"
}

MIX_VERSION="$(read_mix_version)"

if [[ $# -eq 2 ]]; then
  EXPECTED="$1"
  TAG="$2"
elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
  EXPECTED="${MIX_VERSION}"
  TAG="${GITHUB_REF_NAME}"
else
  echo "verify_tag_version: set GITHUB_REF_NAME or pass: <expected_version> <tag>" >&2
  exit 1
fi

TAG_STRIPPED="${TAG#v}"

if [[ "${TAG_STRIPPED}" != "${EXPECTED}" ]]; then
  echo "verify_tag_version: tag '${TAG}' (expected version '${EXPECTED}') does not match mix.exs version '${MIX_VERSION}'" >&2
  exit 1
fi

if [[ "${EXPECTED}" != "${MIX_VERSION}" ]]; then
  echo "verify_tag_version: first arg '${EXPECTED}' does not match mix.exs version '${MIX_VERSION}'" >&2
  exit 1
fi

exit 0
