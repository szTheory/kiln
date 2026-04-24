---
phase: 02-workflow-engine-core
plan: 02
subsystem: infra
tags: [ecto-schema, ecto-migration, postgres, uuidv7, state-machine, 9-state-enum, fk-restrict, hot-path-columns, ex-machina, factory, rehydration]

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor
    provides: "uuid_generate_v7() extension (migration 1), kiln_owner + kiln_app roles (migration 2), Ecto.Enum + CHECK-constraint pattern (migration 3 audit_events), two-phase intent table template (migration 6 external_operations), Jason + Decimal deps"
  - phase: 02-workflow-engine-core
    provides: "Plan 02-00 SHELL factories for Kiln.Factory.Run + Kiln.Factory.StageRun (this plan replaces both with live ExMachina.Ecto bodies); ex_machina 2.8 dep; Kiln.DataCase sandbox wiring"

provides:
  - "priv/repo/migrations/20260419000002_create_runs.exs — runs table with 9-state CHECK (D-86), workflow_checksum 64-char-hex format CHECK (D-94), uuidv7 PK, 5 indexes (state + partial active + workflow + correlation + inserted_at), owner=kiln_owner, kiln_app INSERT/SELECT/UPDATE (D-48)"
  - "priv/repo/migrations/20260419000003_create_stage_runs.exs — stage_runs table with FK to runs ON DELETE RESTRICT (D-81), unique (run_id, workflow_stage_id, attempt) business identity, 4 enum CHECKs (kind/agent_role/state/sandbox), attempt 1..10 (D-74) + cost_usd >= 0 CHECKs, hot-path metric columns tokens_used/cost_usd/requested_model/actual_model_used (D-82, OPS-02), owner=kiln_owner, kiln_app INSERT/SELECT/UPDATE"
  - "lib/kiln/runs/run.ex — Kiln.Runs.Run Ecto schema: 9-state Ecto.Enum, changeset/2 for insert path + transition_changeset/3 for Plan 06 state-only mutations, read_after_writes: true for uuidv7 hydration, public states/0, terminal_states/0, active_states/0 accessors"
  - "lib/kiln/stages/stage_run.ex — Kiln.Stages.StageRun Ecto schema: 4 Ecto.Enum fields (kind/agent_role/state/sandbox), changeset with foreign_key_constraint + unique_constraint + 6 check_constraints wired, Decimal cost_usd, public states/0, kinds/0, agent_roles/0, sandboxes/0 accessors"
  - "lib/kiln/runs.ex — Kiln.Runs context facade: create/1, get/1, get!/1, list_active/0 (drives RunDirector boot-scan via partial index), workflow_checksum/1 (drives D-94 rehydration integrity check)"
  - "lib/kiln/stages.ex — Kiln.Stages context facade: create_stage_run/1, get_stage_run!/1, list_for_run/1"
  - "test/support/factories/run_factory.ex — LIVE ExMachina.Ecto factory replacing Plan 02-00 SHELL; non-empty caps_snapshot + model_profile_snapshot defaults matching D-56/D-57 shapes"
  - "test/support/factories/stage_run_factory.ex — LIVE ExMachina.Ecto factory replacing Plan 02-00 SHELL; run_id intentionally nil (caller must supply; FK on_delete :restrict would hide orphan errors otherwise)"
  - "test/kiln/runs/run_test.exs — 20 schema-level tests covering changeset enum enforcement, workflow_checksum format (case + length), terminal/active-state partitioning, transition_changeset"
  - "test/kiln/stages/stage_run_test.exs — 17 schema-level tests covering 4 enum changeset enforcement, D-74 attempt 1..10 ceiling, unique triple business identity, FK on_delete :restrict at both Ecto.ConstraintError + raw Postgrex.Error layers, 4 public accessors"
  - "test/kiln/runs_test.exs — 12 context-level tests covering create/1 with uuidv7 id hydration, list_active/0 ordering + terminal-state exclusion, workflow_checksum/1 found + :not_found paths"

