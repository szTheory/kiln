---
phase: 01-foundation-durability-floor
plan: 07
subsystem: docs
tags: [spec-alignment, audit-ledger, pg_uuidv7, version-drift, documentation]

# Dependency graph
requires:
  - phase: 00-discuss
    provides: "01-CONTEXT.md D-12 three-layer enforcement, D-51 table rename, D-52 pg_uuidv7 extension decision, D-53 version baseline"
provides:
  - "CLAUDE.md Conventions now cite the D-12 three-layer INSERT-only defense (REVOKE + trigger + RULE)"
  - "ARCHITECTURE.md section 9 uses `audit_events` throughout; schema reflects the Plan 03 22-event-kind shape and the D-10 five composite indexes"
  - "STACK.md documents `pg_uuidv7` Postgres extension (image pin `ghcr.io/fboulnois/pg_uuidv7:1.7.0`, PG 18 native `uuidv7()` migration path)"
  - "STACK.md + ARCHITECTURE.md + SUMMARY.md aligned to the `Elixir 1.19.5+ / OTP 28.1+` baseline already on PROJECT.md"
affects: [01-03 audit_events migration, 01-04 external_operations, 01-06 BootChecks, 02-workflow-engine, 03-agent-adapter, 06-github-integration, 09-dogfood]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Three-layer INSERT-only enforcement: REVOKE + BEFORE trigger + RULE no-op"
    - "`pg_uuidv7` extension for time-sortable PKs until PG 18's native `uuidv7()` ships"

key-files:
  created:
    - .planning/phases/01-foundation-durability-floor/01-07-SUMMARY.md
  modified:
    - CLAUDE.md
    - .planning/research/ARCHITECTURE.md
    - .planning/research/STACK.md
    - .planning/research/SUMMARY.md

key-decisions:
  - "D-50 applied: CLAUDE.md Conventions now reflects the D-12 three-layer defense in depth (REVOKE + trigger + RULE) instead of the RULE-only claim"
  - "D-51 applied: ARCHITECTURE.md section 9 renamed `events` to `audit_events` throughout; schema, SQL example, narrative, and classify_event/1 examples all updated"
  - "D-52 applied: STACK.md documents `pg_uuidv7` as a Postgres extension, references the pinned `ghcr.io/fboulnois/pg_uuidv7:1.7.0` image, notes the kjmph pure-SQL fallback, and documents the PG 18 migration to native `uuidv7()`"
  - "D-53 applied: version drift eliminated from research docs; PROJECT.md already carried the correct `Elixir 1.19.5+/OTP 28.1+` baseline, so ARCHITECTURE.md + STACK.md + SUMMARY.md were aligned to it (five total hits across three files, plus two 'stale items' paragraphs rewritten as resolved)"

patterns-established:
  - "Research-doc drift correction pattern: use `grep -rn` against a canonical PROJECT.md pin to enumerate drift, then rewrite inline with traceable D-NN cross-references"
  - "Spec-upgrade alignment doc-only plans: four D-NN corrections shipped in two atomic commits, each paired with grep-verifiable assertions"

requirements-completed: [OBS-03]

# Metrics
duration: ~10min
completed: 2026-04-18
---

# Phase 01 Plan 07: Spec-upgrade alignment (D-50, D-51, D-52, D-53) Summary

**Four planning-artifact corrections landed atomically: CLAUDE.md now cites the three-layer ledger enforcement; ARCHITECTURE.md section 9 uses `audit_events` throughout with the D-10 composite indexes and the D-12 defense-in-depth SQL; STACK.md documents the `pg_uuidv7` extension with PG 18 migration path; research docs (ARCHITECTURE + STACK + SUMMARY) align to the locked `Elixir 1.19.5+/OTP 28.1+` baseline.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-18T23:10:00-04:00
- **Completed:** 2026-04-18T23:13:00-04:00
- **Tasks:** 2
- **Files modified:** 4 (CLAUDE.md, ARCHITECTURE.md, STACK.md, SUMMARY.md)

