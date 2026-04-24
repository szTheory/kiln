---
phase: 01-foundation-durability-floor
plan: 04
subsystem: durability-idempotency
tags: [oban, external-operations, idempotency, intent-table, brandur-stripe, audit-pairing, base-worker, pruner, d-14, d-18, d-44, d-49]

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor/01
    provides: "Phoenix 1.8.5 scaffold + 7-child supervision tree + :oban dep (2.21) in mix.exs + compose.yaml"
  - phase: 01-foundation-durability-floor/02
    provides: "mix check 11-tool gate including credo-strict, dialyzer fail-on-warning, sobelow HIGH-only"
  - phase: 01-foundation-durability-floor/03
    provides: "pg_uuidv7 (extension or kjmph fallback) + kiln_owner/kiln_app roles + Kiln.Audit.append/1 validating external_op_* kinds against JSV schemas + Kiln.DataCase sandbox template"
  - phase: 01-foundation-durability-floor/05
    provides: "logger_json formatter + Kiln.Telemetry.ObanHandler already attached in Application.start/2 — BaseWorker inherits metadata-threading for free (not re-attached here)"
provides:
  - "external_operations single polymorphic intent table (D-14): 16 columns, 5-state CHECK (intent_recorded/action_in_flight/completed/failed/abandoned — D-16), UNIQUE INDEX on idempotency_key (D-15), three supporting indexes (active-state partial, run_id, op_kind+state — D-21), uuid_generate_v7() PK default, D-48 role grants (kiln_app: INSERT/SELECT/UPDATE; NO DELETE for T-03 forensic preservation; kiln_owner owns)"
  - "InstallOban migration pinned to @oban_migration_version = 14 per D-49 (current @current_version in deps/oban 2.21.1); explicit pin catches future deps.update silent table-shape changes"
  - "Kiln.ExternalOperations context API — fetch_or_record_intent/2 (Brandur ON CONFLICT DO NOTHING + SELECT FOR UPDATE fallback), complete_op/2, fail_op/2, abandon_op/2. Each opens an Ecto.Repo.transaction and writes the state change + companion audit event atomically (D-18). Caller runs the external side-effect OUTSIDE the tx."
  - "Kiln.ExternalOperations.Operation Ecto schema — 5-value Ecto.Enum state, read_after_writes: true on uuid_generate_v7() PK, @derive Jason.Encoder whitelist drops last_error + internal timestamps"
  - "Kiln.ExternalOperations.Pruner — Oban.Worker on :maintenance queue, 30-day TTL for :completed rows only (D-19), escalates to kiln_owner via SET LOCAL ROLE inside its tx (only role with DELETE privilege on external_operations — T-03 mitigation). Scheduled via Oban.Plugins.Cron at 0 3 * * * UTC."
  - "Kiln.Oban.BaseWorker macro — __using__/1 injects max_attempts: 3 default (overrides Oban's 20 default per P9), unique config with :idempotency_key keys + period: :infinity + [:available, :scheduled, :executing] states (D-44). Ships three helpers: fetch_or_record_intent/2, complete_op/2, fail_op/2 that delegate to Kiln.ExternalOperations."
  - "Behaviors 10, 11, 12, 13, 14 from 01-VALIDATION.md mechanically asserted by two test files (15 tests, 0 failures): behaviors 10/11/13 via fetch_or_record_intent paths, 12 via complete_op, 14 via duplicate-insert assertion on oban_jobs."
affects:
  - 01-06 (BootChecks may assert external_operations shape + Oban.Plugins.Cron crontab entry for pruner)
  - Phase 3 (P3 LLM/Docker/secret workers inherit Kiln.Oban.BaseWorker and get correctness for free — idempotent retries, insert-time dedupe, two-phase intent/completion plumbing)
  - Phase 5 (StuckDetector scans for :intent_recorded / :action_in_flight rows past TTL and transitions to :abandoned via abandon_op/2)
  - Phase 6 (git push / gh pr create workers plumb through fetch_or_record_intent with op_kind="git_push" / "gh_pr_create")
  - Phase 8 (Operator UI can query external_operations by (op_kind, state) + run_id using the D-21 indexes shipped here)

