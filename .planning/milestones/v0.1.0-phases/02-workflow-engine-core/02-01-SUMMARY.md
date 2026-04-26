---
phase: 02-workflow-engine-core
plan: 01
subsystem: infra
tags: [jsv, json-schema, jsv-2020-12, yaml, audit, ecto-migration, workflow, stage-contract, schema-registry, event-kind-taxonomy]

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor
    provides: Kiln.Audit.SchemaRegistry compile-time JSV build pattern, Kiln.Audit.EventKind 22-kind SSOT, audit_events_event_kind_check CHECK constraint pattern, JSV 0.18 / Jason / yaml_elixir deps
  - phase: 02-workflow-engine-core
    provides: Plan 02-00 test fixtures (minimal_two_stage.yaml, signature_populated.yaml) consumed by the SchemaRegistry test; ex_machina dep for factories (not used directly in this plan)

provides:
  - "priv/workflow_schemas/v1/workflow.json — D-55..D-59 top-level dialect (apiVersion const kiln.dev/v1, id regex, caps 4 keys, model_profile 6-value enum, stages array with $defs.stage requiring id/kind/agent_role/depends_on/timeout_seconds/retry_policy/sandbox + optional model_preference/on_failure)"
  - "priv/stage_contracts/v1/{planning,coding,testing,verifying,merge}.json — D-74 stage-input envelope (run_id/stage_run_id/attempt/spec_ref/budget_remaining/model_profile_snapshot/holdout_excluded + one kind-specific artifact_ref field per schema)"
  - "priv/audit_schemas/v1/{stage_input_rejected,artifact_written,integrity_violation}.json — D-85 Phase 2 audit payload shapes (payload-only matching Phase 1 convention)"
  - "Kiln.Audit.EventKind taxonomy extended 22 -> 25 (D-85); append-only ordering preserved"
  - "priv/repo/migrations/20260419000001_extend_audit_event_kinds.exs — drops + re-adds audit_events_event_kind_check with 25 kinds; reversible (rollback re-adds original 22-kind CHECK from hard-coded list)"
  - "Kiln.Workflows.SchemaRegistry — compile-time JSV build for priv/workflow_schemas/v1/*.json; fetch/1 + kinds/0 public API; formats: true enabled"
  - "Kiln.Stages.ContractRegistry — compile-time JSV build for priv/stage_contracts/v1/*.json; fetch/1 + kinds/0 public API; formats: true enabled"
  - "test/kiln/audit/event_kind_test.exs updated: asserts length 25, 3 new atoms present, append-only ordering intact"
  - "test/kiln/workflows/schema_registry_test.exs + test/kiln/stages/contract_registry_test.exs — kinds/fetch unit tests + positive / negative JSV-validation smoke for the new schemas"

affects:
  - "02-02 (workflow loader — consumes Kiln.Workflows.SchemaRegistry.fetch(:workflow) at YAML load boundary)"
  - "02-03 (Kiln.Artifacts — writes :artifact_written + :integrity_violation audit events; CAS integrity-on-read enforced via new payload schemas)"
  - "02-05 (Kiln.Stages.StageWorker — consumes Kiln.Stages.ContractRegistry.fetch(kind) at perform/1 boundary for D-76 input-rejection defence)"
  - "02-06 (Kiln.Runs.Transitions — emits :run_state_transitioned via Kiln.Audit; no new kinds here but the 25-kind CHECK must be live)"
  - "02-07 (Kiln.Runs.RunDirector — may emit :escalation_triggered for rehydration failure; unchanged CHECK surface)"
  - "02-08 (end-to-end tests exercise :artifact_written + :stage_input_rejected paths built on this plan's schemas)"

