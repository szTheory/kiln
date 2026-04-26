---
phase: 09-dogfood-release-v0-1-0
plan: "01"
subsystem: infra
tags: [github-actions, ci, versioning]

key-files:
  created:
    - script/verify_tag_version.sh
  modified:
    - .github/workflows/ci.yml
    - README.md
---

# Plan 09-01 Summary

- Added `script/verify_tag_version.sh` — reads `version:` from `mix.exs` via grep (no BEAM on tag runners), compares to `GITHUB_REF_NAME` or CLI args.
- Extended `ci.yml` with `push.tags: ['v*']` and a lightweight `tag-check` job; branch `check` job skips tag refs.
- README CI badge points at `szTheory/kiln` workflow `ci.yml`.

## Self-Check: PASSED

- `bash script/verify_tag_version.sh 0.1.0 v0.1.0`
- `mix compile --warnings-as-errors`