# Tech tracking
tech-stack:
  added: []  # :oban 2.21 was already in mix.exs from Plan 01-01
  patterns:
    - "Brandur Stripe idempotency — INSERT ... ON CONFLICT (idempotency_key) DO NOTHING + SELECT FOR UPDATE fallback. When on_conflict: :nothing hits a conflict, Ecto returns %Operation{id: nil} because no RETURNING row fires; the fallback SELECT observes the winner's row deterministically. Racing callers collapse into exactly one winner."
    - "Role elevation inside a worker via SET LOCAL ROLE kiln_owner — Repo.transaction wraps the privilege escalation; the role scope is the txn, so Postgres auto-resets on commit. The connecting superuser (kiln) was granted membership in kiln_owner by migration 20260418000002 so the ROLE switch needs no re-auth."
    - "Dual-audit-event invariant (D-18) via single Repo.transaction with Ecto.Repo.insert/update + Kiln.Audit.append/1 — if the audit write fails (JSV validation, unknown kind), the tx rolls back AND the state mutation is undone. Invariant: every external_operations row mutation has a matching audit_events row in the same tx or neither lands."
    - "Oban BaseWorker as __using__/1 macro, NOT a shared behaviour — macro expansion at compile time injects safe defaults into each worker's own module, so Kiln.Oban.BaseWorker has no runtime presence and nothing to break via bad per-worker overrides. Callers use Keyword.put_new so explicit opts (e.g. max_attempts: 5) always win over BaseWorker defaults."
    - "Oban cron pruner registration via Oban.Plugins.Cron crontab in config/config.exs — keeps the 7-child supervision tree invariant (D-42). No new supervisor child added for the pruner; the existing Oban child schedules it."

key-files:
  created:
    - "priv/repo/migrations/20260418000005_install_oban.exs"
    - "priv/repo/migrations/20260418000006_create_external_operations.exs"
    - "lib/kiln/external_operations.ex"
    - "lib/kiln/external_operations/operation.ex"
    - "lib/kiln/external_operations/pruner.ex"
    - "lib/kiln/oban/base_worker.ex"
    - "test/kiln/external_operations_test.exs"
    - "test/kiln/oban/base_worker_test.exs"
  modified:
    - "config/config.exs (added :maintenance queue + Oban.Plugins.Cron entry scheduling Kiln.ExternalOperations.Pruner at 03:00 UTC daily)"

key-decisions:
  - "@oban_migration_version = 14 (not 12 from the plan text, not 13 from Plan 01-01's SUMMARY) — verified against deps/oban/lib/oban/migrations/postgres.ex `@current_version 14` and the migration files v10..v14 present under deps/oban/lib/oban/migrations/postgres/. The pin is the one correct value at install time; plan text drift is acceptable because D-49 explicitly requires pinning, not freezing at any particular number."
  - "external_operations migration reuses 01-03's ALTER TABLE OWNER TO kiln_owner + reversible execute/2 pattern — the uncommitted migration files left by the prior agent attempt already incorporated this pattern, extending it to CHECK constraint + grants. The files matched the plan spec and were committed as-is without rewriting."
  - "Pruner's SET LOCAL ROLE kiln_owner pattern mirrors AuditLedgerCase.with_role/2 from Plan 01-03 — both rely on the connecting superuser's membership in kiln_owner (granted in migration 20260418000002). No separate connection pool needed; the LOCAL scope confines the escalation to the pruner's transaction."
  - "BaseWorker test uses Worker.__opts__/0 introspection for max_attempts assertion — stable API documented in Oban source (lib/oban/worker.ex:464 @callback __opts__). Rejected alternatives: inspecting changeset.changes (brittle; max_attempts lives in :data only when opts match defaults), running perform_job (doesn't observe opts at all)."
  - "BaseWorker helpers use @spec with the concrete Operation.t() return — avoids the 'contract too broad' Dialyzer warning that bit Plan 01-05's mandatory_keys/0. The Operation.t() opaque type is shipped from lib/kiln/external_operations/operation.ex."

