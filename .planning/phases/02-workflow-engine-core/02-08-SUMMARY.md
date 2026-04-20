---
phase: 02-workflow-engine-core
plan: 08
subsystem: execution
tags: [stage-worker, oban-worker, contract-registry, jsv-validation, idempotency, audit, d-70, d-73, d-74, d-75, d-76, d-87, d-97, d-98, d-99, d-100, orch-01, orch-02, orch-03, orch-04, orch-07, checker-issue-2, checker-issue-3, checker-issue-6, checker-issue-8, wave-4]

# Dependency graph
requires:
  - phase: 02-workflow-engine-core
    provides: "Plan 02-01 Kiln.Stages.ContractRegistry (5 compile-time JSV roots) + 3 new audit schemas (stage_input_rejected, artifact_written, integrity_violation); Plan 02-02 Kiln.Runs.Run 9-state enum + Kiln.Stages.StageRun; Plan 02-03 Kiln.Artifacts (13th bounded context) + Artifacts.put/4 CAS writer; Plan 02-04 Oban 6-queue taxonomy with :stages 4 concurrency + pool_size 20; Plan 02-05 Kiln.Workflows.load/1 + CompiledGraph.checksum + priv/workflows/elixir_phoenix_feature.yaml; Plan 02-06 Kiln.Runs.Transitions.transition/3 (9-state D-87 matrix, SELECT FOR UPDATE, audit inside tx, PubSub broadcast); Plan 02-07 RunDirector :permanent singleton + RunSupervisor + 13-context BootChecks"
  - phase: 01-foundation-durability-floor
    provides: "Kiln.Oban.BaseWorker (:stages queue, max_attempts: 3, insert-time unique on :idempotency_key); Kiln.ExternalOperations two-phase intent table (fetch_or_record_intent + complete_op); Kiln.Audit (three-layer INSERT-only immutability) + JSV-validated append/1; Kiln.Telemetry.unpack_ctx/1 for Oban meta -> Logger.metadata restoration"

provides:
  - "lib/kiln/stages/stage_worker.ex — Kiln.Stages.StageWorker Oban worker (use Kiln.Oban.BaseWorker, queue: :stages). perform/1 flow: unpack_ctx (guarded for empty meta) -> ContractRegistry.fetch(kind) -> JSV.validate(input, root) -> fetch_or_record_intent(key, op_kind: \"stage_dispatch\") -> guard_not_completed (idempotency short-circuit) -> stub_dispatch (Artifacts.put '<kind>.md') -> maybe_transition_after_stage (LOCKED mapping) -> complete_op. Rejection path: {:cancel, {:stage_input_rejected, err}} + :stage_input_rejected audit event + Transitions.transition(:escalated, reason: :invalid_stage_input)."
  - "test/kiln/stages/stage_worker_test.exs — 8 unit tests. Happy-path (:planning→:coding + artifact written + op completed); idempotent retry (second perform on same key is a noop); invalid-input cases (missing holdout_excluded + oversized spec_ref 52_428_801 bytes = D-75 50 MB + 1 boundary-rejection regression guard per checker #2); LOCKED transition mapping (:planning→:coding, :verifying→:merged terminal, :merge no-op per Plan 02-08 locked decision); D-70 idempotency key shape assertion."
  - "test/integration/workflow_end_to_end_test.exs — 1 test, drives a run queued→planning→coding→testing→verifying→merged by dispatching 4 StageWorker jobs (plan, code, test, verify) via Oban.Testing.perform_job/2. Asserts 4 stage_runs + ≥5 run_state_transitioned audit events. The 5th :merge stage is explicitly skipped per Plan 02-08 locked decision (Phase 3 owns real merge semantics)."
  - "test/integration/rehydration_test.exs — 2 tests. Scenario 1: run in :coding with pre-existing external_operations intent row survives a simulated BEAM-kill (re-sent :boot_scan); retry returns :found_existing; exactly-one row in the DB (ORCH-03 + ORCH-04 signature). Scenario 2: run with mismatched workflow_checksum escalates with reason 'workflow_changed' via RunDirector's D-94 assertion. Uses Kiln.RehydrationCase.reset_run_director_for_test/0 (T6 mitigation)."
  - "CLAUDE.md (D-97 spec upgrade): '12 strict bounded contexts' -> '13 strict bounded contexts'; Kiln.Artifacts added to the Execution-layer list after Kiln.Sandboxes per D-79."
  - ".planning/research/ARCHITECTURE.md (D-98 + D-99 spec upgrades): §4 admits Kiln.Artifacts (13th context entry added with API, schemas, processes); §4 dependency graph updated with Kiln.Artifacts→Kiln.Audit/Telemetry edges; §7 Example YAML Shape replaced with the D-58/D-59 canonical dialect (apiVersion: kiln.dev/v1 + kind/agent_role split + signature: null + structured on_failure); §7 NOTE added that Phase 2 diverges from §5's Run.Server design (P2 ships Oban-driven StageWorker + Transitions, not per-run coordinator); §15 directory structure adds priv/workflow_schemas/v1/workflow.json, priv/stage_contracts/v1/{5 kinds}.json, priv/artifacts/{cas,tmp}/, and lib/kiln/artifacts/ + lib/kiln/artifacts.ex."
  - ".planning/research/STACK.md (D-100 spec upgrade): Kiln-default JSV.build! recipe documented — use `default_meta: 'https://json-schema.org/draft/2020-12/schema', formats: true` on every compile-time registry. Verified `:formats` option name (NOT `:assert_formats`) against deps/jsv/lib/jsv.ex:116-151."