# Tech tracking
tech-stack:
  added:
    - "None (no new runtime deps — JSV 0.18 + Jason + yaml_elixir 2.12 shipped in P1)"
  patterns:
    - "Compile-time JSV registry pattern extended to two new kinds: Kiln.Workflows.SchemaRegistry + Kiln.Stages.ContractRegistry both use @external_resource + @kinds module attr + compile-time for-loop into %{kind => JSV.Root.t() | :missing}. Verbatim copy of Kiln.Audit.SchemaRegistry (P1) with dir/kinds swap + formats: true addition"
    - "Payload-only audit schema convention preserved for the 3 new D-85 kinds. Every priv/audit_schemas/v1/*.json describes ONLY the `payload` object; Kiln.Audit.append/1 passes `Map.get(attrs, :payload, %{})` to JSV.validate. Full event envelope is validated by Ecto.Changeset (cast+validate_required) not JSV"
    - "Migration down/0 hard-codes the previous SSOT state rather than reading the module attribute. The Elixir module is always compiled to the current source, so reading EventKind.values/0 at rollback time would observe 25 atoms and make the down re-add a silent no-op. Pattern: migrations that extend an SSOT must snapshot the prior state inline for reversibility"
    - "JSV build opts include formats: true for new registries. Phase 1's Kiln.Audit.SchemaRegistry was shipped without this and does NOT enforce `\"format\": \"uuid\"` etc. Phase 2 registries opt in; workflow authors and stage-input producers get real format validation. RESEARCH.md correction #1 / STACK.md D-100 flagged this as a retroactive P1 fix candidate (deferred to a future plan)"

key-files:
  created:
    - "priv/workflow_schemas/v1/workflow.json (191 lines) — D-55..D-59 canonical workflow dialect"
    - "priv/stage_contracts/v1/planning.json (77 lines) — planning envelope + last_diagnostic_ref"
    - "priv/stage_contracts/v1/coding.json (72 lines) — coding envelope + plan_ref"
    - "priv/stage_contracts/v1/testing.json (72 lines) — testing envelope + code_ref"
    - "priv/stage_contracts/v1/verifying.json (72 lines) — verifying envelope + test_output_ref; holdout_excluded is `type: boolean` (not const true) per D-74"
    - "priv/stage_contracts/v1/merge.json (72 lines) — merge envelope + verifier_verdict_ref"
    - "priv/audit_schemas/v1/stage_input_rejected.json (20 lines) — D-76 boundary-rejection payload"
    - "priv/audit_schemas/v1/artifact_written.json (15 lines) — D-80 CAS-write payload"
    - "priv/audit_schemas/v1/integrity_violation.json (15 lines) — D-84 integrity-mismatch payload"
    - "lib/kiln/workflows/schema_registry.ex (73 lines) — compile-time JSV registry for workflow.json"
    - "lib/kiln/stages/contract_registry.ex (73 lines) — compile-time JSV registry for 5 stage contracts"
    - "priv/repo/migrations/20260419000001_extend_audit_event_kinds.exs (76 lines) — reversible CHECK-constraint extension 22 -> 25"
    - "test/kiln/workflows/schema_registry_test.exs (52 lines) — kinds/fetch + positive-validation smoke + signature-null boundary documentation"
    - "test/kiln/stages/contract_registry_test.exs (125 lines) — 5-kind fetch + envelope-smoke + holdout_excluded const-true enforcement"
  modified:
    - "lib/kiln/audit/event_kind.ex — appended 3 atoms (:stage_input_rejected, :artifact_written, :integrity_violation); moduledoc rewritten 22 -> 25"
    - "test/kiln/audit/event_kind_test.exs — asserts length 25, 3 new atoms present, append-only ordering preserved"
    - "test/kiln/audit/append_test.exs — Rule-3 blocking fix: minimal_payload_for/1 gained 3 clauses (1 per new kind) + title updated '22 kinds' -> '25 kinds'"