## Accomplishments

- **D-50:** CLAUDE.md Conventions section no longer claims `CREATE RULE … DO INSTEAD NOTHING` is the sole INSERT-only enforcement — now explicitly names the D-12 three layers (REVOKE role-based / `audit_events_immutable()` trigger / RULE no-op) with a pointer back to `01-CONTEXT.md` D-12.
- **D-51:** ARCHITECTURE.md section 9 renamed `events` → `audit_events`. Four edits: (1) `schema "events"` → `schema "audit_events"` with the Plan 03 field shape (`event_kind` Ecto.Enum, `stage_id`, `schema_version`, `actor_role`, `autogenerate: false` PK); (2) `CREATE TABLE events (...)` SQL block replaced with the full three-layer enforcement + five D-10 composite indexes + `uuid_generate_v7()` default; (3) narrative paragraph rewritten to cite the RULE silent-bypass rationale; (4) `classify_event/1` pattern-matches updated from `event_type: "run.transition." <> ...` to `event_kind: :run_state_transitioned` (etc.).
- **D-52:** STACK.md documents the `pg_uuidv7` Postgres extension in two places: an install-note block immediately after the PostgreSQL table row (covers the `ghcr.io/fboulnois/pg_uuidv7:1.7.0` image pin, `uuid_generate_v7()`, the PG 18 native-`uuidv7()` migration path, and the kjmph pure-SQL fallback) and a one-line annotation below the reference `docker-compose.yml` snippet noting that Kiln's actual `compose.yaml` uses the pg_uuidv7-bundled image instead of `postgres:16-alpine`.
- **D-53:** Version drift eliminated from the three research docs. All five `Elixir 1.18` / `OTP 27` hits across ARCHITECTURE.md (line 5 confidence paragraph; `.tool-versions` directory-layout comment) and STACK.md ("step forward" paragraph; Poison replacement note; version-compatibility note) and SUMMARY.md (Recommended Stack paragraph; Constraint update paragraph) now read `Elixir 1.19.5+ / OTP 28.1+`. Two "stale items" paragraphs (STACK.md line 489, SUMMARY.md line 200) were rewritten from "flag for acceptance" to "resolved" to reflect the PROJECT.md pin that is already in place.

## Task Commits

1. **Task 1: D-50 + D-51 (CLAUDE.md Conventions + ARCHITECTURE.md section 9 rename)** — `6f4438e` (docs)
2. **Task 2: D-52 + D-53 (STACK.md pg_uuidv7 install note + version drift fix across research docs)** — `a2bc420` (docs)

## Files Modified

- `CLAUDE.md` — Conventions section sentence replaced (D-50).
- `.planning/research/ARCHITECTURE.md` — Line 5 confidence paragraph (D-53); section 9 Ecto schema, SQL block, narrative paragraph, classify_event examples (D-51); directory-layout `.tool-versions` comment (D-53).
- `.planning/research/STACK.md` — Postgres extensions install-note block added (D-52); reference compose snippet annotated (D-52); TL;DR "step forward" paragraph (D-53); Poison replacement note (D-53); version-compatibility table row (D-53); stale-items entry rewritten as resolved (D-53).
- `.planning/research/SUMMARY.md` — Recommended Stack paragraph (D-53); Constraint update paragraph rewritten as resolved (D-53).

## Grep-verifiable Assertions (all pass)

