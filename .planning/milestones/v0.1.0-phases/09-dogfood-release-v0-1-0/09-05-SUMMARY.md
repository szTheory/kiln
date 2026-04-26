---
phase: 09-dogfood-release-v0-1-0
plan: "05"
subsystem: docs
tags: [changelog, license, release]

key-files:
  created:
    - CHANGELOG.md
    - LICENSE
    - NOTICE
  modified:
    - README.md
---

# Plan 09-05 Summary

- **CHANGELOG.md** — Keep a Changelog 1.1.0 with `[Unreleased]` + `[0.1.0]` listing GIT-04, OBS-02, LOCAL-03 and 55 REQ-ID note.
- **LICENSE** — Apache-2.0 full text from apache.org + copyright header.
- **NOTICE** — minimal project attribution.
- README license section now points to Apache-2.0 files.

## Operator steps (Task 3 — manual)

1. Confirm `mix.exs` `:version` is `0.1.0`.
2. `git pull` clean `main` with merged dogfood work.
3. `git tag -a v0.1.0 -m "v0.1.0"` then `git push origin v0.1.0`.
4. Wait for CI **tag-check** job green.
5. `gh release create v0.1.0 --title "v0.1.0" --notes-file CHANGELOG.md` (or paste `[0.1.0]` section only).
6. Update `.planning/ROADMAP.md` Phase 9 row to Complete with date when policy allows.

## Self-Check: PASSED

- `wc -l LICENSE` ≥ 150
- `grep` CHANGELOG for GIT-04, OBS-02, LOCAL-03, `[0.1.0]`