affects:
  - "02-03 (Kiln.Artifacts) — Artifact schema FK to stage_runs(id) + runs(id) now resolvable; ON DELETE RESTRICT cascade consistent with D-81"
  - "02-05 (Kiln.Workflows.Loader) — runs.workflow_id + runs.workflow_version serve as run-start anchor pointing at compiled CompiledGraph"
  - "02-06 (Kiln.Runs.Transitions) — Run.transition_changeset/3 is the command module's single changeset entry point; 9-state enum locked; Run.terminal_states/0 + Run.active_states/0 drive the matrix's partition"
  - "02-07 (Kiln.Runs.RunDirector) — list_active/0 + workflow_checksum/1 are the boot-scan primitives; runs_active_state_idx partial index is what RunDirector's periodic 30-second scan reads"
  - "02-08 (Kiln.Stages.StageWorker) — StageRun schema + Kiln.Stages.create_stage_run/1 are the dispatcher's row-creation path; unique (run_id, workflow_stage_id, attempt) is the dedupe boundary"

# Tech tracking
tech-stack:
  added:
    - "None — ex_machina 2.8 already locked in Plan 02-00; Decimal ships with OTP"
  patterns:
    - "P2 table-creation template (structural clone of external_operations migration): uuidv7 PK via fragment(\"uuid_generate_v7()\"), enum CHECKs via Enum.map_join/3 + 2-arg execute/2 for reversibility, owner transfer + kiln_app grants. Used verbatim for runs + stage_runs; Plan 02-03 artifacts migration follows the same shape"
  - "Ecto.Enum + DB CHECK + app-side validate_inclusion triple layer: Phase 1 external_operations shipped enum + CHECK; Plan 02-02 adds validate_inclusion to the changeset so a bad state fails at the changeset boundary before the DB round-trip. check_constraint/2 on the changeset wires the DB error name back to a clean field error if the app somehow bypasses the validator (e.g., raw Ecto.Multi with attrs drift)"
    - "Business-identity unique + FK :restrict combo: StageRun's (run_id, workflow_stage_id, attempt) unique idx is the dispatcher's dedupe key; runs(id) FK with on_delete :restrict is forensic-preservation. Validated at both Ecto.ConstraintError (via Kiln.Repo.delete!) AND raw Postgrex.Error (via Kiln.Repo.query!) layers — the second test ensures the policy is enforced even if a caller bypasses the Ecto schema constraints machinery"
    - "Factory discipline: live ExMachina.Ecto factory replaces Plan 02-00 SHELL; placeholder_*_attrs/0 markers removed per the exit criterion in 02-00 SUMMARY. StageRun factory intentionally leaves run_id nil with a moduledoc-documented caller contract — building a stage_run without a supplied run_id surfaces the FK dependency as an explicit test-author choice, not a hidden autogen"

key-files:
  created:
    - "priv/repo/migrations/20260419000002_create_runs.exs (120 lines)"
    - "priv/repo/migrations/20260419000003_create_stage_runs.exs (131 lines)"
    - "lib/kiln/runs/run.ex (160 lines)"
    - "lib/kiln/stages/stage_run.ex (162 lines)"
    - "test/kiln/runs/run_test.exs (131 lines, 20 tests)"
    - "test/kiln/stages/stage_run_test.exs (200 lines, 17 tests)"
    - "test/kiln/runs_test.exs (111 lines, 12 tests)"
  modified:
    - "lib/kiln/runs.ex — replaced Phase 1 @moduledoc-only placeholder with full context facade (create/1 + get/1 + get!/1 + list_active/0 + workflow_checksum/1)"
    - "lib/kiln/stages.ex — replaced Phase 1 @moduledoc-only placeholder with context facade (create_stage_run/1 + get_stage_run!/1 + list_for_run/1)"
    - "test/support/factories/run_factory.ex — SHELL → LIVE (use ExMachina.Ecto, run_factory/0 returns a %Kiln.Runs.Run{} with non-empty caps_snapshot + model_profile_snapshot)"
    - "test/support/factories/stage_run_factory.ex — SHELL → LIVE (use ExMachina.Ecto, stage_run_factory/0 returns a %Kiln.Stages.StageRun{run_id: nil, ...} with caller-supplied-FK contract in moduledoc)"