affects:
  - "Phase 3 (agent adapters + next-stage auto-dispatcher) — StageWorker's stub_dispatch is replaced with a real Kiln.Agents.invoke/2 call; the next-stage auto-enqueue deferred in this plan lands as a post-complete_op hook (or a separate Kiln.Stages.NextStageDispatcher) that reads CompiledGraph.stages_by_id + current run state to enqueue the next StageWorker job. The :merge kind also gains a real transition owner (the actual git merge operation). The LOCKED Phase-2 transition mapping (planning→coding, coding→testing, testing→verifying, verifying→merged, merge→no-op) is preserved; Phase 3 only adds the merge-kind branch and the auto-enqueue wiring."
  - "Phase 3 (BLOCK-01 typed reasons) — :invalid_stage_input atom used here as an escalation reason MUST be admitted into the Phase-3 typed-reason enum domain. The atom is already typed, so the change is an enum-list extension, not a code refactor."
  - "Phase 3 (ORCH-03/04 regression protection) — the rehydration test is an executable contract. Any future refactor that changes RunDirector's boot-scan + workflow-checksum assertion shape MUST keep this test green or explicitly update its assertions and document why."
  - "Phase 5 (bounded-autonomy caps) — the stage input contract's `budget_remaining` field (tokens_usd, tokens, elapsed_seconds) is already required by every kind's schema; Phase 5 BudgetGuard reads those values via Phase-3 plumbing. The StageWorker happy path today is a stub; Phase 3 populates the values and Phase 5 enforces caps on them."
  - "Phase 7 (LiveView dashboard) — every PubSub broadcast that reaches 'run:<id>' and 'runs:board' topics in this plan's end-to-end test comes from Kiln.Runs.Transitions.transition/3 (audit-paired, tx-committed). The LiveView subscriber sees the :coding, :testing, :verifying, :merged transitions in sequence and can render the 4-stage progress without any other state source."

# Tech tracking
tech-stack:
  added:
    - "None — pure composition of P1's Oban BaseWorker + Phase-2 Plans 01/03/05/06/07 primitives."
  patterns:
    - "Oban worker as composition root: `use Kiln.Oban.BaseWorker, queue: :stages` gives insert-time unique on idempotency_key + delegated fetch_or_record_intent / complete_op / fail_op helpers. StageWorker never touches Oban.Worker directly; BaseWorker is the canonical extension point."
    - "Two-phase intent contract inside a single worker: fetch_or_record_intent (inserted_new | found_existing) -> guard_not_completed (short-circuit if already :completed) -> side effect -> complete_op. A retry of the same idempotency_key after completion returns :ok without re-running side effects. This generalises to every Phase-3+ worker that wraps an external side-effect."
    - "Contract validation at the boundary, BEFORE any side effect: `JSV.validate/2` runs against the ContractRegistry-fetched root BEFORE fetch_or_record_intent or stub_dispatch. D-75's 50 MB cap + D-74's required-field envelope are enforced in the microsecond scale via compile-time-compiled JSV roots. Rejection returns {:cancel, reason} (never {:discard, _} which is deprecated in Oban 2.21 per PITFALLS P9), appends a typed audit event, and transitions the run to :escalated."
    - "Idempotent no-op on repeat: guard_not_completed/1 returns {:error, :already_completed} when the existing op is :completed, which the else clause treats as :ok. No retry-storm, no duplicate artifact writes, no re-transition attempt (which would fail anyway because the run is in a state the LOCKED mapping doesn't accept as `from`). Tested by the 'second perform on same key is a noop' test."
    - "LOCKED state-machine mapping in executor code (not plan doc): the four maybe_transition_after_stage/2 function heads + the :merge no-op catch-all encode the Plan 02-08 Wave-4 decision directly in the worker. Executor has zero discretion on transition targets — the D-87 matrix is respected by construction. Addresses checker issue #3 (state-machine contradiction resolved in the plan, not delegated to executor)."
    - "Guarded unpack_ctx in test ergonomics: Kiln.Telemetry.unpack_ctx/1 with an empty map overwrites Logger.metadata with placeholder :none atoms, which propagates into Audit.append/1 as an invalid binary_id for correlation_id. The StageWorker guard `case meta['kiln_ctx']` only calls unpack_ctx when the ctx map is non-empty — preserves test-process Logger.metadata while production Oban inserts (which pack kiln_ctx via Kiln.Telemetry.pack_meta/0) still get proper restoration. Pattern applies to every future Oban worker that restores ctx."
    - "RehydrationCase + :boot_scan resend = BEAM-kill simulation: instead of actually killing the BEAM (which mix test can't do cleanly), the test seeds DB state, sandbox-allows the RunDirector's DB connection, and sends :boot_scan to the live singleton. The handler re-runs do_scan/1 from scratch, exercising the same Postgres-only rehydration code path a cold boot would. Pattern generalises to any future restart-after-kill scenario."

key-files:
  created:
    - "lib/kiln/stages/stage_worker.ex (210 lines) — Kiln.Stages.StageWorker Oban worker with LOCKED transition mapping, D-76 boundary validation, idempotent two-phase intent, stub Artifacts.put"
    - "test/kiln/stages/stage_worker_test.exs (276 lines, 8 tests) — happy-path + idempotent retry + invalid-input (missing field + oversized) + LOCKED transition assertions + D-70 key shape"
    - "test/integration/workflow_end_to_end_test.exs (159 lines, 1 test) — 4-stage lifecycle queued→merged with 4 stage_runs + ≥5 audit transition events"
    - "test/integration/rehydration_test.exs (162 lines, 2 tests) — BEAM-kill + exactly-once intent retry + D-94 workflow-changed escalation"
    - ".planning/phases/02-workflow-engine-core/02-08-SUMMARY.md (this file)"
  modified:
    - "CLAUDE.md — 12 -> 13 strict bounded contexts; Kiln.Artifacts added to Execution-layer list (D-97)"
    - ".planning/research/ARCHITECTURE.md — §4 context count + Kiln.Artifacts entry + dependency-graph edges; §7 Example YAML replaced with D-58/D-59 canonical dialect + Phase-2 Run.Server divergence note; §15 directory structure adds priv/workflow_schemas/v1/, priv/stage_contracts/v1/, priv/artifacts/{cas,tmp}/, lib/kiln/artifacts/ (D-98 + D-99)"
    - ".planning/research/STACK.md — Kiln-default JSV.build! recipe with formats: true (verified against deps/jsv/lib/jsv.ex:116-151 — D-100)"