key-decisions:
  - "Audit schema shape is payload-only (not full event envelope). Plan 02-01 spec text suggested top-level fields like `event_kind`/`run_id`/`stage_id`/`correlation_id`/`payload`; the Phase 1 convention (and Kiln.Audit.append/1 implementation) validates ONLY the payload map. Followed the analog (payload-only, consistent with Phase 1). Documented as Deviation #1."
  - "Verifying stage contract omits `const: true` on holdout_excluded. D-74 states verifier stages may run against the holdout set; all four other kinds enforce `const: true` structurally (SPEC-04 provenance). verifying.json accepts either boolean value; the operator opts in via the envelope producer."
  - "Registry fetch/1 returns {:error, :unknown_kind} not {:error, :schema_missing}. RESEARCH.md Pattern 1 example and plan spec both specify :unknown_kind; adopted for new registries. Kiln.Audit.SchemaRegistry (P1) still returns :schema_missing — consistency-retrofit deferred since the two semantics overlap (missing file OR kind not in registry)."
  - "Migration down/0 hard-codes the original 22-kind list. The alternative (compute from EventKind at down-time) fails because the module attribute is always 25 atoms at rollback time. Documented the rationale in the migration moduledoc."
  - "Added `formats: true` to new registries per RESEARCH.md correction #1. Phase 1's Kiln.Audit.SchemaRegistry remains without it; the inconsistency is flagged as a deferred item (see STACK.md D-100 retrofit)."

patterns-established:
  - "Compile-time JSV registry copy pattern: for each new bounded-context schema family, ship a Kiln.<Context>.SchemaRegistry that mirrors Kiln.Audit.SchemaRegistry — swap @schemas_dir + @kinds + @build_opts (adding formats: true). Two verbatim copies now exist; Phase 3+ registries follow the same shape"
  - "Reversible migration for SSOT-derived CHECK constraints: up/0 reads from the SSOT at migration-compile time; down/0 hard-codes the prior SSOT state because the module attribute drifts forward. This pattern generalises for any ALTER TABLE ... CHECK where the check body is list-generated"
  - "Stage-contract envelope convention: top-level required 7 keys (run_id, stage_run_id, attempt, spec_ref, budget_remaining, model_profile_snapshot, holdout_excluded) + one kind-specific artifact_ref field. $defs.artifact_ref sub-schema captures sha256 pattern + size_bytes 0..52428800 + content_type enum — the P4 token-bloat boundary defence in schema form"
  - "Audit payload-only schema convention extended: new D-85 kinds mirror Phase 1 schema shape (Kiln.Audit.append/1 validates payload map, not envelope). Every future audit kind uses the same payload-only pattern; full event envelope validation is the Ecto.Changeset's concern"

requirements-completed: [ORCH-01, ORCH-04, ORCH-07]

# Metrics
duration: ~7min
completed: 2026-04-20
---

# Phase 02 Plan 01: Schema Registries + Audit Event Kind Extension Summary

**9 JSON Schema 2020-12 files (1 workflow dialect + 5 stage contracts + 3 new audit payloads) with two compile-time JSV registries and a reversible CHECK-constraint migration extending audit_events from 22 to 25 event kinds.**

## Performance

- **Duration:** ~7 min (426 s)
- **Started:** 2026-04-20T01:22:39Z
- **Completed:** 2026-04-20T01:29:45Z
- **Tasks:** 2 / 2 complete
- **Files created:** 14
- **Files modified:** 3

## Accomplishments