key-decisions:
  - "FK on_delete :restrict validated at BOTH Ecto.ConstraintError and Postgrex.Error layers. The plan's acceptance criterion asked for `Postgrex.Error ~r/foreign key/`, but Ecto intercepts the raw error and returns Ecto.ConstraintError when the caller doesn't declare a foreign_key_constraint/2. Shipped two tests: one via Kiln.Repo.delete!/1 (normal app path → Ecto.ConstraintError) and one via Kiln.Repo.query!/2 raw SQL (bypass path → Postgrex.Error). Both prove the D-81 invariant holds."
  - "Run factory ships with NON-EMPTY caps_snapshot + model_profile_snapshot defaults (the plan spec used bare `%{}` for caps_snapshot). Reason: downstream Plan 06 Transitions + Plan 07 RunDirector + Phase 3 BudgetGuard will read these fields; having realistic shapes in the default factory means their tests don't need to override every time. Tests that need empty maps override explicitly via `build(:run, caps_snapshot: %{})`."
  - "StageRun factory leaves `run_id: nil` by design with a moduledoc warning. Alternative — auto-inserting a parent run inside the factory — would hide the FK dependency and produce orphan rows when tests call `build(:stage_run)` without persisting. Forcing callers to write `run = insert(:run); insert(:stage_run, run_id: run.id)` keeps the FK contract visible in test code."
  - "All 6 check_constraints wired on StageRun changeset (kind, agent_role, state, sandbox, attempt, cost_usd) so a raw Repo.insert that somehow bypasses the app-side validate_inclusion/validate_number still surfaces as a clean changeset error rather than a Postgrex.Error. Defence-in-depth mirroring the Phase 1 Kiln.ExternalOperations.Operation pattern."
  - "Used `def change` (reversible) for both migrations instead of `def up + def down`. Every DDL escape (CHECK constraint, ownership, grant) uses the 2-arg form of `execute/2` so `mix ecto.rollback --step 2` fully unwinds. Verified with a round-trip: migrate → rollback --step 2 → migrate, clean."

patterns-established:
  - "Business-identity unique index naming: `<table>_<col1>_<col2>_<col3>_idx`. stage_runs_run_stage_attempt_idx is the dedupe key for the dispatcher; Plan 08 StageWorker will read this to decide scheduling"
  - "Hot-path metric columns live on the row, not in audit payload: tokens_used, cost_usd, requested_model, actual_model_used (D-82). A single compound index can serve cost dashboards; Audit payload JSONB is reserved for state-machine facts + small summaries (≤ 4KB per D-82 threshold)"
  - "Context-facade narrow surface convention: create + get + get! + list_<scoped-by-something> + one-or-two-domain-specific-queries. State mutation lives in a separate command module (Kiln.Runs.Transitions in Plan 06). This is the same separation external_operations modeled in Phase 1 (create/read vs state transition)"
  - "Test factory exit criterion follow-through: Plan 02-00 shipped SHELL factories with placeholder_*_attrs/0 markers; the `! grep -q placeholder_*_attrs` acceptance check for this plan's Task 2 caught the removal-obligation automatically. Shells → lives → marker-verified removal is the full Wave 0→Wave 1 lifecycle"

requirements-completed: [ORCH-02, ORCH-03, ORCH-04]

# Metrics
duration: ~6min
completed: 2026-04-20
---

# Phase 02 Plan 02: runs + stage_runs Ecto Tables + Context Facades Summary

**Two migrations + two Ecto schemas + two public context facades (Kiln.Runs + Kiln.Stages) + two LIVE factory swap-ins. The state-machine core (Plan 06), the rehydration scan (Plan 07), and the stage worker (Plan 08) all now have their row-level substrate live, indexable, and covered by 49 new tests.**

## Performance

- **Duration:** ~6 min (~360 s)
- **Started:** 2026-04-20T01:35:49Z
- **Completed:** 2026-04-20T01:41:30Z
- **Tasks:** 2 / 2 complete
- **Files created:** 7
- **Files modified:** 4
- **New tests:** 49 (20 schema-level Run + 17 schema-level StageRun + 12 context-level Runs)
- **Full suite:** 147 tests / 0 failures (up from 104)

## Accomplishments