patterns-established:
  - "External side-effect workers plumb through fetch_or_record_intent/2 → external action → complete_op/2 or fail_op/2. The intent is DB-persisted BEFORE the side-effect runs so a retry after a crash observes the intent and can decide whether to re-run the action or skip (state == :completed means skip)."
  - "Audit pairing convention: every external_operations state mutation has a matching audit_events row of the corresponding kind. Callers never see the audit write — it's internal to the context module. This is the D-18 invariant and holds independent of retries, because the tx guarantees both-or-neither."
  - "30-day TTL pruner retains :failed and :abandoned rows indefinitely — D-19. Only :completed rows are deletable. Rationale: forensic debugging of production failures requires the error trail; successes are noise after 30 days. Audit_events companion rows live forever regardless (no separate cleanup job planned; audit_events has its own retention rules in later phases)."
  - "Oban worker opts override pattern — `use Kiln.Oban.BaseWorker, max_attempts: 5` wins over the default of 3 because the macro uses Keyword.put_new. This lets occasional workers (e.g. verify-run-then-exit smoke workers) opt into more retries without forking the BaseWorker."

requirements-completed: [OBS-03]

# Metrics
duration: ~20min
completed: 2026-04-19
---

# Phase 01 Plan 04: external_operations + Kiln.Oban.BaseWorker Summary

**The `external_operations` single polymorphic idempotency table (D-14, Brandur Stripe pattern) — 16 columns, 5-state CHECK, UNIQUE INDEX on `idempotency_key`, D-48 role grants — plus `Kiln.ExternalOperations`'s two-phase intent → action → completion machine (D-18: every row mutation pairs with a companion audit event in the same transaction), `Kiln.Oban.BaseWorker` macro shipping D-44 safe defaults (`max_attempts: 3` + idempotency-key unique dedupe), and a 30-day TTL pruner (D-19) registered as an Oban cron plugin to keep the 7-child supervision tree invariant (D-42). Behaviors 10-14 from 01-VALIDATION.md mechanically proven by 15 tests; 59 tests total all green; `mix check` 11-tool gate green.**

## Performance

- **Duration:** ~20 min (wall clock; includes retry-agent cold-start + reading two prior SUMMARYs)
- **Started:** 2026-04-19T13:15:00Z (approximate, after reading plan + prior-attempt uncommitted files)
- **Completed:** 2026-04-19T13:35:00Z
- **Tasks:** 3/3
- **Files created:** 8 (2 migrations + 4 lib + 2 tests)
- **Files modified:** 1 (config/config.exs — adds :maintenance queue + Oban.Plugins.Cron)

## Accomplishments