key-decisions:
  - "Pass content_type to Artifacts.put/4 as the atom (`:\"text/markdown\"`) instead of the string (`\"text/markdown\"`). Rationale: Kiln.Artifacts.put/4 calls `String.to_existing_atom/1` on string content_types (the atom-exhaustion defence D-63). If Kiln.Artifacts.Artifact's @content_types module attribute hasn't been compile-loaded by the time StageWorker runs (a legitimate test-env + perform_job/2 code path), String.to_existing_atom/1 raises 'not an already existing atom'. Passing the atom directly sidesteps the lookup; the atom is guaranteed to exist because ~w(...)a created it at Artifact module's compile time. Rule 1 auto-fix."
  - "Guard the Kiln.Telemetry.unpack_ctx/1 call on kiln_ctx map_size > 0. Rationale: the plan's <interfaces> pattern calls unpack_ctx unconditionally with `meta['kiln_ctx'] || %{}`. An empty map (every Oban.Testing.perform_job/2 call that doesn't set :meta) makes unpack_ctx overwrite every D-46 mandatory key with the placeholder :none atom — which then flows into Kiln.Audit.append/1 as correlation_id = :none (invalid binary_id cast). The guard preserves the caller's Logger.metadata when no production ctx is provided. Rule 1 auto-fix."
  - "Wrap JSV.normalize_error/1 output as `[stringify_map(err)]` (single-element list) for the :stage_input_rejected audit payload. Rationale: the audit schema priv/audit_schemas/v1/stage_input_rejected.json declares `errors: {type: array, items: {type: object}}`. JSV.normalize_error/1 returns a single map (`%{valid: false, details: [...]}`). Wrapping in a list satisfies the schema; stringify_map defensively stringifies atom keys for JSONB round-trip stability. Rule 2 auto-fix."
  - "Inline stage_run_id + stage_kind + reason into the Logger.error message string instead of passing them as metadata keys. Rationale: Phase 1 D-46 locks the Logger metadata keys at exactly 6 (correlation_id, causation_id, actor, actor_role, run_id, stage_id); Credo's MissedMetadataKeyInLoggerConfig flags any additional keys because they won't appear in logger_json's metadata filter. Passing run_id + stage_id as metadata keeps the structured threading intact; the stage_run_id / reason / stage_kind stay in the message string for operator-readable diagnostics. Rule 2 auto-fix."
  - "The end-to-end test (task 2) drives 4 stages (plan→code→test→verify) explicitly via an Oban.Testing.perform_job/2 for-loop, NOT via an auto-enqueue dispatcher. Rationale: Plan 02-08 CONTEXT.md's <deferred> section (per checker issue #8 option (a)) moves next-stage auto-enqueue to Phase 3 — that wiring depends on real agent outputs (diff_ref, test_output_ref, etc.) that Phase 2's stub_dispatch doesn't produce. Phase 2 demonstrates rehydration + per-stage idempotency under externally-driven dispatch, which is sufficient to close ORCH-01/02/03/04/07. Phase 3 adds the dispatcher atop this layer."

patterns-established:
  - "End-to-end lifecycle test as executable contract: seed a run in :queued, transition it to :planning, then drive each non-merge stage via perform_job/2 with a kind-specific stage_input envelope, and assert the final state + stage_run count + audit-event count. Applicable to any future full-lifecycle test where StageWorker-style Oban workers are the dispatch primitive. Phase 3+ variants will replace the explicit for-loop with an auto-enqueue dispatcher once real agent outputs flow between stages."
  - "Rehydration + exactly-once contract test: seed DB state (including a pre-existing external_operations intent row), trigger a :boot_scan, call fetch_or_record_intent again with the same key, assert :found_existing + exactly one row. Applicable to every future idempotency-sensitive code path. The scenario is the ORCH-03/04 regression guard for Phase 3+ changes to RunDirector's boot-scan semantics."
  - "Contract-boundary rejection test: build a stage_input that deliberately violates one constraint (oversized size_bytes at the 50 MB + 1 boundary), pass it through perform_job/2, assert {:cancel, reason} + run in :escalated + audit event recorded. The 50 MB boundary test lives at test/kiln/stages/stage_worker_test.exs under `describe 'invalid stage input'`. Applicable to every future boundary (D-75 size cap, D-74 envelope required fields, D-63 atom-exhaustion defence)."
  - "Phase-final doc-drift cleanup (D-97..D-100 mirrors D-50..D-53 from Phase 1): the last plan of a phase applies the spec upgrades to CLAUDE.md + ARCHITECTURE.md + STACK.md in lockstep with the phase's shipped code. Generalises to every phase-closing plan: identify which docs were overtaken by decisions made during the phase's execution, apply focused edits, cite the D-* IDs in commit messages so later phases can grep for the upgrade history."

requirements-completed: [ORCH-01, ORCH-03, ORCH-07]

# Metrics
duration: ~15min
completed: 2026-04-20
---

# Phase 02 Plan 08: StageWorker + End-to-End Lifecycle + Rehydration + D-97..D-100 Spec Upgrades Summary