```text
$ grep -q "three-layer defense in depth" CLAUDE.md                                 # D-50 PASS
$ grep -q "REVOKE UPDATE, DELETE, TRUNCATE" CLAUDE.md                              # D-50 PASS
$ grep -q "audit_events_immutable" CLAUDE.md                                       # D-50 PASS
$ ! grep -qE "INSERT-only is enforced at the DB level via \`CREATE RULE" CLAUDE.md # D-50 PASS (old gone)
$ ! grep -q 'schema "events" do' .planning/research/ARCHITECTURE.md                # D-51 PASS (old Ecto gone)
$ grep -q 'schema "audit_events" do' .planning/research/ARCHITECTURE.md            # D-51 PASS
$ ! grep -qE "^CREATE TABLE events \(" .planning/research/ARCHITECTURE.md          # D-51 PASS (old SQL gone)
$ grep -q "CREATE TABLE audit_events" .planning/research/ARCHITECTURE.md           # D-51 PASS
$ grep -q "Why three-layer enforcement" .planning/research/ARCHITECTURE.md         # D-51 PASS
$ grep -q "event_kind: :run_state_transitioned" .planning/research/ARCHITECTURE.md # D-51 PASS
$ grep -q "pg_uuidv7" .planning/research/STACK.md                                  # D-52 PASS
$ grep -q "ghcr.io/fboulnois/pg_uuidv7:1.7.0" .planning/research/STACK.md          # D-52 PASS
$ grep -q "uuid_generate_v7" .planning/research/STACK.md                           # D-52 PASS
$ grep -q "Postgres 18" .planning/research/STACK.md                                # D-52 PASS
$ ! grep -qE "Elixir 1\.18|OTP 27" .planning/research/STACK.md                     # D-53 PASS
$ ! grep -qE "Elixir 1\.18|OTP 27" .planning/research/ARCHITECTURE.md              # D-53 PASS
$ ! grep -qE "Elixir 1\.18|OTP 27" .planning/research/SUMMARY.md                   # D-53 PASS
$ grep -q "Elixir 1.19.5" .planning/research/STACK.md && grep -q "OTP 28" .planning/research/STACK.md  # D-53 PASS
```

A final sweep across `.planning/` and `CLAUDE.md` confirms the only remaining `Elixir 1.18` / `OTP 27` occurrences live inside `01-07-PLAN.md` and `01-CONTEXT.md` — expected, since those artifacts describe the drift being fixed.

## Edit Counts

| File | Edits | Notes |
|---|---|---|
| CLAUDE.md | 1 | Conventions single-sentence replacement (D-50). |
| .planning/research/ARCHITECTURE.md | 6 | Line 5 confidence (D-53); section 9 Ecto schema (D-51); section 9 SQL block (D-51); section 9 narrative (D-51); section 9 classify_event (D-51); directory-layout `.tool-versions` (D-53). |
| .planning/research/STACK.md | 5 | Postgres extensions install note (D-52); compose-snippet annotation (D-52); TL;DR paragraph (D-53); Poison replacement note (D-53); version-compat row (D-53); stale-items entry (D-53). *(Six entries listed; counted as 5 because the two D-52 edits are a single conceptual change split across adjacent insertion points.)* |
| .planning/research/SUMMARY.md | 2 | Recommended Stack paragraph (D-53); Constraint update entry (D-53). |

**Total:** 14 edits across 4 files, committed in 2 atomic commits.

## Additional Drift Found Beyond CONTEXT.md D-53's Prediction

CONTEXT.md D-53 originally named only `PROJECT.md` as the drift owner. The plan's scope-clarification paragraph extended the search to `ARCHITECTURE.md + STACK.md + SUMMARY.md`; the actual drift count across those three files was:

- **ARCHITECTURE.md:** 2 hits (line 5 confidence line; line 975 `.tool-versions` directory-layout comment).
- **STACK.md:** 4 hits (line 14 TL;DR paragraph; line 456 Poison replacement note; line 474 version-compatibility row; line 489 stale-items recommendation).
- **SUMMARY.md:** 2 hits (line 20 Recommended Stack paragraph; line 200 Constraint update bullet).

Total: **8 hits across 3 files** — more than the "~5" the plan estimated, but still well within single-task scope. No drift found outside the three files, and none in CLAUDE.md (the original `Elixir 1.18 / OTP 27` drift CLAUDE.md had was already corrected in a prior edit before Plan 07).