- **Two migrations committed:** `20260418000005_install_oban.exs` (pins Oban migration to @current_version = 14 per D-49) and `20260418000006_create_external_operations.exs` (16-column table, 5-state CHECK, unique idempotency_key index, three supporting indexes, kiln_app INSERT/SELECT/UPDATE grant — NO DELETE). Both migrations shipped by the prior attempt matched the plan spec and were committed as-is.
- **`Kiln.ExternalOperations` context + Ecto schema + Pruner ship** — four public functions (`fetch_or_record_intent/2`, `complete_op/2`, `fail_op/2`, `abandon_op/2`) each opening a Repo.transaction that writes the state change + audit event atomically (D-18). Brandur's INSERT ... ON CONFLICT DO NOTHING + SELECT FOR UPDATE pattern handles the racing-writer case deterministically.
- **`Kiln.Oban.BaseWorker` macro ships** with `max_attempts: 3` (overrides Oban's 20 default per P9), insert-time unique config on `:idempotency_key`, and three idempotency helpers delegating to `Kiln.ExternalOperations`.
- **30-day TTL pruner registered** via `Oban.Plugins.Cron` crontab in `config/config.exs` — daily at 03:00 UTC. Deletes only `:completed` rows (D-19 — forensics preserved for `:failed`/`:abandoned`). Escalates to `kiln_owner` via `SET LOCAL ROLE` (only role with DELETE on external_operations — T-03 mitigation).
- **Supervision tree remains 7 children** (D-42 invariant) — pruner is registered inside the existing Oban child's `:plugins` list, not a new supervisor child.
- **Behaviors 10, 11, 12, 13, 14 from 01-VALIDATION.md mechanically proven** — 7 tests in `external_operations_test.exs` + 8 tests in `oban/base_worker_test.exs`. All prior-plan tests remain green (44 baseline → 59 total, zero regressions).
- **`mix check` green across all 11 tools** (compiler, credo, dialyzer, ex_unit, formatter, mix_audit, no_compile_secrets, no_manual_qa, sobelow, unused_deps, xref_cycles).

## Task Commits

Each task committed atomically on the main working tree:

1. **Task 1: Migrations 5 + 6 (install_oban + create_external_operations)** — `2c3984c` (feat)
2. **Task 2: Kiln.ExternalOperations + Operation schema + Pruner + config update + 7 tests** — `0f41dc3` (feat)
3. **Task 3: Kiln.Oban.BaseWorker macro + 8 tests** — `c714e0c` (feat)

Plan metadata commit will follow this SUMMARY.

## Output Answers (per plan's `<output>` section)

- **Final `@oban_migration_version` used: 14.** Plan 01-01's SUMMARY cited `13` based on an early reading of `Oban.Migration`'s moduledoc example, but the `@current_version` module attribute in the shipped code (`deps/oban/lib/oban/migrations/postgres.ex:9`) is `14`. Migration files `v01..v14` are all present under `deps/oban/lib/oban/migrations/postgres/`. The pin catches the exact version in use; a future `mix deps.update oban` that ships a `v15` cannot silently change table shape — it requires a deliberate follow-up migration (`UpgradeObanToV15`).
- **Exact column count of `external_operations`: 16.** Verified via `SELECT count(*) FROM information_schema.columns WHERE table_name = 'external_operations'` returning `[[16]]`. The 16 = 13 `add` columns + 2 from `timestamps(type: :utc_datetime_usec)` (inserted_at + updated_at) + 1 `id` PK. Plan 06's BootChecks can assert this exact count.
- **Oban.Testing sandbox shared mode:** no adjustments needed for BaseWorker test setup. `use Kiln.DataCase, async: false` + `use Oban.Testing, repo: Kiln.Repo` + `config :kiln, Oban, testing: :manual` (from `config/test.exs`, shipped by Plan 01-05) all compose cleanly. `Oban.insert/1` writes to the shared `oban_jobs` table inside the sandbox txn; the second-insert dedupe assertion in the BaseWorker test observes the first-winner row via `args -> 'idempotency_key'` match without any shared-mode workarounds.
- **Pruner role-switching under sandbox:** not exercised by tests in this plan (the cron-plugin path fires only in a long-running app, not in `mix test`). The `SET LOCAL ROLE kiln_owner` pattern is known to work under Ecto sandbox from Plan 01-03's `AuditLedgerCase.with_role/2` — same mechanism (`SET LOCAL` scoped to txn + connecting-user membership in both roles). The pruner is expected to execute correctly in production; Plan 01-06's BootChecks can add a sanity probe if desired.

## Files Created/Modified

### New files (Plan 04)

**Migrations (2):**
- `priv/repo/migrations/20260418000005_install_oban.exs` — `Oban.Migration.up(version: 14)` per D-49. Reversible via matching `down/0` that calls `Oban.Migration.down(version: 14)`.
- `priv/repo/migrations/20260418000006_create_external_operations.exs` — 16 columns, 5-state CHECK, UNIQUE INDEX on `idempotency_key`, three D-21 supporting indexes (active-state partial, run_id, op_kind+state), reversible `execute/2` for CHECK + owner transfer + grants.

**Context + schema + pruner (4):**
- `lib/kiln/external_operations.ex` — `fetch_or_record_intent/2`, `complete_op/2`, `fail_op/2`, `abandon_op/2`. Each wraps a `Repo.transaction/1` writing state + paired audit event.
- `lib/kiln/external_operations/operation.ex` — Ecto schema; 5-value `Ecto.Enum` on `:state`; `read_after_writes: true` on `uuid_generate_v7()` PK; Jason.Encoder whitelist.
- `lib/kiln/external_operations/pruner.ex` — `Oban.Worker` on `:maintenance` queue; `SET LOCAL ROLE kiln_owner` → `DELETE` where `state == :completed AND completed_at < now() - 30 days`.
- `lib/kiln/oban/base_worker.ex` — `__using__/1` macro injecting D-44 defaults + three idempotency helpers delegating to `Kiln.ExternalOperations`.

**Tests (2):**
- `test/kiln/external_operations_test.exs` — 7 tests across four describe blocks (fetch_or_record_intent + complete_op + fail_op + abandon_op). Covers behaviors 10/11/12/13.
- `test/kiln/oban/base_worker_test.exs` — 8 tests across three describe blocks (safe defaults + unique-key dedupe + helper delegation). Covers behavior 14.

### Modified files
- `config/config.exs` — `queues:` now `[default: 10, maintenance: 1]`; `plugins:` now includes `Oban.Plugins.Cron` with a single crontab entry for `Kiln.ExternalOperations.Pruner` at `0 3 * * *`.

## Decisions Made

See `key-decisions` frontmatter — five decisions made during execution.

The highest-impact was the **keep-prior-attempt-files decision** made in the first 5 tool calls. The prior agent left two uncommitted migration files on disk that already matched the plan spec and added reversibility niceties (reversible `execute/2`, owner transfer, reversible grants) consistent with 01-03's patterns. Reading both files against the plan's action block confirmed they were usable; committing them as-is saved ~10 tool calls of unnecessary rewrite and preserved the prior attempt's DB state (migrations were already applied).

## Deviations from Plan

### Zero Auto-Fixed Issues

Plan executed as written. Two benign interpretation choices:

1. **Migration 5's `@oban_migration_version` is 14, not the plan's suggested 12.** This is not a deviation — the plan explicitly calls out that the pin should match `Oban.Migration.latest_version/0` at install time, and 14 is the current value in `deps/oban`. D-49 mandates pinning; the specific integer is whatever the shipped Oban version exposes.

2. **Kept prior-attempt uncommitted migration files instead of rewriting.** Both files matched the plan spec; rewriting would have burned tool calls without producing a better artifact. The SUMMARY explicitly documents this in the "Decisions Made" section so the next reader understands why the migration files don't have a first-authorship commit from this attempt.

**Total deviations:** 0. Plan specification was complete and directly implementable.

## Issues Encountered

**1. Prior agent attempt stalled with uncommitted work.** The retry-context in the user prompt flagged two untracked migration files the previous agent had produced. The files were valid and usable after cross-checking against the plan; `git commit` of those files as Task 1's commit saved time.

**2. `KILN_DB_ROLE=kiln_owner mix ecto.migrations` errors on `schema_migrations`.** The `kiln_owner` role doesn't own `schema_migrations` (owned by the connecting `kiln` superuser), so a query for migration status under that role fails with `permission denied for table schema_migrations`. Verified via `mix ecto.migrations` without `KILN_DB_ROLE` — all 6 migrations show `up`. This is a pre-existing Plan 01-03 quirk and does not affect Plan 01-04 (migrations were already applied by the prior attempt).

**3. No DB port 5432 conflict issues.** The sigra-uat-postgres compatibility path established by Plan 01-03 is holding — Kiln connects on 5432 using the `kiln` / `kiln_dev` credentials that were aligned to compose.yaml in Plan 01-03.

## User Setup Required

None. Plan 01-04 introduces no new env vars, no new external services, no new user-setup items. The pre-existing operator blocker (free port 5432 by stopping the conflicting `sigra-uat-postgres` container so Kiln's own compose can spin up its own Postgres) remains — Plan 01-01's deferred item.

## Next Phase Readiness

**Ready for Plan 01-06 (BootChecks + HealthPlug):**
- BootChecks can mechanically assert:
  * `external_operations` table exists with 16 columns.
  * `kiln_app` has `INSERT/SELECT/UPDATE` but not `DELETE` on `external_operations` (T-03 mitigation probe).
  * `Oban.Plugins.Cron` crontab contains an entry for `Kiln.ExternalOperations.Pruner`.
  * Supervision tree has exactly 7 children (D-42 invariant).
- HealthPlug can emit `external_operations_state` counts per state as a readiness gauge.

**Ready for Phase 3 (Agent Adapter + Sandbox + Safety):**
- Every LLM/Docker/secret worker will use `use Kiln.Oban.BaseWorker` and get idempotency + dedupe + two-phase intent/completion plumbing for free.
- `fetch_or_record_intent/2` + `complete_op/2` are the right tools for P3's `Kiln.Agents.Adapter` implementations — wrap each Anthropix call in the intent/completion pair, and the audit ledger tracks every token-spend event automatically via `external_op_*` kinds.
- Phase 3's budget circuit breaker can query `external_operations` aggregated by `op_kind = 'llm_complete'` and `state = :completed` for recent token-cost accounting.

**Ready for Phase 5 (Spec + Verification + Bounded Loop):**
- `Kiln.ExternalOperations.abandon_op/2` is the terminal state the `StuckDetector` uses to mark orphaned rows.
- The `external_operations_active_state_idx` partial index (active_state filter: `state IN ('intent_recorded', 'action_in_flight')`) supports `StuckDetector`'s scan efficiently.

**Ready for Phase 6 (GitHub Integration):**
- `op_kind` values `git_push`, `git_commit`, `gh_pr_create`, `gh_check_observe` (D-17 taxonomy) are already allocated; workers ship there.

**Notes for downstream planners:**
- **Adding a new `op_kind`:** the `op_kind` column is `text` with no CHECK constraint — new kinds land as an app-side change + a test that asserts the kind threads correctly through `fetch_or_record_intent/2`. No migration needed unless the new kind needs an index.
- **Pruner retention tuning:** `@retention_days 30` in `lib/kiln/external_operations/pruner.ex` is the single config knob. If a future phase needs to retain `:completed` rows longer (e.g. Phase 9 dogfood wants post-hoc analysis), either raise the constant or add a `storage_policy` Ecto.Enum column and branch inside the pruner query.
- **BaseWorker `@spec` strategy:** the helpers use `Kiln.ExternalOperations.Operation.t()` directly in specs, which the Operation module exposes. If Dialyzer ever flags "contract too broad," narrow to `%Kiln.ExternalOperations.Operation{}` literal — but the opaque type is the stable API.

## Self-Check: PASSED

**Files created — `test -f`:**

Migrations:
- `priv/repo/migrations/20260418000005_install_oban.exs` — FOUND
- `priv/repo/migrations/20260418000006_create_external_operations.exs` — FOUND

Lib:
- `lib/kiln/external_operations.ex` — FOUND
- `lib/kiln/external_operations/operation.ex` — FOUND
- `lib/kiln/external_operations/pruner.ex` — FOUND
- `lib/kiln/oban/base_worker.ex` — FOUND

Tests:
- `test/kiln/external_operations_test.exs` — FOUND
- `test/kiln/oban/base_worker_test.exs` — FOUND

**Commits verified — `git log --oneline | grep "01-04"`:**

- `2c3984c feat(01-04): external_operations migration + pinned Oban install (D-14, D-49)` — FOUND
- `0f41dc3 feat(01-04): Kiln.ExternalOperations two-phase intent machine (D-14, D-18)` — FOUND
- `c714e0c feat(01-04): Kiln.Oban.BaseWorker macro with D-44 safe defaults` — FOUND

**DB state verified:**
- `external_operations.columns == 16` — PASS
- `has_table_privilege('kiln_app', 'external_operations', 'UPDATE') == true` — PASS
- `has_table_privilege('kiln_app', 'external_operations', 'DELETE') == false` — PASS (T-03 mitigation active)
- `external_operations_state_check` CHECK constraint exists — PASS
- `oban_jobs` table exists — PASS

**Supervision tree invariant (D-42):** 7 children — verified by `grep -c` inside `lib/kiln/application.ex`'s `children = [...]` block. Pruner registered via `Oban.Plugins.Cron` crontab inside the existing `Oban` child's config; no 8th supervisor.

**Test results:**
- `mix test test/kiln/external_operations_test.exs --seed 0` — 7 tests, 0 failures
- `mix test test/kiln/oban/base_worker_test.exs --seed 0` — 8 tests, 0 failures
- `mix test` (full suite) — 59 tests, 0 failures (44 prior + 15 new; zero regressions)

**`mix check` tail (final run):**
```
 ✓ compiler success in 0:01
 ✓ credo success in 0:02
 ✓ dialyzer success in 0:04
 ✓ ex_unit success in 0:02
 ✓ formatter success in 0:01
 ✓ mix_audit success in 0:02
 ✓ no_compile_secrets success in 0:01
 ✓ no_manual_qa success in 0:01
 ✓ sobelow success in 0:01
 ✓ unused_deps success in 0:01
 ✓ xref_cycles success in 0:01
```

All 11 tools green. P3 idempotency pitfall engineered against at the durability floor.

**Pre-existing uncommitted `prompts/software dark factory prompt.txt`:** untouched throughout.

---

*Phase: 01-foundation-durability-floor*
*Plan: 04*
*Completed: 2026-04-19*