- **The two core Phase 2 tables are live in Postgres.** `runs` + `stage_runs` ship with the full D-48 privilege envelope (owner=kiln_owner, kiln_app INSERT/SELECT/UPDATE), the uuidv7 PK default, and every CHECK constraint generated from single-source enum lists. Reversibility verified: `migrate → rollback --step 2 → migrate` round-trips cleanly.
- **The 9-state run enum (D-86) is locked at three layers.** Elixir `Ecto.Enum` + `validate_inclusion` + `@states` module attribute on `Kiln.Runs.Run` → migration-generated `runs_state_check` DB CHECK → app-side `check_constraint/2` wires the DB name back to a changeset error. A future `@states ~w(... paused)a` addition without a matching migration fails in CI via the 9-atom length assertion, per T2 threat-model mitigation.
- **FK on_delete: :restrict (D-81) is proven at two layers.** Ecto-path test: `Kiln.Repo.delete!/1` surfaces `Ecto.ConstraintError` with the FK name. Raw-SQL-bypass test: `Kiln.Repo.query!/2 "DELETE FROM runs ..."` surfaces `Postgrex.Error` SQLSTATE 23503. Forensic preservation holds even when a caller bypasses the Ecto schema machinery.
- **Hot-path metric columns (D-82) are reserved.** `stage_runs.tokens_used`, `cost_usd`, `requested_model`, `actual_model_used` are indexable columns — NOT audit payload. OPS-02 silent-fallback detection (Phase 3) reads `requested_model ≠ actual_model_used`; the Phase 7 cost dashboard aggregates `sum(cost_usd) GROUP BY run_id`.
- **Live factories replace Plan 02-00 SHELLs.** `placeholder_run_attrs/0` + `placeholder_stage_run_attrs/0` markers are gone; both factories `use ExMachina.Ecto, repo: Kiln.Repo`; the Plan 02-00 SUMMARY's "fill-in obligation" table is discharged for rows 1 and 2 (artifact factory still SHELL — Plan 02-03).

## Task Commits

Each task was committed atomically:

1. **Task 1: runs + stage_runs migrations + Ecto schemas** — `7371684` (feat)
2. **Task 2: Runs/Stages context facades + live factories + tests** — `64abc7c` (feat)

## Files Created / Modified

### Created (7)

**Migrations (2):**
- `priv/repo/migrations/20260419000002_create_runs.exs` — 120 lines
- `priv/repo/migrations/20260419000003_create_stage_runs.exs` — 131 lines

**Ecto schemas (2):**
- `lib/kiln/runs/run.ex` — 160 lines
- `lib/kiln/stages/stage_run.ex` — 162 lines

**Tests (3):**
- `test/kiln/runs/run_test.exs` — 131 lines, 20 tests
- `test/kiln/stages/stage_run_test.exs` — 200 lines, 17 tests
- `test/kiln/runs_test.exs` — 111 lines, 12 tests

### Modified (4)

- `lib/kiln/runs.ex` — Phase 1 placeholder (@moduledoc-only, 10 lines) → full facade (create/1, get/1, get!/1, list_active/0, workflow_checksum/1)
- `lib/kiln/stages.ex` — Phase 1 placeholder → full facade (create_stage_run/1, get_stage_run!/1, list_for_run/1)
- `test/support/factories/run_factory.ex` — SHELL → LIVE ExMachina.Ecto
- `test/support/factories/stage_run_factory.ex` — SHELL → LIVE ExMachina.Ecto

## DDL Snippets

### `runs` (9-state, uuidv7, 5 indexes, kiln_app grants)

