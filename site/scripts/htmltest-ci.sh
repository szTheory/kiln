#!/usr/bin/env bash
# htmltest resolves paths against the output directory. Astro + GitHub Pages use
# absolute "/kiln/..." hrefs while files live at dist/_astro, dist/index.html, etc.
# Rewrite a temp copy so internal targets line up with the filesystem layout.
set -euo pipefail
SITE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -R "${SITE_ROOT}/dist" "${TMP}/ht"

if [[ "$(uname -s)" == "Darwin" ]]; then
  find "${TMP}/ht" -name '*.html' -type f -exec sed -i '' 's#/kiln/#/#g' {} +
else
  find "${TMP}/ht" -name '*.html' -type f -exec sed -i 's#/kiln/#/#g' {} +
fi

htmltest -s -c "${SITE_ROOT}/.htmltest.ci.yml" "${TMP}/ht"