- **The Phase 2 schema foundation is live.** Every downstream plan (loader, Artifacts, StageWorker, Transitions, Run/StageRun schemas) now has validated envelopes to validate against. Plan 02-05's P4 token-bloat boundary defence (D-76) can be implemented in a few lines because ContractRegistry.fetch/1 + JSV.validate/2 do the hard work.
- **EventKind taxonomy is at 25 (22 + 3 D-85 extensions) in both code and DB.** Migration 20260419000001 is up, the audit_events_event_kind_check constraint lists all 25 kinds, `mix ecto.rollback --step 1 && mix ecto.migrate` round-trips cleanly (verified).
- **Two registries compile at module load time; both are verbatim copies of Kiln.Audit.SchemaRegistry structure.** `Kiln.Workflows.SchemaRegistry.fetch(:workflow)` returns `{:ok, %JSV.Root{}}`; `Kiln.Stages.ContractRegistry.fetch(k)` returns compiled roots for all of `[:planning, :coding, :testing, :verifying, :merge]`.
- **Full test suite 104 tests, 0 failures** including the 28 tests in this plan's new/modified files plus the pre-existing 76 that still pass. The one Rule-3 auto-fix (`minimal_payload_for/1` pattern match) kept the full suite green.
- **`mix compile --warnings-as-errors` clean in both dev and test** — no warning regressions from the 5 new/modified files.

## Task Commits

Each task was committed atomically:

1. **Task 1: 9 JSON Schema 2020-12 files** — `e64acc4` (feat)
2. **Task 2: EventKind extend + migration + 2 registries + 3 tests** — `4aed708` (feat)

## Files Created / Modified

### Created (14)

**JSON schemas (9):**
- `priv/workflow_schemas/v1/workflow.json` — D-55..D-59 top-level workflow dialect (191 lines)
- `priv/stage_contracts/v1/planning.json` — planning envelope (77 lines)
- `priv/stage_contracts/v1/coding.json` — coding envelope (72 lines)
- `priv/stage_contracts/v1/testing.json` — testing envelope (72 lines)
- `priv/stage_contracts/v1/verifying.json` — verifying envelope, holdout_excluded relaxed to boolean (72 lines)
- `priv/stage_contracts/v1/merge.json` — merge envelope (72 lines)
- `priv/audit_schemas/v1/stage_input_rejected.json` — D-76 rejection payload (20 lines)
- `priv/audit_schemas/v1/artifact_written.json` — D-80 CAS-write payload (15 lines)
- `priv/audit_schemas/v1/integrity_violation.json` — D-84 integrity-mismatch payload (15 lines)

**Elixir source (2 registries + 1 migration = 3):**
- `lib/kiln/workflows/schema_registry.ex` — compile-time JSV registry for workflow.json (73 lines)
- `lib/kiln/stages/contract_registry.ex` — compile-time JSV registry for 5 stage contracts (73 lines)
- `priv/repo/migrations/20260419000001_extend_audit_event_kinds.exs` — reversible CHECK extension (76 lines)

**Tests (2):**
- `test/kiln/workflows/schema_registry_test.exs` — kinds/fetch + positive + signature-boundary-documentation (52 lines)
- `test/kiln/stages/contract_registry_test.exs` — 5-kind fetch + envelope-smoke + const-true enforcement (125 lines)

### Modified (3)

- `lib/kiln/audit/event_kind.ex` — appended :stage_input_rejected, :artifact_written, :integrity_violation; moduledoc 22 -> 25
- `test/kiln/audit/event_kind_test.exs` — length assertion 22 -> 25; 3 new-atom assertions; append-only-ordering assertion
- `test/kiln/audit/append_test.exs` — Rule-3 auto-fix: added 3 `minimal_payload_for/1` clauses; title updated "22 kinds" -> "25 kinds"

## Decisions Made

See the `key-decisions` frontmatter entries for the 5 decisions. Highlights:

- **Audit schemas are payload-only.** Plan spec text implied a full-envelope shape (with `event_kind`/`run_id`/`stage_id`/`correlation_id` at top level). The Phase 1 convention (and `Kiln.Audit.append/1`) validates only the `payload` map; followed the analog. See Deviation #1.
- **Verifying stage contract allows holdout_excluded: false.** D-74 states verifier stages may run against the holdout set. All 4 other kinds enforce `const: true` structurally (SPEC-04 provenance); verifying accepts either value.
- **Registry fetch/1 returns `{:error, :unknown_kind}`** (not `:schema_missing`) per RESEARCH.md Pattern 1. Kiln.Audit.SchemaRegistry (P1) is inconsistent and still returns `:schema_missing` — retrofit deferred.
- **Migration down/0 hard-codes the original 22-kind list.** Reading from EventKind at rollback time would observe the 25-atom current-source module attribute and make down a silent no-op.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Plan spec vs analog shape mismatch] Audit schema shape is payload-only (match Phase 1 convention, not plan spec's full-envelope example)**

- **Found during:** Task 1 (authoring `stage_input_rejected.json` / `artifact_written.json` / `integrity_violation.json`)
- **Issue:** The plan text said: `Required: event_kind (const "stage_input_rejected"), run_id, stage_id, correlation_id, payload. payload: ...` — implying the schema should describe the full event envelope. But the plan also said "Mirror `stage_failed.json` shape"; `stage_failed.json` (and every other existing audit schema) is PAYLOAD-ONLY: it describes the `payload` object, not the envelope. `Kiln.Audit.append/1` passes `Map.get(attrs, :payload, %{})` to `JSV.validate/2`, confirming the payload-only boundary. Honoring the plan's literal "Required" list would cause every real `Kiln.Audit.append(%{event_kind: :stage_input_rejected, payload: ...})` call to fail schema validation.
- **Fix:** Authored the 3 new schemas as payload-only, matching every existing `priv/audit_schemas/v1/*.json`. For `stage_input_rejected`, required payload fields are `stage_run_id`/`stage_kind`/`errors`. For `artifact_written`: `name`/`sha256`/`size_bytes`/`content_type`. For `integrity_violation`: `artifact_id`/`expected_sha`/`actual_sha`/`path`. Verified the 3 new schemas accept their respective minimal payloads by extending `test/kiln/audit/append_test.exs` (see Rule-3 below).
- **Files modified:** priv/audit_schemas/v1/stage_input_rejected.json, priv/audit_schemas/v1/artifact_written.json, priv/audit_schemas/v1/integrity_violation.json
- **Verification:** 104 tests / 0 failures (full suite); `minimal_payload_for/1` for the 3 new kinds produces payloads that `Kiln.Audit.append/1` accepts against the new JSV roots.
- **Committed in:** e64acc4 (Task 1 commit — schemas ship in the payload-only shape); append_test.exs gains matching clauses in 4aed708 (Task 2 commit).

**2. [Rule 3 — Blocking] `test/kiln/audit/append_test.exs` `minimal_payload_for/1` FunctionClauseError on the 3 new EventKind atoms**

- **Found during:** Task 2 verification (full suite run after EventKind extension)
- **Issue:** P1's Audit test iterates `for kind <- EventKind.values()` and calls `minimal_payload_for(kind)`. With 25 kinds now returned but only 22 clauses defined, the test raised `FunctionClauseError` for the first new atom encountered. 1 failure / 104 tests.
- **Fix:** Added 3 `minimal_payload_for/1` clauses (one per new kind) producing valid payloads that satisfy the respective JSON schemas. Also updated the test title from `"every one of the 22 kinds ..."` to `"every one of the 25 kinds ..."` and rewrote the internal comment from `"mirrors the 22 JSON schemas"` to `"mirrors the 25 JSON schemas (22 Phase 1 + 3 Phase 2 D-85 extensions)"`.
- **Files modified:** test/kiln/audit/append_test.exs
- **Verification:** Full suite returned to 104 tests / 0 failures.
- **Committed in:** 4aed708 (Task 2 commit)

**3. [Rule 3 — Blocking — deferred, not in scope] Pre-existing fixture `test/support/fixtures/workflows/cyclic.yaml` uses single-char stage IDs `a`/`b`/`c` which violate the `^[a-z][a-z0-9_]{1,31}$` id regex and will fail JSV before D-62 validator 2 (toposort) can detect the cycle**

- **Found during:** Task 1 verification (positive-validation smoke of the fixtures against workflow.json)
- **Issue:** Plan 02-00 shipped cyclic.yaml as the fixture for D-62 validator 2 (topological sort rejection). JSV rejects at the schema layer first (id regex requires min 2 chars), so the downstream loader tests that consume this fixture would incorrectly report "schema rejection" instead of "cycle detected". This is a plan-02-00 fixture design issue, not a plan-02-01 concern.
- **Fix:** NOT fixed in this plan — logged to `.planning/phases/02-workflow-engine-core/deferred-items.md`. The fixture's owner is the workflow loader plan (02-02+); that plan either updates the fixture to 2-char IDs or loosens the id regex. The deferred-items log pins the context for the next agent.
- **Files modified:** `.planning/phases/02-workflow-engine-core/deferred-items.md` (new file)
- **Verification:** Deferred; downstream plan owns it.
- **Committed in:** (not committed — deferred-items.md is untracked and out-of-scope for this plan; will be picked up by the owning plan's agent)

---

**Total deviations:** 2 auto-fixed (1 Rule-1 bug per plan-spec vs analog mismatch, 1 Rule-3 blocking from EventKind extension); 1 pre-existing out-of-scope issue logged to deferred-items.md.
**Impact on plan:** Both auto-fixes necessary: Rule-1 would have made Kiln.Audit.append/1 reject the 3 new kinds forever; Rule-3 would have left the full suite red. No scope creep. Deferred item stays deferred.

## Issues Encountered

None beyond the deviations above.

## Authentication Gates

None required.

## Verification Evidence

- `MIX_ENV=test mix compile --warnings-as-errors` — 0 warnings (clean)
- `MIX_ENV=test mix ecto.migrate` — 20260419000001 applied; `mix ecto.rollback --step 1 && mix ecto.migrate` — clean round-trip
- `MIX_ENV=test mix test --exclude pending` — 104 tests, 0 failures
- `MIX_ENV=test mix test test/kiln/audit/event_kind_test.exs test/kiln/workflows/schema_registry_test.exs test/kiln/stages/contract_registry_test.exs` — 28 tests, 0 failures
- `MIX_ENV=test mix run -e '...JSV.build ...'` — all 9 new + all 22 existing schemas compile with `formats: true`
- `psql`-equivalent inspect via Repo.query!: `audit_events_event_kind_check` CHECK body contains all 25 kinds including `stage_input_rejected`, `artifact_written`, `integrity_violation`
- Grep acceptance: `grep -q "formats: true"` passes for both new registries; `grep -q "@external_resource"` passes for both; `grep -q "\"const\": \"kiln.dev/v1\""` passes in workflow.json; `grep -q "\"x-kiln-reserved\": true"` passes; all 5 stage contracts contain `$defs` + `artifact_ref`.

## Next Plan Readiness

- `Kiln.Workflows.SchemaRegistry.fetch(:workflow)` is live for Plan 02-02 (workflow loader) to call.
- `Kiln.Stages.ContractRegistry.fetch(kind)` is live for Plan 02-05 (StageWorker input rejection) to call.
- `audit_events_event_kind_check` accepts the 3 new kinds, so Plan 02-03 (Kiln.Artifacts) can emit `:artifact_written` + `:integrity_violation` without a follow-up migration.
- Plan 02-02+ fixture owner needs to address deferred-items.md entry (cyclic.yaml single-char IDs).

## Self-Check: PASSED

- All 14 created files exist on disk (verified file-by-file).
- Both task commits (`e64acc4`, `4aed708`) present in `git log --all --oneline`.
- Full `MIX_ENV=test mix test --exclude pending` suite: 104 tests, 0 failures.
- `MIX_ENV=test mix compile --warnings-as-errors` clean.
- Migration `20260419000001` status = up.
- No unexpected file deletions in either task commit.

---

*Phase: 02-workflow-engine-core*
*Completed: 2026-04-20*