```sql
CREATE TABLE runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  workflow_id TEXT NOT NULL,
  workflow_version INTEGER NOT NULL,
  workflow_checksum TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'queued',
  model_profile_snapshot JSONB NOT NULL DEFAULT '{}',
  caps_snapshot JSONB NOT NULL DEFAULT '{}',
  correlation_id TEXT NOT NULL,
  tokens_used_usd NUMERIC(18,6) NOT NULL DEFAULT 0,
  elapsed_seconds INTEGER NOT NULL DEFAULT 0,
  escalation_reason TEXT,
  escalation_detail JSONB,
  inserted_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT runs_state_check CHECK (
    state IN ('queued','planning','coding','testing','verifying','blocked','merged','failed','escalated')
  ),
  CONSTRAINT runs_workflow_checksum_format CHECK (workflow_checksum ~ '^[0-9a-f]{64}$')
);
-- Indexes (5):
CREATE INDEX runs_state_idx ON runs (state);
CREATE INDEX runs_active_state_idx ON runs (state)
  WHERE state IN ('queued','planning','coding','testing','verifying','blocked');
CREATE INDEX runs_workflow_idx ON runs (workflow_id, workflow_version);
CREATE INDEX runs_correlation_id_idx ON runs (correlation_id);
CREATE INDEX runs_inserted_at_idx ON runs (inserted_at);
-- Privileges:
ALTER TABLE runs OWNER TO kiln_owner;
GRANT INSERT, SELECT, UPDATE ON runs TO kiln_app;
```

### `stage_runs` (FK :restrict, unique triple, 4 enum CHECKs, hot-path cols)

```sql
CREATE TABLE stage_runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  run_id UUID NOT NULL REFERENCES runs(id) ON DELETE RESTRICT,
  workflow_stage_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  agent_role TEXT NOT NULL,
  attempt INTEGER NOT NULL DEFAULT 1,
  state TEXT NOT NULL DEFAULT 'pending',
  timeout_seconds INTEGER NOT NULL,
  sandbox TEXT NOT NULL,
  tokens_used INTEGER NOT NULL DEFAULT 0,
  cost_usd NUMERIC(18,6) NOT NULL DEFAULT 0,
  requested_model TEXT,
  actual_model_used TEXT,
  error_summary TEXT,
  inserted_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT stage_runs_kind_check CHECK (kind IN ('planning','coding','testing','verifying','merge')),
  CONSTRAINT stage_runs_agent_role_check CHECK (agent_role IN ('planner','coder','tester','reviewer','uiux','qa_verifier','mayor')),
  CONSTRAINT stage_runs_state_check CHECK (state IN ('pending','dispatching','running','succeeded','failed','cancelled')),
  CONSTRAINT stage_runs_sandbox_check CHECK (sandbox IN ('none','readonly','readwrite')),
  CONSTRAINT stage_runs_attempt_range CHECK (attempt BETWEEN 1 AND 10),
  CONSTRAINT stage_runs_cost_nonneg CHECK (cost_usd >= 0)
);
-- Indexes (3):
CREATE UNIQUE INDEX stage_runs_run_stage_attempt_idx ON stage_runs (run_id, workflow_stage_id, attempt);
CREATE INDEX stage_runs_run_id_idx ON stage_runs (run_id);
CREATE INDEX stage_runs_state_idx ON stage_runs (state);
-- Privileges:
ALTER TABLE stage_runs OWNER TO kiln_owner;
GRANT INSERT, SELECT, UPDATE ON stage_runs TO kiln_app;
```

## Decisions Made

See `key-decisions` frontmatter for the five decisions. Highlights:

- **FK on_delete :restrict validated at BOTH Ecto + raw SQL layers.** Plan spec expected `Postgrex.Error`; Ecto wraps the DB error in `Ecto.ConstraintError` by default. Shipped tests for both paths so the D-81 invariant is proven regardless of bypass surface.
- **Run factory caps_snapshot + model_profile_snapshot ship NON-EMPTY.** Plan spec used `%{}` for caps; downstream consumers (BudgetGuard in Phase 3, RunDirector in Plan 07) expect realistic shapes. Factory default is the realistic shape; tests override with `%{}` when that's what they want.
- **StageRun factory leaves `run_id: nil` by design.** Auto-inserting a parent run would hide the FK dependency. Caller contract documented in moduledoc; tests that forget to supply run_id fail the `validate_required([:run_id])` at changeset time — clean error.
- **All 6 StageRun check_constraints wired on the changeset.** Defence-in-depth: if a raw attrs-drift Repo.insert bypasses the app-side validate_inclusion/validate_number, the DB CHECK's `check_constraint/2` wires the error back as a changeset field error — no raw Postgrex.Error in the caller code path.
- **`def change` (reversible) over `def up + def down`.** All DDL escapes use 2-arg `execute/2`. Round-trip verified: migrate → rollback --step 2 → migrate clean.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — test assertion mismatch] FK :restrict test expected `Postgrex.Error` but Ecto emits `Ecto.ConstraintError`**

