---
phase: 22-merge-authority-operator-docs
plan: "01"
subsystem: docs
tags: [merge-authority, ci, github-actions, DOCS-08]

requires: []
provides:
  - "Canonical ## Merge authority in .planning/PROJECT.md (tier table + optional locals + Local vs CI + Phase 12 citation)"
  - "README skim pointer to #merge-authority without duplicating tier pipe-table"
affects: []

tech-stack:
  added: []
  patterns:
    - "Merge authority narrative lives in PROJECT.md; README stays compact"

key-files:
  created: []
  modified:
    - ".planning/PROJECT.md"
    - "README.md"
    - ".planning/STATE.md"

key-decisions:
  - "GitHub Actions green on PRs to main remains merge oracle; optional just/mix/docs.verify called out as non-gates"
  - "Phase 12 12-01-SUMMARY.md cited for local PARTIAL vs CI honesty"

patterns-established:
  - "Exact ci.yml job name: strings in table and footnote for grep-verifiable drift detection"

requirements-completed:
  - DOCS-08

duration: 15min
completed: 2026-04-23
---

# Phase 22: Merge authority & operator docs — Plan 01 summary

**DOCS-08 shipped:** one canonical merge-authority section in `.planning/PROJECT.md` and a three-line README callout linking `#merge-authority` plus Phase 12 PARTIAL evidence — no duplicate tier table in README.

## Performance

- **Tasks:** 2  
- **Files modified:** `.planning/PROJECT.md`, `README.md`, `.planning/STATE.md` (execution snapshot)

## Task commits

1. **Task 1 — PROJECT.md merge authority SSOT** — `8c88dd8` (docs)
2. **Task 2 — README merge callout + Phase 12 pointer** — `36074d1` (docs)
3. **STATE.md execution snapshot** — `791b00d` (docs)

## Deviations

- None.

## Self-Check: PASSED

- Plan `<acceptance_criteria>` grep checks: all satisfied (run from repo root per plan verification block).
- README merge block: **3** consecutive non-empty lines under `### Merge authority (CI)` (under **Quick start**, before **Operator checklist**).
- No `| **Tier A` row in README.