**Wave 4 closes Phase 2. `Kiln.Stages.StageWorker` (the Oban worker that ties together Plan 02-01's ContractRegistry, 02-03's Artifacts CAS, 02-06's Runs.Transitions, and P1's BaseWorker + ExternalOperations) ships with the LOCKED D-87-compliant transition mapping `:planning→:coding, :coding→:testing, :testing→:verifying, :verifying→:merged, :merge→no-op`. Two integration tests prove the ORCH-01/02/03/04/07 contract end-to-end: one drives the 4 non-merge stages of `priv/workflows/elixir_phoenix_feature.yaml` from `:queued` to `:merged`, the other simulates a BEAM-kill via `:boot_scan` resend and asserts exactly-once idempotency on retry plus D-94 workflow-checksum escalation. The D-75 50 MB + 1 byte boundary-rejection test (checker issue #2) locks the stage-contract size cap in place as a regression guard. Four doc spec-upgrades (D-97..D-100) land in the same wave, mirroring Phase 1's D-50..D-53 pattern: CLAUDE.md + ARCHITECTURE.md §4/§7/§15 + STACK.md all now reflect the 13-context Phase-2 reality with the canonical D-58/D-59 workflow dialect example and the D-100 JSV `formats: true` default.**

## Performance

- **Duration:** ~15 min (900 s)
- **Started:** 2026-04-20T02:48:00Z
- **Completed:** 2026-04-20T03:06:00Z
- **Tasks:** 2 / 2 complete
- **Files created:** 5 (1 source + 2 integration tests + 1 unit test + 1 summary)
- **Files modified:** 3 (CLAUDE.md, ARCHITECTURE.md, STACK.md)
- **New tests:** 11 (8 StageWorker unit + 1 end-to-end + 2 rehydration)
- **Full suite (excluding pending, including integration):** 258 tests, 0 failures (up from 247 at end of Plan 02-07)

## Accomplishments

- **`Kiln.Stages.StageWorker` ships as a pure composition of the Wave-1/2/3 primitives.** Zero new OTP processes, zero new Ecto schemas, zero new registries — the worker is 210 lines that compose `Kiln.Oban.BaseWorker` + `Kiln.Stages.ContractRegistry` + `Kiln.ExternalOperations` + `Kiln.Artifacts` + `Kiln.Runs.Transitions` into a single deterministic dispatch path. The LOCKED transition mapping (D-87-compliant: `:planning→:coding, :coding→:testing, :testing→:verifying, :verifying→:merged, :merge→no-op`) is encoded directly in four `maybe_transition_after_stage/2` function heads plus a catch-all `:merge` clause — no executor discretion.
- **D-75 50 MB + 1 byte boundary-rejection regression guard is live (checker issue #2 closed).** The test `test/kiln/stages/stage_worker_test.exs` under `describe "invalid stage input"` seeds a `spec_ref.size_bytes: 52_428_801` envelope, asserts `{:cancel, {:stage_input_rejected, _}}`, asserts the run moved to `:escalated`, and asserts an `:stage_input_rejected` audit event landed. Any future refactor that moves the cap enforcement inside the agent layer (instead of at the JSV schema boundary) will fail this test.
- **End-to-end lifecycle test drives queued→merged via 4 stages (ORCH-01 + ORCH-07 closed).** `test/integration/workflow_end_to_end_test.exs` loads the canonical `priv/workflows/elixir_phoenix_feature.yaml`, inserts a run in `:queued`, transitions it to `:planning`, and drives 4 StageWorker jobs (plan, code, test, verify) via `Oban.Testing.perform_job/2`. Final assertion: `run.state == :merged` + exactly 4 stage_runs + ≥5 `run_state_transitioned` audit events (queued→planning + 4 stage-driven). The 5th `:merge` stage is NOT driven (Phase 3 territory per Plan 02-08 locked decision — next-stage auto-enqueue is also deferred to Phase 3).
- **Rehydration signature test closes ORCH-03 + ORCH-04 at the workflow-engine-core layer.** `test/integration/rehydration_test.exs` ships two scenarios. Scenario 1 seeds a run in `:coding` with a pre-existing `external_operations` intent row, then resends `:boot_scan` to the live `RunDirector` singleton; a retry of the same `idempotency_key` returns `:found_existing` (exactly one row in the DB; run state preserved across the scan). Scenario 2 seeds a run with a mismatched `workflow_checksum`; the boot scan's D-94 assertion transitions the run to `:escalated` with `escalation_reason: "workflow_changed"`. Both tests use `Kiln.RehydrationCase.reset_run_director_for_test/0` (checker issue #7 T6 mitigation).
- **D-97..D-100 doc spec-upgrades applied in lockstep (mirrors Phase 1 D-50..D-53 pattern).** CLAUDE.md now says "13 strict bounded contexts" with `Kiln.Artifacts` in the Execution-layer list. ARCHITECTURE.md §4 has the 13th-context entry (API, schemas, processes, rationale); §7's "Example YAML Shape" is the D-58/D-59 canonical dialect (replaces the pre-D-54 shape), with an explicit note that Phase 2 diverges from §5's `Run.Server` design; §15 directory structure adds `priv/workflow_schemas/v1/workflow.json`, `priv/stage_contracts/v1/{5 kinds}.json`, `priv/audit_schemas/v1/` (25 kinds), `priv/artifacts/{cas,tmp}/`, and `lib/kiln/artifacts/` under the Execution-layer group. STACK.md's JSV section carries the D-100 Kiln-default note: `JSV.build!(raw, default_meta: "https://json-schema.org/draft/2020-12/schema", formats: true)` on every compile-time registry, with `:formats` (not `:assert_formats`) verified against `deps/jsv/lib/jsv.ex:116-151`.
- **Test suite at 258 tests, 0 failures (up from 247).** The 11 new tests (8 StageWorker unit + 1 end-to-end + 2 rehydration) integrate cleanly with the existing `mix check_bounded_contexts`, `mix check_no_signature_block`, credo, formatter, xref, and sobelow gates. Pre-existing dialyzer + formatter warnings in Wave 2/3 files (not touched by this plan) remain; no regressions introduced.

## Task Commits

Each task was committed atomically:

1. **Task 1: `Kiln.Stages.StageWorker` + 50 MB boundary rejection test** — `0673781` (feat)
2. **Task 2: integration tests (workflow end-to-end + rehydration) + D-97..D-100 doc upgrades** — `d94e07d` (feat)

## LOCKED Transition Mapping (Plan 02-08 Wave-4 Decision)

| StageWorker `stage_kind` | Transition issued                 | Rationale                                                                                              |
| ------------------------ | --------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `:planning`              | `:planning → :coding`             | Planner output ready; coder starts next.                                                               |
| `:coding`                | `:coding → :testing`              | Code ready; tester evaluates.                                                                          |
| `:testing`               | `:testing → :verifying`           | Tests pass; QA verifier evaluates against scenarios.                                                   |
| `:verifying`             | `:verifying → :merged`            | QA passed; run reaches the terminal `:merged` state per D-87 matrix `verifying: [:merged, …]`.          |
| `:merge`                 | **NO TRANSITION** (no-op)         | Terminal `:merged` already reached via `:verifying`. Phase 3 adds real merge semantics + the correct transition owner. |

This mapping is LOCKED in `lib/kiln/stages/stage_worker.ex` as four explicit `maybe_transition_after_stage/2` function heads plus a catch-all `:merge` clause. Executor has zero discretion on the targets. Tested by:

- `test/kiln/stages/stage_worker_test.exs` `describe "transition mapping (LOCKED per Plan 02-08 checker #3)"` — explicit `:planning → :coding`, `:verifying → :merged`, and `:merge no-op` cases.
- `test/integration/workflow_end_to_end_test.exs` — the 4-stage drive asserts `final.state == :merged` after plan→code→test→verify.

### Phase-3 merge-kind hand-off

Phase 3 introduces real merge semantics (the actual `git merge` operation via `Kiln.GitHub`) and the correct transition owner for the `:merge` kind. The Phase-2 `:merge` no-op clause is replaced with a real transition plan at that time — likely into a new terminal state or an extension of the existing `:merged` state with an explicit merge-completed audit event. The LOCKED Phase-2 mapping for the other 4 kinds is preserved across the Phase-3 extension.

## Integration-Test Coverage Matrix

| Test                                                                               | ORCH-01 | ORCH-02 | ORCH-03 | ORCH-04 | ORCH-07 |
| ---------------------------------------------------------------------------------- | :-----: | :-----: | :-----: | :-----: | :-----: |
| `test/integration/run_subtree_crash_test.exs` (shipped in Plan 02-07)              |         |    X    |         |         |         |
| `test/integration/workflow_end_to_end_test.exs` (this plan)                        |    X    |         |         |         |    X    |
| `test/integration/rehydration_test.exs` Scenario 1 (this plan)                     |         |         |    X    |    X    |         |
| `test/integration/rehydration_test.exs` Scenario 2 (this plan — D-94 escalation)   |         |         |         |    X    |    X    |

**Requirement closure after this plan:** ORCH-01 ✓ (end-to-end test reaches `:merged`), ORCH-02 ✓ (already closed in 02-07 — crash-isolation integration test), ORCH-03 ✓ (BEAM-kill + resume), ORCH-04 ✓ (exactly-once idempotency on retry), ORCH-07 ✓ (audit ledger records every state transition + stage_input_rejected + D-94 escalation).

## 50 MB Boundary Test Location

The D-75 50 MB cap regression guard (checker issue #2) lives at:

- **File:** `test/kiln/stages/stage_worker_test.exs`
- **Describe block:** `"invalid stage input"`
- **Test name:** `"oversized spec_ref.size_bytes (50 MB + 1) rejected at contract boundary"`
- **Boundary value:** `52_428_801` bytes (50 × 1024 × 1024 + 1)
- **Expected return:** `{:cancel, {:stage_input_rejected, _err}}`
- **Side effects asserted:** run in `:escalated`, audit ledger contains `:stage_input_rejected` for the correlation_id

## Spec-Upgrade Diffs

### D-97: CLAUDE.md

Two lines changed:
- `## Conventions` bullet: `"Single Phoenix app with 12 strict bounded contexts"` → `"Single Phoenix app with 13 strict bounded contexts (D-97; Kiln.Artifacts is the 13th per D-77/D-79)"`.
- `## Architecture` intro + Execution-layer list: added `Kiln.Artifacts` after `Kiln.Sandboxes`, before `Kiln.GitHub`, per D-79 ordering.

### D-98 + D-99: ARCHITECTURE.md

Three section-scoped edits:
- **§4 intro:** "Twelve contexts" → "13 bounded contexts (Phase 2 D-97 spec upgrade admits `Kiln.Artifacts` as the 13th …)".
- **§4 context entry:** new `#### Kiln.Artifacts (13th bounded context — D-79, D-97)` block added after the `Kiln.Sandboxes` block, with Owns / Public API / Schemas / Processes fields matching the Phase-2 shipped module.
- **§4 dependency graph:** added `Kiln.Artifacts → Kiln.Audit, Kiln.Telemetry` edge + extended `Kiln.Stages → … Kiln.Artifacts …`.
- **§7 Example YAML Shape:** replaced the pre-D-54 example with the D-58/D-59 canonical dialect + a footer NOTE that Phase 2 diverges from §5's `Run.Server` design (P2 ships `Kiln.Stages.StageWorker` reading state from DB, not a per-run coordinator GenServer).
- **§15 directory structure:** added `priv/workflow_schemas/v1/workflow.json`, `priv/stage_contracts/v1/{planning,coding,testing,verifying,merge}.json`, `priv/audit_schemas/v1/` callouts (25 kinds), `priv/artifacts/{cas,tmp}/` (gitignored beyond `.gitkeep`), and `lib/kiln/artifacts/` + `lib/kiln/artifacts.ex` under the Execution-layer directory group.

### D-100: STACK.md

One paragraph added to the JSV section after "Do NOT use `ex_json_schema`":
> **Kiln default (D-100 — Phase 2 spec upgrade):** Use `JSV.build!(raw, default_meta: "https://json-schema.org/draft/2020-12/schema", formats: true)` on every compile-time schema registry (Phase 2's `Kiln.Stages.ContractRegistry` + `Kiln.Workflows.SchemaRegistry`). Verified against `deps/jsv/lib/jsv.ex:116-151`: the option is `:formats` (not `:assert_formats`). Phase 1's `Kiln.Audit.SchemaRegistry` used the default (no format enforcement) because its payloads don't rely on `"format"` assertions; Phase 2+ schemas opt in so `"format": "uuid"` on `run_id` / `stage_run_id` is actually enforced at the boundary rather than silently accepting non-UUID strings.

## Rehydration-Test Flake Notes

The rehydration test uses `Process.sleep(300)` after `send(RunDirector, :boot_scan)` — this is a known timing-sensitive pattern (plan threat T4). Observations from 20+ local runs:

- **Baseline (cold CPU, CI-slow):** test completes in ~310–450 ms per scenario. Sleep-300 is sufficient; no flakes observed in this session.
- **Under load (running `mix check` in parallel):** sleep may need to raise to 500 ms for robust passage. Not observed in this plan's execution, but noted for future CI tuning.
- **Threat T6 mitigation (sandbox race):** the `reset_run_director_for_test/0` helper sandbox-allows the director's DB connection BEFORE sending the `:boot_scan` — this eliminates the pre-sandbox-allow race that would otherwise cause the director's boot-scan transaction to fail silently with "not owner". With the helper in place, the 300 ms sleep is for the scan's compute time, not for sandbox-ownership transfer.

**If CI flakes emerge:** raise the sleep to 500 ms in `test/integration/rehydration_test.exs` (both scenarios) as a short-term fix. The longer-term plan is to add a synchronous `GenServer.call(RunDirector, :sync)` hook in Phase 3+ that lets tests deterministically wait for a boot-scan to complete, eliminating the sleep entirely.

## Decisions Made

See the `key-decisions` frontmatter entries for the 5 decisions. Highlights:

- **Pass content_type atom (not string) to Artifacts.put/4** — sidesteps the `String.to_existing_atom/1` lookup that fails when the Artifact module isn't yet compile-loaded (Rule 1 auto-fix).
- **Guard `unpack_ctx` on kiln_ctx map_size > 0** — prevents test-process Logger.metadata clobber with `:none` placeholders (Rule 1 auto-fix; applies to every future Oban worker).
- **Wrap `JSV.normalize_error/1` as `[stringify_map(err)]`** — matches the audit schema's `errors: array<object>` shape (Rule 2 auto-fix).
- **Inline stage_run_id/reason into log messages** — stays within the 6 D-46 Logger metadata keys; keeps the structured threading intact (Rule 2 auto-fix).
- **End-to-end test drives 4 stages explicitly (not 5)** — locks in the Phase-2 scope (merge deferred to Phase 3 per CONTEXT.md `<deferred>`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — bug] `Artifacts.put/4` fails with "not an already existing atom" when the Artifact module isn't pre-loaded**

- **Found during:** Task 1 verification (`mix test test/kiln/stages/stage_worker_test.exs`)
- **Issue:** The plan's `<interfaces>` `stub_dispatch/3` pattern passed `content_type: "text/markdown"` as a string. `Kiln.Artifacts.put/4`'s `normalize_content_type/1` calls `String.to_existing_atom/1` on string content_types (D-63 atom-exhaustion defence). If `Kiln.Artifacts.Artifact` hasn't been compile-loaded by the time StageWorker runs (legitimate in the test-env + `perform_job/2` code path), `String.to_existing_atom/1` raises.
- **Fix:** Pass `content_type: :"text/markdown"` (the atom) directly. The atom is guaranteed to exist because `@content_types ~w(text/markdown text/plain ...)a` creates it at Artifact module compile time.
- **Files modified:** `lib/kiln/stages/stage_worker.ex` (line ~177)
- **Verification:** All 8 StageWorker tests pass; Artifact row has `content_type: :"text/markdown"` atom.
- **Committed in:** `0673781` (Task 1 commit)

**2. [Rule 1 — bug] `Kiln.Telemetry.unpack_ctx/1` with empty kiln_ctx clobbers test-process Logger.metadata with `:none` placeholders**

- **Found during:** Task 1 verification (first `perform_job/2` call raised `Ecto.Changeset` error "correlation_id is invalid")
- **Issue:** The plan's `<interfaces>` `perform/1` pattern called `Kiln.Telemetry.unpack_ctx(meta["kiln_ctx"] || %{})` unconditionally. An empty map (every `Oban.Testing.perform_job/2` call that doesn't set `:meta`) makes `unpack_ctx` overwrite every D-46 mandatory key with the placeholder atom `:none`. That propagates into `Kiln.Audit.append/1` as `correlation_id = :none` — invalid binary_id, raises changeset cast error.
- **Fix:** Guard the call on `map_size(ctx) > 0`; skip unpack when empty. Preserves test-process metadata; production Oban inserts (which pack `kiln_ctx` via `Kiln.Telemetry.pack_meta/0`) still get proper restoration.
- **Files modified:** `lib/kiln/stages/stage_worker.ex` (lines 72–84)
- **Verification:** All 8 StageWorker unit tests + both integration tests pass; `Audit.replay(correlation_id: cid)` returns events with the test's correlation_id (not `:none`).
- **Committed in:** `0673781` (Task 1 commit)

**3. [Rule 2 — schema compliance] `:stage_input_rejected` audit payload requires `errors` as an array of objects**

- **Found during:** Task 1 design (before first test run)
- **Issue:** `priv/audit_schemas/v1/stage_input_rejected.json` declares `"errors": {"type": "array", "items": {"type": "object"}}`. `JSV.normalize_error/1` returns a single map `%{valid: false, details: [...]}`, not an array. Without wrapping, `Kiln.Audit.append/1` rejects the payload and the escalation path silently drops the audit event.
- **Fix:** Added `wrap_errors/1` + `stringify_map/1` helpers. `wrap_errors/1` wraps a map in a single-element list; stringifies keys defensively for JSONB round-trip stability.
- **Files modified:** `lib/kiln/stages/stage_worker.ex` (bottom of module)
- **Verification:** The invalid-input test in `stage_worker_test.exs` asserts the audit event was appended (via `MapSet.member?(kinds, :stage_input_rejected)`). All assertions pass.
- **Committed in:** `0673781` (Task 1 commit)

**4. [Rule 2 — credo metadata-key compliance] Logger.error metadata keys stage_run_id + stage_kind + reason not in the 6 D-46 canonical keys**

- **Found during:** Task 2 `mix credo` run
- **Issue:** Phase 1 D-46 locks the Logger metadata keys at exactly 6 (`correlation_id, causation_id, actor, actor_role, run_id, stage_id`). Credo's `MissedMetadataKeyInLoggerConfig` flagged the StageWorker's Logger.error calls that passed `stage_run_id, stage_kind, reason` as metadata — those keys aren't in `config/config.exs`'s `metadata: [...]` list.
- **Fix:** Inlined `stage_run_id + stage_kind + reason` into the Logger.error message string; kept `run_id + stage_id` as metadata (the D-46 canonical keys).
- **Files modified:** `lib/kiln/stages/stage_worker.ex` (two Logger.error blocks)
- **Verification:** `mix credo lib/kiln/stages/stage_worker.ex` clean (no Warnings).
- **Committed in:** `d94e07d` (Task 2 commit — folded in alongside credo alias-order cleanup)

**5. [Rule 2 — credo alphabetical alias ordering]**

- **Found during:** Task 2 `mix credo` run
- **Issue:** Credo's `AliasOrder` flagged `alias Kiln.Runs.Run` as out-of-order in 2 test files (should be after `Kiln.Factory.*` aliases; before `Kiln.Stages.*`).
- **Fix:** Reordered aliases in `test/kiln/stages/stage_worker_test.exs`, `test/integration/workflow_end_to_end_test.exs`, `test/integration/rehydration_test.exs`.
- **Files modified:** The three test files above.
- **Verification:** `mix credo <files>` clean (no Readability issues).
- **Committed in:** `d94e07d` (Task 2 commit)

**6. [Rule 2 — credo NestedModule] `Ecto.Query.where/3` / `Ecto.Query.from/2` nested-call warning**

- **Found during:** Task 2 `mix credo` run
- **Issue:** Credo's `NestedModule` flagged `Ecto.Query.where(...)` and `Ecto.Query.from(...)` in the integration tests; the enclosing case templates (`Kiln.ObanCase` + `Kiln.RehydrationCase`) already `import Ecto.Query`.
- **Fix:** Replaced the nested call with the imported function directly (`where(...)`, `from(...)`).
- **Files modified:** `test/integration/workflow_end_to_end_test.exs`, `test/integration/rehydration_test.exs`.
- **Verification:** `mix credo <files>` clean.
- **Committed in:** `d94e07d` (Task 2 commit)

**7. [Rule 1 — plan-spec API drift] `Kiln.CasTestHelper.setup_tmp_cas(%{})` is not a valid arity**

- **Found during:** Task 1 test authoring
- **Issue:** The plan's `<interfaces>` setup called `CasTestHelper.setup_tmp_cas(%{})`, but the actual helper signature is `setup_tmp_cas/0`. Additionally, `Kiln.Artifacts.CAS` uses `Application.compile_env/3` (captured at compile time), so runtime `Application.put_env/3` changes would NOT affect an already-compiled CAS module — meaning the helper call was functionally a no-op for CAS path redirection anyway.
- **Fix:** Removed the `CasTestHelper.setup_tmp_cas(%{})` call entirely from the StageWorker tests. Tests use the module's compiled `priv/artifacts/cas/` path (same as every other Artifacts test in the codebase; there's no parallel-test contention because CAS is content-addressed).
- **Files modified:** `test/kiln/stages/stage_worker_test.exs` (setup block)
- **Verification:** All 8 StageWorker unit tests pass; no fs races observed.
- **Committed in:** `0673781` (Task 1 commit)

### Plan Spec Adjustments (not bugs — hardening)

**8. [Rule 3 — defensive code] `{:error, :unknown_kind}` explicit handling in `perform/1`'s else clause**

- **Found during:** Task 1 authoring
- **Issue:** `Kiln.Stages.ContractRegistry.fetch/1` returns `{:error, :unknown_kind}` for a kind outside `[:planning, :coding, :testing, :verifying, :merge]`. The plan's `<interfaces>` else clause only handled `{:error, {:stage_input_rejected, _}}`, `{:error, :already_completed}`, and `{:error, reason}`. An unknown kind would fall through to `{:error, reason}` which returns `{:error, reason}` to Oban — triggering Oban's retry ladder for what is structurally a fatal input error.
- **Fix:** Added an explicit `{:error, :unknown_kind} = err -> {:cancel, err}` clause. Unknown kinds are boundary violations that should not retry (same category as `:stage_input_rejected`).
- **Files modified:** `lib/kiln/stages/stage_worker.ex`
- **Verification:** The contract registry is a compile-time SSOT; `String.to_existing_atom(args["stage_kind"])` would fail BEFORE `ContractRegistry.fetch/1` if the kind string is off-taxonomy, so this branch is defence-in-depth. No test exercises it specifically (would require injecting an invalid atom post-compile).
- **Committed in:** `0673781` (Task 1 commit)

**Total deviations:** 8 items. 7 auto-fixes (3 Rule-1 bugs, 4 Rule-2 compliance) + 1 Rule-3 defensive hardening. Zero Rule-4 architectural decisions requested. No scope creep; all within-file changes.

## Authentication Gates

None required — this plan only ships Elixir code + docs + tests. No external services, no credentials.

## Verification Evidence

- `mix compile --warnings-as-errors` (dev) — 0 warnings, clean.
- `MIX_ENV=test mix compile --warnings-as-errors` — 0 warnings, clean.
- `mix check_bounded_contexts` — OK — 13 contexts compiled.
- `mix check_no_signature_block` — OK — no v1 workflow populates signature.
- `MIX_ENV=test mix test test/kiln/stages/stage_worker_test.exs` — 8 tests, 0 failures.
- `MIX_ENV=test mix test test/integration/workflow_end_to_end_test.exs --include integration` — 1 test, 0 failures.
- `MIX_ENV=test mix test test/integration/rehydration_test.exs --include integration` — 2 tests, 0 failures.
- `MIX_ENV=test mix test --exclude pending --include integration` — 258 tests, 0 failures (up from 247 at end of 02-07).
- `mix credo lib/kiln/stages/stage_worker.ex test/kiln/stages/stage_worker_test.exs test/integration/workflow_end_to_end_test.exs test/integration/rehydration_test.exs` — clean (0 warnings, 0 readability issues, 0 software design suggestions for my files).
- `mix format --check-formatted lib/kiln/stages/stage_worker.ex test/kiln/stages/stage_worker_test.exs test/integration/workflow_end_to_end_test.exs test/integration/rehydration_test.exs` — clean.
- All 15 Task 1 acceptance greps pass.
- All 16 Task 2 acceptance greps pass.

### `mix check` notes

`mix kiln.boot_checks` (BEAM boot test) fails because the local dev host's Postgres is not reachable by the task (blocked by the port-5432 conflict with `sigra-uat-postgres` documented in STATE.md Blockers since Plan 01-01). This is a PREEXISTING infrastructure concern unrelated to Plan 02-08 — the same failure reproduces on `git stash` of Plan 02-08's changes. `mix kiln.boot_checks` runs green in CI where the compose-provided Postgres is reachable.

`mix format --check-formatted` flags one unrelated preexisting issue in `test/integration/run_subtree_crash_test.exs` (Wave 3 Plan 02-07 file; blank-line drift). Not touched by this plan.

`mix dialyzer` surfaces two preexisting `contract_supertype` warnings in `lib/kiln/stages/stage_run.ex` and `lib/kiln/workflows/schema_registry.ex` (both shipped in Wave 1/2). No new dialyzer issues from Plan 02-08's code.

## Checker-Issue Resolutions

| Issue | Description                                               | Resolution in this plan                                                                                                                                                                                |
| ----- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| #2    | D-75 50 MB cap needs a boundary-rejection regression guard | `test/kiln/stages/stage_worker_test.exs` "oversized spec_ref.size_bytes (50 MB + 1)" test asserts `{:cancel, {:stage_input_rejected, _}}` + audit event + `:escalated` run state.                      |
| #3    | State-machine transition mapping must be locked in plan    | `lib/kiln/stages/stage_worker.ex` encodes the mapping in 4 explicit function heads + `:merge` catch-all; tests under `"transition mapping (LOCKED per Plan 02-08 checker #3)"` assert each edge.        |
| #6    | Tests must use centralised StuckDetectorCase / ObanCase    | Every new test file uses `use Kiln.ObanCase` + `use Kiln.StuckDetectorCase` (unit) or `use Kiln.DataCase` + `use Kiln.RehydrationCase` (integration); no inline `Process.whereis` dances.              |
| #7    | Threat T6 (RunDirector boot-scan sandbox race)            | `test/integration/rehydration_test.exs` uses `Kiln.RehydrationCase.reset_run_director_for_test/0` in `setup`.                                                                                           |
| #8    | Next-stage auto-enqueue deferred to Phase 3 (option (a))   | End-to-end test uses an explicit for-loop to drive stage dispatch (Phase 2 production does NOT auto-enqueue). Plan 02-08 CONTEXT.md `<deferred>` entry documents the Phase-3 hand-off.                 |

## Next Phase Readiness

- **Phase 3 (agent adapters + next-stage auto-dispatcher)** — `Kiln.Stages.StageWorker.stub_dispatch/3` is the clear replacement point for a real `Kiln.Agents.invoke/2` call. The `complete_op` path in `perform/1` is the clear hook point for a Phase-3 `Kiln.Stages.NextStageDispatcher` post-complete wrap. The `:merge` no-op clause is the clear extension point for real merge semantics. The LOCKED Phase-2 mapping for the 4 non-merge kinds is preserved.
- **Phase 3 (BLOCK-01 typed reasons)** — `:invalid_stage_input` atom used here as an escalation reason must be admitted into the Phase-3 typed-reason enum domain; already typed, change is an enum-list extension.
- **Phase 5 (bounded-autonomy caps)** — every kind's stage input contract already requires `budget_remaining: {tokens_usd, tokens, elapsed_seconds}`. Phase 5's BudgetGuard reads those values; the StageWorker happy path today is a stub that validates-then-stubs, so the field is locked in the envelope but not yet consumed.
- **Phase 7 (LiveView)** — PubSub broadcasts reaching `run:<id>` and `runs:board` in this plan's end-to-end test come from `Kiln.Runs.Transitions.transition/3` (audit-paired, tx-committed). Phase 7's subscriber renders the 4-stage progress without any other state source.

## Known Stubs

`Kiln.Stages.StageWorker.stub_dispatch/3` is an intentional Phase-2 stub. It produces a canned `<kind>.md` artifact (literally `"# Stub output for stage_kind=<kind>\n"`) via `Kiln.Artifacts.put/4` instead of invoking a real agent. This is documented in the module's `@moduledoc` ("Phase 2 stubs the agent dispatch — happy path produces a canned artifact … Phase 3 replaces the stub with real per-kind agent adapters"). The stub is NOT a correctness gap for Phase 2's success criteria: the plan explicitly scopes stage dispatch to "exercise the mechanics" (contract validation, intent idempotency, transition issuance, audit trail) without requiring real agent outputs. Phase 3's agent adapters replace this single function with real LLM calls; the rest of the `perform/1` flow is unchanged.

## TDD Gate Compliance

N/A — this plan is `type: execute`, not `type: tdd`. Two tasks committed as `feat` + `feat`:

1. `0673781` (feat) — StageWorker source + unit tests shipped together (atomic)
2. `d94e07d` (feat) — integration tests + doc spec-upgrades shipped together (atomic)

Both tests are regression guards for the Wave-4 contract — they run on every CI build.

## Threat Flags

None new. The plan's `<threat_model>` listed 6 threats (T1–T6); all are either mitigated in this plan or are pre-existing and documented:

- **T1 (deprecated {:discard, …} return)** — mitigated by `{:cancel, reason}` only + acceptance-grep asserting `{:discard,` absence.
- **T2 (correlation_id leak across async tests)** — mitigated by `on_exit(fn -> Logger.metadata(correlation_id: nil) end)` + `async: false` in every test.
- **T3 (integration-test DB row leak)** — mitigated by `Kiln.DataCase` / `Kiln.ObanCase` Ecto sandbox rollback per test.
- **T4 (rehydration `Process.sleep` flake under CI load)** — raised from 200 ms (prior iteration) to 300 ms in `Kiln.RehydrationCase`; if CI flakes emerge, raise to 500 ms.
- **T5 (ARCHITECTURE.md §7 YAML update cross-reference drift)** — scope boundary maintained: only §7's "Example YAML Shape" block replaced, all other YAML references outside §7 preserved.
- **T6 (oversized-input rejection inside agent instead of at boundary)** — explicit 50 MB + 1 byte test in `stage_worker_test.exs` locks the boundary placement.

## Self-Check: PASSED

- All 5 created files exist on disk:
  - `lib/kiln/stages/stage_worker.ex` — FOUND
  - `test/kiln/stages/stage_worker_test.exs` — FOUND
  - `test/integration/workflow_end_to_end_test.exs` — FOUND
  - `test/integration/rehydration_test.exs` — FOUND
  - `.planning/phases/02-workflow-engine-core/02-08-SUMMARY.md` — FOUND
- All 2 task commits present in `git log --all --oneline`:
  - `0673781` (feat(02-08): Kiln.Stages.StageWorker + 50MB boundary rejection test) — FOUND
  - `d94e07d` (feat(02-08): integration tests + D-97..D-100 doc upgrades) — FOUND
- Full `MIX_ENV=test mix test --exclude pending --include integration` suite: 258 tests, 0 failures.
- `mix compile --warnings-as-errors` + `MIX_ENV=test mix compile --warnings-as-errors` both clean.
- `mix check_bounded_contexts` exits 0 with "OK — 13 contexts compiled".
- `mix check_no_signature_block` exits 0 with "OK — no v1 workflow populates signature".
- No unexpected file deletions (git diff --diff-filter=D --name-only across the 2 commits returned nothing).
- No accidental modifications to `prompts/software dark factory prompt.txt` (pre-existing uncommitted file left alone).

---

*Phase: 02-workflow-engine-core*
*Completed: 2026-04-20*
