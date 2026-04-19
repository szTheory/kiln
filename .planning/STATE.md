---
gsd_state_version: 1.0
milestone: v0.1.0
milestone_name: milestone
status: in_progress
stopped_at: Phase 1 Plans 01, 02, 03, 07 complete — ready for Plan 04 (external_operations + BaseWorker)
last_updated: "2026-04-19T00:10:00.000Z"
last_activity: 2026-04-19 — Phase 1 Plan 03 executed (audit_events + pg_uuidv7 + two-role model + D-12 three-layer INSERT-only enforcement + Kiln.Audit context + 22 JSV schemas + 37 green tests)
progress:
  total_phases: 9
  completed_phases: 0
  total_plans: 7
  completed_plans: 4
  percent: 57
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-18)

**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.
**Current focus:** Phase 1 — Foundation & Durability Floor

## Current Position

Phase: 1 of 9 (Foundation & Durability Floor)
Plan: 4/7 complete (01-01, 01-02, 01-03, 01-07) — next is 01-04-PLAN.md (external_operations + Kiln.Oban.BaseWorker)
Status: In progress
Last activity: 2026-04-19 — Plan 03 executed (audit_events ledger with D-12 three-layer enforcement; pg_uuidv7 extension + kjmph SQL fallback; D-48 two-role Postgres access model; Kiln.Audit context + JSV-validated append/1; 22 Draft 2020-12 per-kind schemas; 37 tests green; mix check all 11 tools green)

Progress: [██████░░░░] 57%

## Performance Metrics

**Velocity:**

- Total plans completed: 4
- Average duration: ~22 min
- Total execution time: ~88 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1     | 4/7   | ~88m  | ~22m     |

**Recent Trend:**

- Last 5 plans: 01-01 (~15m, feat), 01-07 (~10m, docs), 01-02 (~13m, feat), 01-03 (~50m, feat+test — 3 Rule-1 bugs discovered + 1 Rule-3 environment blocker fix)
- Trend: Plan 03 took longer because of the D-12 RULE/trigger interaction bug in the plan spec (Postgres query rewriting runs before triggers — masking the trigger). Fix preserves three-layer intent while making each layer independently testable.

*Updated after each plan completion.*

## Accumulated Context

### Decisions

Full decision log lives in PROJECT.md Key Decisions table. Roadmap-level decisions:

- Phase structure: 9 phases at standard granularity (SUMMARY's 8 + split operator-UX into Phase 7 core run UI and Phase 8 intake/ops/unblock/onboarding) — justified by expanded INTAKE/OPS/BLOCK/UI-07..09 scope
- Five HIGH-cost pitfalls (P2 cost runaway, P3 idempotency, P5 sandbox escape, P8 prompt injection, P21 secrets) treated as architectural invariants seeded in Phase 1, not features
- Zero-human-QA (UAT-01/02) and typed-block contract (BLOCK-01..04) are cross-cutting invariants; scenario runner is the sole acceptance oracle
- Phases 3, 4, 5 flagged HIGH for `/gsd-research-phase` before planning

### Plan 01-01 decisions

- Scaffold via `mix phx.new` in a tempdir + `rsync` into the repo to preserve `.planning/`, `prompts/`, `CLAUDE.md`
- DNSCluster fully removed (dep + child + config line) — LOCAL-01 targets single-node local deploy
- `MIX_TEST_PARTITION` read moved from `config/test.exs` → `config/runtime.exs` to satisfy T-02 (no env reads at compile time)
- `.env.sample` allowlisted via `!.env.sample` in `.gitignore`
- Oban migration version pinned at 13 (per deps/oban 2.21.1) — Plan 04 to hardcode

### Plan 01-07 decisions

- D-50: CLAUDE.md Conventions now cite the D-12 three-layer INSERT-only defense (REVOKE + `audit_events_immutable()` trigger + RULE no-op) instead of the RULE-only claim
- D-51: ARCHITECTURE.md section 9 renamed `events` → `audit_events`; schema aligned to the Plan 03 shape (event_kind Ecto.Enum, schema_version, stage_id, autogenerate: false PK); SQL example replaced with the D-12 three-layer enforcement + five D-10 composite indexes; narrative paragraph rewritten to cite the RULE silent-bypass rationale; classify_event/1 examples updated from event_type strings to event_kind atoms
- D-52: STACK.md documents `pg_uuidv7` Postgres extension (ghcr.io/fboulnois/pg_uuidv7:1.7.0 image pin, uuid_generate_v7(), PG 18 native-uuidv7() migration path, kjmph pure-SQL fallback); compose-snippet annotated rather than rewritten so the reference pattern stays intact
- D-53: version drift eliminated from research docs — PROJECT.md already carried `Elixir 1.19.5+/OTP 28.1+`, so ARCHITECTURE.md (2 hits) + STACK.md (4 hits) + SUMMARY.md (2 hits) were aligned to it; two "stale items" paragraphs rewritten as resolved
- D-51 scope boundary respected: ARCHITECTURE.md line 143's `Kiln.Audit` public-API description still says `event_type` (outside section 9); logged as a deferred cross-reference for a future audit plan

### Plan 01-02 decisions

- xref cycles uses `--label compile-connected` (Elixir xref docs best practice); the Phoenix scaffold has harmless runtime cycles between router/endpoint/controllers/layouts that don't cause recompilation pain — compile-connected cycles are the recompile tax we care about for the 12-context DAG
- `:credo` added to Dialyzer `plt_add_apps` because `lib/kiln/credo/*` modules `use Credo.Check`; without it Dialyzer flags 9 "unknown function" errors despite Credo being `runtime: false`
- Custom Credo checks compiled as normal project code (no `requires:` list in `.credo.exs`) — adding the list caused "redefining module" warnings because Credo evaluated the file twice
- Sobelow baseline intentionally non-empty at P1 — Phoenix scaffold `:browser` pipeline ships without a CSP plug; Phase 7 (UI) adds the real CSP and removes the `.sobelow-skips` entry
- `mix deps.unlock --unused` required to pass ex_check's `unused_deps` tool — Plan 01-01 removed `:dns_cluster` from mix.exs but didn't clean mix.lock; one-time cleanup
- All 23 ex_slop checks enabled (full default set) — the P1 scaffold was clean after the Task 2 Rule-3 fixups; revisit in Phase 9 dogfood if noisy

### Plan 01-03 decisions

- D-12 Layer 3 RULE shipped **DISABLED** by default (Rule 1 deviation from plan spec). Postgres query rewriting runs BEFORE triggers fire — an active `DO INSTEAD NOTHING` RULE masks Layer 2's trigger. Disabled RULE keeps Layer 2 the loud error path; AUD-03 test enables the RULE explicitly to verify it works.
- Migration 1 ships a kjmph pure-SQL `uuid_generate_v7()` fallback when `pg_uuidv7` extension is unavailable (Rule 3 deviation). Probe via `pg_available_extensions` with `@disable_ddl_transaction true` — rescue inside a migration transaction doesn't work (25P02 aborts). Fallback path sanctioned by CONTEXT.md D-06 canonical refs.
- `config/runtime.exs` KILN_DB_ROLE → Postgrex :parameters wiring is **conditional on env-var presence**. Unset = no SET ROLE; keeps `mix ecto.drop`/`create` on pre-migration-2 DB from failing with "role kiln_app does not exist".
- `audit_events` ownership transferred to kiln_owner via `ALTER TABLE OWNER TO` inside migration 3 — keeps DDL authority centralized even when bootstrap runs `mix ecto.migrate` as connecting superuser.
- `Kiln.Audit.Event` needs `read_after_writes: true` on its UUID v7 PK so Ecto fetches the Postgres-generated default `uuid_generate_v7()` id back to the struct after INSERT.
- `Kiln.Audit.append/1` uses `Map.put_new_lazy` (not `Map.put_new`) for correlation_id fallback — eager `put_new` evaluates the Logger-fetching function even when the key is already present, producing spurious ArgumentErrors.
- Postgrex 0.22.0 `err.postgres.code` is the atom `:insufficient_privilege` for SQLSTATE 42501 (not the string `"42501"`). Trigger uses `USING ERRCODE = 'feature_not_supported'` (0A000) so catching code can discriminate trigger errors from CHECK and privilege errors.

### Pending Todos

From .planning/todos/pending/ — ideas captured during sessions.

None yet.

### Blockers/Concerns

**BLOCKER — operator environment (Plan 01-01 verification):** Host port 5432 held by pre-existing `sigra-uat-postgres` Docker container. Prevented running `docker compose up -d db && mix ecto.create && mix ecto.migrate && mix test` during Plan 01-01 execution. Static acceptance criteria all pass; DB smoke deferred to operator next session (stop the conflicting container or run Kiln compose with alternate host port).

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Verification | `docker compose up -d db` under Kiln's own compose (port 5432 conflict with sigra-uat-postgres). All Plan 01-03 verification passed via kjmph pure-SQL fallback + sigra's `kiln` user; operator action still required to switch to Kiln's `pg_uuidv7` image path before Phase 2. | Operator action required | 2026-04-19 (Plan 01-01; revalidated 01-03) |
| Doc cross-reference | ARCHITECTURE.md line 143 `Kiln.Audit` context description still lists `event_type` filter (section 9 now uses `event_kind`) | Future bounded-context doc audit | 2026-04-18 (Plan 01-07; D-51 scope was section-9-only) |

## Session Continuity

Last session: 2026-04-19
Stopped at: Plans 01-01 (f567c7e), 01-07 (6f4438e, a2bc420), 01-02 (cb05fa1, 18de9a4), and 01-03 (ea6b174, aeede36, 00a3782) complete; ready for Plan 04 (external_operations + Kiln.Oban.BaseWorker)
Resume file: .planning/phases/01-foundation-durability-floor/01-04-PLAN.md
Next command: /gsd-execute-phase 1 (continues with 01-04)