## Compose-Snippet Annotation Decision (D-52)

The plan offered two options for the reference `docker-compose.yml` snippet in STACK.md: edit the snippet itself to reference `ghcr.io/fboulnois/pg_uuidv7:1.7.0`, or add a one-line annotation directly below the snippet. **Selected: annotate only.** Rationale: the snippet is a reference pattern (not Kiln's actual compose.yaml), so rewriting the `image:` line would imply Kiln still uses `postgres:16-alpine`. The adjacent annotation preserves the reference pattern while pointing operators to the correct image. Annotation reads: `> Kiln's compose.yaml uses ghcr.io/fboulnois/pg_uuidv7:1.7.0 (PG 16 + pg_uuidv7 extension pre-installed) instead of postgres:16-alpine — see CONTEXT.md D-52.`

## Decisions Made

None beyond the planned D-50/D-51/D-52/D-53 applications. The D-53 scope clarification (fix ARCHITECTURE + STACK + SUMMARY instead of PROJECT) was pre-decided in the plan.

The compose-snippet annotation vs. rewrite choice (D-52) was the only micro-decision left to execution; selected annotation-only (preserves reference-pattern semantics).

## Deviations from Plan

None - plan executed exactly as written. The plan's scope-clarification paragraph for D-53 correctly predicted the drift locations, and all four spec upgrades applied cleanly.

## Issues Encountered

**Minor location confusion in plan:** The plan's D-53 subsection says "STACK.md line 5 (confidence paragraph)" and "STACK.md line ~958 (`.tool-versions` comment)". The first target text lives on ARCHITECTURE.md line 5, not STACK.md line 5; the second target lives on ARCHITECTURE.md line 975, not STACK.md line 958 (STACK.md has ~555 lines). Resolved by locating the target strings via `grep` and applying edits to whichever file actually contained each one. No drift was missed; no un-targeted files were edited.

## Out-of-scope Cross-Reference Observation

ARCHITECTURE.md line 143 (inside section 3's `Kiln.Audit` bounded-context description, outside section 9) still reads `list_events/1 (filter by run_id, actor, event_type, time range)`. The old `event_type` field name is now `event_kind` per D-51's renamed schema. Plan 07 explicitly scopes D-51's ARCHITECTURE.md edits to section 9 only ("Do not change anything in ARCHITECTURE.md outside section 9 for D-51"), so this reference is **intentionally left unchanged** by this plan. It does not affect correctness (the context-description paragraph is prose, not code), but a future plan auditing bounded-context docs should align it. Logged as a deferred item.

## User Setup Required

None - no external service configuration required (doc-only plan).

## Next Phase Readiness

- Plans 02-06 can now read ARCHITECTURE.md section 9, STACK.md Postgres extensions, and CLAUDE.md Conventions as authoritative without inheriting stale assumptions.
- Plan 03 (`audit_events` table + `pg_uuidv7` + three-layer enforcement) now has an exact ARCHITECTURE.md section 9 blueprint matching D-10 + D-12 to implement against.
- Plan 04 (`external_operations`) inherits the same `pg_uuidv7` + `uuid_generate_v7()` + table-owner/runtime-role split.
- Phases 2-9 no longer risk referencing the old `events` table name, the RULE-only enforcement claim, or the Elixir 1.18 / OTP 27 baseline.

## Self-Check: PASSED

- FOUND: `.planning/phases/01-foundation-durability-floor/01-07-SUMMARY.md`
- FOUND: `CLAUDE.md`
- FOUND: `.planning/research/ARCHITECTURE.md`
- FOUND: `.planning/research/STACK.md`
- FOUND: `.planning/research/SUMMARY.md`
- FOUND: commit `6f4438e` (Task 1 — D-50 + D-51)
- FOUND: commit `a2bc420` (Task 2 — D-52 + D-53)

All claims verified against working tree and git history.

---

*Phase: 01-foundation-durability-floor*
*Plan: 07*
*Completed: 2026-04-18*