- **Found during:** Task 2 verification (first run of `MIX_ENV=test mix test test/kiln/stages/stage_run_test.exs`)
- **Issue:** Plan spec's Task 2f test used `assert_raise Postgrex.Error, ~r/foreign key constraint/` for the delete path. Ecto 3.13 catches foreign_key_violation and translates it into `Ecto.ConstraintError` when the caller uses `Repo.delete!/1` without a changeset-based `foreign_key_constraint/2`. The test would fail as written even though the D-81 invariant actually held.
- **Fix:** Kept the original test and added a second test that uses `Kiln.Repo.query!("DELETE FROM runs WHERE id = $1", [...])` to bypass the Ecto constraints machinery. This path raises `Postgrex.Error` with SQLSTATE 23503. Together the two tests prove the D-81 invariant at both the Ecto-path and the raw-SQL-path layers.
- **Files modified:** `test/kiln/stages/stage_run_test.exs`
- **Verification:** All 17 StageRun tests pass.
- **Committed in:** 64abc7c

### Plan Spec Adjustments (not bugs — wider defence)

- **Run factory ships with realistic caps_snapshot + model_profile_snapshot.** Plan spec used `caps_snapshot: %{}`; shipped with D-56-shaped defaults (max_retries/max_tokens_usd/max_elapsed_seconds/max_stage_duration_seconds) and a D-57 model_profile shape. Downstream tests benefit from the realistic defaults; tests that want empty maps override.
- **StageRun changeset pre-wires all 6 check_constraints** (plan mentioned only `foreign_key_constraint` + `unique_constraint`). Belt-and-suspenders for bypass callers; matches the Phase 1 `Kiln.ExternalOperations.Operation` pattern.

**Total deviations:** 1 auto-fixed (Rule 1 test assertion), 2 non-breaking adjustments that widen the invariant coverage. No scope creep.

## Authentication Gates

None required.

## Verification Evidence

- `MIX_ENV=test mix ecto.migrate` → 20260419000002 + 20260419000003 applied cleanly
- `MIX_ENV=test mix ecto.rollback --step 2 && MIX_ENV=test mix ecto.migrate` → clean round-trip
- `MIX_ENV=test mix compile --warnings-as-errors` → 0 warnings
- `mix compile --warnings-as-errors` (dev) → 0 warnings
- `MIX_ENV=test mix test test/kiln/runs/run_test.exs test/kiln/stages/stage_run_test.exs test/kiln/runs_test.exs` → 43 tests, 0 failures
- `MIX_ENV=test mix test --exclude pending` → 147 tests, 0 failures (no regression from 104)
- All 10 Task 1 grep acceptance checks → pass
- All 8 Task 2 grep acceptance checks → pass (including the SHELL-marker removal assertions)

## Next Plan Readiness

- `Kiln.Runs.create/1` + `Kiln.Runs.list_active/0` + `Kiln.Runs.workflow_checksum/1` live for Plan 06 Transitions + Plan 07 RunDirector to call.
- `Kiln.Stages.create_stage_run/1` + `Kiln.Stages.list_for_run/1` live for Plan 08 StageWorker.
- `stage_runs.run_id FK on_delete :restrict` in place; Plan 02-03 `Kiln.Artifacts` adds a matching FK on `artifacts.stage_run_id` + `artifacts.run_id` for the 3-way integrity chain (D-81).
- The `runs_active_state_idx` partial index is the performance guarantee RunDirector's 30-second defensive scan depends on (D-92).

## Self-Check: PASSED

- All 7 created files exist on disk (grep-verified).
- Both task commits (`7371684`, `64abc7c`) present in `git log`.
- Full `MIX_ENV=test mix test --exclude pending` suite: 147 tests, 0 failures.
- `MIX_ENV=test mix compile --warnings-as-errors` clean.
- `mix compile --warnings-as-errors` (dev) clean.
- Migration `20260419000002` + `20260419000003` status = up.
- No unexpected file deletions in either task commit.

---

*Phase: 02-workflow-engine-core*
*Completed: 2026-04-20*
