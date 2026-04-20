---
phase: 02-workflow-engine-core
plan: 05
subsystem: workflow
tags: [workflow, yaml-loader, jsv-validation, topological-sort, digraph, compiled-graph, sha256-checksum, d-62, d-64a, d-65, d-94, ets-hygiene, threat-t1, threat-t5, deferred-items-discharged]

# Dependency graph
requires:
  - phase: 02-workflow-engine-core
    provides: "Plan 02-01 Kiln.Workflows.SchemaRegistry.fetch(:workflow) compile-time JSV root; Kiln.Stages.ContractRegistry.fetch/1 for the 5 stage kinds (D-62 validator 5); Plan 02-00 test fixtures (minimal_two_stage.yaml, missing_entry.yaml, forward_edge_on_failure.yaml, signature_populated.yaml, cyclic.yaml — last rewritten in this plan); Plan 02-04 mix check_no_signature_block gate (now guards priv/workflows/elixir_phoenix_feature.yaml)"
  - phase: 01-foundation-durability-floor
    provides: "JSV 0.18 / yaml_elixir 2.12 deps; :crypto + :erlang.term_to_binary built-ins"

provides:
  - "lib/kiln/workflows/compiled_graph.ex — %Kiln.Workflows.CompiledGraph{} struct: id, version, api_version, metadata, caps, model_profile (string), stages (topologically sorted), stages_by_id, entry_node, checksum (64-char lowercase hex sha256); @enforce_keys guard on 9 required fields; two-key defaults metadata + nothing else"
  - "lib/kiln/workflows/graph.ex — Graph.topological_sort/1 using :digraph.new([:acyclic]) + :digraph_utils.topsort/1 inside try/after :digraph.delete/1 (mandatory ETS cleanup — threat T5). Returns {:ok, [id]} | {:error, :cycle} | {:error, {:missing_dep, id}}"
  - "lib/kiln/workflows/compiler.ex — Compiler.compile/1: 6 D-62 validators (signature-null, single-entry, kinds-have-contracts, toposort+missing-dep, on_failure-ancestor, checksum) + compile-time @kind_atoms / @agent_role_atoms / @sandbox_atoms module-attr maps so String -> atom conversion is load-order-independent (no String.to_existing_atom/1 dependency on Kiln.Stages.StageRun being loaded at run time)"
  - "lib/kiln/workflows/loader.ex — Loader.load/1 + load!/1: YamlElixir (default atoms: false per threat T1) -> string-keyed map -> SchemaRegistry.fetch(:workflow) -> JSV.validate -> JSV.normalize_error (D-63) -> Compiler.compile/1. Typed error shapes {:yaml_parse, _} | {:schema_invalid, _} | {:graph_invalid, atom_or_tuple, map}"
  - "lib/kiln/workflows.ex — public facade (replaces P1 @moduledoc placeholder): defdelegate load/1 + load!/1 + compile/1 + explicit checksum/1; single module alias row and 4 delegations — no business logic in the facade"
  - "priv/workflows/elixir_phoenix_feature.yaml — D-64a canonical realistic 5-stage workflow: plan (planning/planner, entry, readonly) -> code (coding/coder, readwrite, on_failure -> plan) -> test (testing/tester, readwrite, on_failure -> plan) -> verify (verifying/qa_verifier, readonly, on_failure -> plan) -> merge (merge/coder [D-61 separate axes], readwrite, on_failure: escalate [D-59 string const]). Passes full load + compile pipeline; mix check_no_signature_block passes"
  - "test/kiln/workflows/graph_test.exs (10 tests) — topological-sort unit tests covering empty/single/linear/diamond DAGs, :cycle detection at :digraph.add_edge time, downstream-cycle with-entry-node branch, missing-dep takes precedence over cycle when both present, 1000-iteration ETS-leak regression on success AND error paths (threat T5)"
  - "test/kiln/workflows/loader_test.exs (13 tests) — integration tests covering both happy-path fixtures (minimal_two_stage + elixir_phoenix_feature), all 4 D-62 rejection fixtures (cyclic -> :cycle, missing_entry -> :no_entry_node, forward_edge_on_failure -> :on_failure_forward_edge, signature_populated -> :signature_must_be_null), yaml_parse error on missing file, load!/1 raise semantics, Kiln.Workflows facade delegation checks"
  - "test/kiln/workflows/compiler_test.exs (18 tests) — unit tests on raw maps exercising each D-62 validator in isolation: validator 6 (signature object + string + null-accept), validator 1 (no-entry + multiple-entry), validators 2+3 (missing-dep + downstream-cycle), validator 4 (ancestor-accept + descendant-reject + self-equal-position reject per threat T3), validator 5 (all 5 registered kinds compile); 5 checksum invariants (determinism, per-field stability, 64-hex format)"
  - "test/support/fixtures/workflows/cyclic.yaml (rewritten) — discharges the deferred-items.md entry raised in Plan 02-01. New shape: start (valid entry) + loop_a <-> loop_b (2-cycle downstream) so the rejection boundary is the compiler's toposort step (not JSV regex or validator 1)"

affects:
  - "02-06 (Kiln.Runs.Transitions) — Transitions opens a run against a CompiledGraph.entry_node + CompiledGraph.stages; Transitions.transition/3 may use CompiledGraph.stages_by_id[id] to resolve per-stage on_failure routing"
  - "02-07 (Kiln.Runs.RunDirector) — D-94 rehydration integrity assertion reads CompiledGraph.checksum and compares against runs.workflow_checksum; mismatch -> escalate with reason :workflow_changed"
  - "02-08 (Kiln.Stages.StageWorker) — StageWorker.perform/1 reads the run's CompiledGraph.stages_by_id[stage.workflow_stage_id] to resolve kind, timeout, sandbox, retry_policy; on_failure routing drives next-stage enqueue in Phase 3"
  - "Phase 3 — adapter work consumes CompiledGraph.stages[].model_preference + .agent_role; Kiln.Agents.SessionSupervisor dispatches based on .agent_role"

# Tech tracking
tech-stack:
  added:
    - "None — yaml_elixir 2.12 + JSV 0.18 + :crypto + :erlang all shipped in Phase 1"
  patterns:
    - "Compile-time SSOT for String -> atom conversion at the schema boundary: Compiler defines @kind_atoms / @agent_role_atoms / @sandbox_atoms module attributes as explicit decode tables. This replaces the RESEARCH.md-Pattern-2 suggestion of String.to_existing_atom/1 because (a) the downstream atom-owning module (Kiln.Stages.StageRun) may not be loaded when Compiler runs under `mix run` or `mix check`, (b) the explicit map keeps the D-58 enum SSOT visible for review, and (c) Map.fetch!/2 surfaces a clean KeyError on unknown values instead of the opaque `:not an already existing atom` ArgumentError"
    - ":digraph ETS-hygiene pattern: every :digraph.new/1 call is wrapped in try/after :digraph.delete/1 — MANDATORY, not optional. :digraph tables are ETS-backed and NOT garbage-collected; a forgotten delete leaks one table per call. Test suite carries a 1000-iteration regression test that asserts length(:ets.all/0) did not grow meaningfully — structural enforcement beyond code review"
    - "Deterministic sha256 checksum via :erlang.term_to_binary(term, [:deterministic]) + :crypto.hash(:sha256, _). The `:deterministic` option sorts map keys and normalises term-level ordering so the sha is stable across BEAM nodes / restarts / iex sessions. Term shape is {id, version, api_version, model_profile, caps, [per-stage tuple]} — shape-significant fields only; metadata (description/author/tags) intentionally excluded so cosmetic workflow edits do not invalidate D-94 rehydration integrity"
    - "Explicit yaml_elixir-option-absence pattern: `YamlElixir.read_from_file(path)` is called WITHOUT options (no `atoms: true`) by design — the default `atoms: false` is the DoS-prevention posture per D-63 / threat T1. Loader moduledoc documents the rule; the Plan 02-04 `mix check_no_signature_block` task gives the project-wide grep gate"
    - "Typed-error normalisation at the loader boundary: JSV validation errors pass through `JSV.normalize_error/1` so raw JSV internals never reach the UI/audit log (D-63). Compiler error tuples follow `{:graph_invalid, reason, detail}` — reason is atom OR a 2-tuple tagged by the first element, detail is always a map. Loader wraps yaml_elixir errors in `{:yaml_parse, term()}` — three top-level error classes, each with a stable shape"
    - "Threat T3 mitigation structurally: validate_on_failure_ancestors/2 uses `>= ` (not `>`) when comparing topological positions — rejects not just forward edges but also self-references and sibling-at-equal-position references. Test coverage exists for both descendant-reject and self-equal-position-reject branches"

key-files:
  created:
    - "lib/kiln/workflows/compiled_graph.ex (73 lines) — CompiledGraph struct with @enforce_keys"
    - "lib/kiln/workflows/graph.ex (86 lines) — :digraph-based topological_sort/1 with mandatory ETS cleanup"
    - "lib/kiln/workflows/compiler.ex (214 lines) — 6 D-62 validators + sha256 checksum; compile-time String -> atom maps for load-order safety"
    - "lib/kiln/workflows/loader.ex (95 lines) — YAML -> string-map -> JSV -> Compiler pipeline with typed-error normalisation"
    - "priv/workflows/elixir_phoenix_feature.yaml (85 lines) — D-64a canonical 5-stage realistic workflow"
    - "test/kiln/workflows/graph_test.exs (113 lines, 10 tests) — topological-sort unit tests + ETS-leak regression"
    - "test/kiln/workflows/loader_test.exs (118 lines, 13 tests) — load/load! happy + 4 D-62 failure paths + yaml_parse + facade delegation"
    - "test/kiln/workflows/compiler_test.exs (236 lines, 18 tests) — per-validator unit tests + 5 checksum invariants"
  modified:
    - "lib/kiln/workflows.ex — replaced P1 @moduledoc-only placeholder (10 lines) with real facade (39 lines) wiring Loader + Compiler + checksum/1"
    - "test/support/fixtures/workflows/cyclic.yaml — rewrote single-char-id fixture (a/b/c) to valid-entry + 2-cycle shape (start + loop_a <-> loop_b) so the rejection boundary is the compiler's toposort step, discharging the deferred-items.md entry from Plan 02-01"
    - ".planning/phases/02-workflow-engine-core/deferred-items.md — added Status column and marked the 02-01 cyclic.yaml entry as Resolved in 02-05 Task 2"

key-decisions:
  - "Compile-time String -> atom maps instead of String.to_existing_atom/1. When Compiler.compile/1 runs inside `mix run` or `mix check` (where application modules are loaded lazily), the atoms `:planning` / `:coder` / `:readonly` etc. may not yet be interned even though Kiln.Stages.StageRun's @kinds / @agent_roles / @sandboxes module attrs would eventually intern them. The explicit `@kind_atoms %{\"planning\" => :planning, ...}` module attribute interns the atoms AT COMPILER'S compile time and gives a load-order-independent decode path. Also produces a cleaner error (KeyError on unknown string) than ArgumentError from String.to_existing_atom/1."
  - "CompiledGraph.model_profile is a string, not an atom. D-57 names 6 model-profile values (:elixir_lib, :phoenix_saas_feature, :typescript_web_feature, :python_cli, :bugfix_critical, :docs_update) but no bounded context has yet materialised these as an Ecto.Enum. Kiln.ModelRegistry is Phase 3. Keeping the field as a string avoids introducing a fourth @*_atoms decode map and sidesteps the enum-drift risk (schema JSON already is the SSOT). Downstream consumers (Plan 02-06 Transitions, Plan 02-07 RunDirector) read it as-is for snapshot into runs.model_profile_snapshot."
  - "Checksum term excludes metadata. :erlang.term_to_binary({id, version, api_version, model_profile, caps, [stage tuples]}) intentionally omits `metadata` (description/author/tags). D-94's goal is 'did the workflow semantically change between run-start and rehydration?' — editing a tag or description shouldn't force an in-flight run to escalate with :workflow_changed. Shape-significant fields only. The per-stage tuple covers id/kind/agent_role/depends_on/timeout/retry_policy/sandbox/model_preference/on_failure so any semantic stage change flips the sha."
  - "Discharged the deferred cyclic.yaml fixture issue inline. Prior-wave context explicitly named me as the owner of fixing the single-char-IDs regression raised in Plan 02-01. Rewrote the fixture to a valid-entry + 2-cycle shape (start + loop_a <-> loop_b) so the loader_test.exs must_haves truth #3 (`cyclic.yaml rejected with :cycle`) is actually exercised — the prior shape would have been rejected by JSV regex before the compiler ever ran. deferred-items.md updated with a Status column and the entry marked Resolved."
  - "Shipped MORE tests than the plan specified (10/13/18 instead of 7/7/6) to get 1-test-per-validator-branch coverage, separate ancestor/descendant/self-equal-position branches on validator 4, and two separate ETS-leak regressions (success path + error path). Widening test coverage is not scope creep; it is a safer baseline for Plan 02-06 + 02-07 which depend on CompiledGraph's contract."

patterns-established:
  - "YAML-validated-boundary + typed error three-class: {:yaml_parse, _} | {:schema_invalid, normalized_map} | {:graph_invalid, reason_atom_or_tuple, detail_map}. Every workflow-consumption site (Loader, Transitions, RunDirector) deals with exactly these three classes; no raw yaml_elixir or JSV error tuples leak. Downstream audit-event payloads can use the same shape"
  - ":digraph try/after cleanup as the canonical Elixir ETS-backed-resource-hygiene pattern. Applies to any future Kiln code that uses :ets.new (e.g. Phase 3 sandbox session table, Phase 7 LiveView subscription table) — the ergonomic shape is `try do WORK after :digraph.delete(g) end` not `cleanup-first-on-success; cleanup-again-in-rescue/2` which misses the normal error-tuple paths"
  - "Deterministic checksum via :erlang.term_to_binary(_, :deterministic) + :crypto.hash(:sha256, _) is the Kiln pattern for any future integrity assertion (workflow graph, stage-contract body, audit-event payload). The `:deterministic` option is non-negotiable — without it, map-key iteration order is VM-state-dependent and the checksum churns across nodes"

requirements-completed: [ORCH-01]

# Metrics
duration: ~7min
completed: 2026-04-20
---

# Phase 02 Plan 05: Workflow Loader Pipeline + Realistic 5-Stage Workflow Summary

**The engine's ORCH-01 entry point is live. `Kiln.Workflows.load!/1` reads a YAML file, JSV-validates against the D-55..D-59 dialect, runs 6 D-62 Elixir-side validators (signature-null, single-entry, kinds-have-contracts, toposort+missing-dep, on_failure-ancestor), topologically sorts via `:digraph` with mandatory ETS cleanup, and returns a `%CompiledGraph{}` with a deterministic 64-char-hex sha256 checksum. The canonical realistic 5-stage workflow (`priv/workflows/elixir_phoenix_feature.yaml`) exercises every engine path.**

## Performance

- **Duration:** ~7 min
- **Tasks:** 2 / 2 complete
- **Files created:** 8 (5 Elixir source + 1 YAML + 3 tests — wait: 5 lib + 1 priv + 3 test = 9; see Files section)
- **Files modified:** 3 (lib/kiln/workflows.ex real facade, test/support/fixtures/workflows/cyclic.yaml fixture rewrite, deferred-items.md status column)
- **New tests:** 41 (10 graph + 13 loader + 18 compiler)
- **Full suite:** 206 tests / 0 failures (up from 165 at end of Plan 02-04)

## Accomplishments

- **Full ORCH-01 load + compile pipeline lands in one plan.** `Kiln.Workflows.load!/1` is the entry point Plan 02-06 Transitions + Plan 02-07 RunDirector + Plan 02-08 StageWorker all consume. The 5 lib files + 1 facade module compose cleanly; no forward-decl stubs, no Phase-3 placeholder wiring.
- **6 D-62 validators are each covered by a dedicated test branch.** Validator 6 (signature-null) has 3 branches (object reject / string reject / null accept). Validator 4 (on_failure ancestor) has 3 branches (ancestor accept / descendant reject / self-equal-position reject per threat T3 — the `>=` vs `>` subtlety is structurally tested). Validator 5 (kind contract) iterates all 5 registered kinds. Every failure path in the plan's must_haves truths is exercised on both a fixture (loader_test) and a raw map (compiler_test).
- **ETS leak regression is structural, not advisory.** Plan 02-05 ships two separate 1000/500-iteration loops (`graph_test.exs`) that assert `length(:ets.all/0)` did not grow meaningfully on success AND error paths. A future refactor that forgets `:digraph.delete/1` fails these tests loud, not silently at production-day-30.
- **Realistic 5-stage workflow (D-64a) passes the full pipeline.** `priv/workflows/elixir_phoenix_feature.yaml` loads into a 5-stage CompiledGraph in topological order [plan, code, test, verify, merge] with a 64-char hex checksum. Every stage kind is exercised (planning + coding + testing + verifying + merge). `mix check_no_signature_block` gate (Plan 02-04) now has real content to guard.
- **Deferred item from Plan 02-01 discharged inline.** Prior-wave context flagged me as the owner of the cyclic.yaml single-char-id regression. Fixture rewritten to `start` + `loop_a <-> loop_b` (valid entry + downstream cycle); deferred-items.md status-column updated.

## Task Commits

Each task was committed atomically:

1. **Task 1: CompiledGraph + Graph + Compiler + Loader + priv/workflows fixture** — `f5f689d` (feat)
2. **Task 2: Kiln.Workflows facade + 3 test files + cyclic.yaml fixture rewrite** — `0f7f7e6` (test)

## Files Created / Modified

### Created (8)

**Elixir source (4):**
- `lib/kiln/workflows/compiled_graph.ex` — %CompiledGraph{} struct with @enforce_keys
- `lib/kiln/workflows/graph.ex` — Graph.topological_sort/1 with mandatory :digraph.delete/1
- `lib/kiln/workflows/compiler.ex` — 6 D-62 validators + sha256 checksum
- `lib/kiln/workflows/loader.ex` — YAML -> JSV -> Compiler pipeline

**Workflow YAML (1):**
- `priv/workflows/elixir_phoenix_feature.yaml` — D-64a canonical 5-stage realistic workflow

**Tests (3):**
- `test/kiln/workflows/graph_test.exs` (10 tests)
- `test/kiln/workflows/loader_test.exs` (13 tests)
- `test/kiln/workflows/compiler_test.exs` (18 tests)

### Modified (3)

- `lib/kiln/workflows.ex` — P1 @moduledoc placeholder -> real facade (load/1, load!/1, compile/1, checksum/1)
- `test/support/fixtures/workflows/cyclic.yaml` — single-char-id shape -> valid-entry + downstream-cycle shape (discharges Plan 02-01 deferred item)
- `.planning/phases/02-workflow-engine-core/deferred-items.md` — added Status column, marked entry Resolved

## D-62 Validator Coverage Matrix

| Validator | Name | Compiler branch | Graph test | Loader test | Compiler test |
|-----------|------|-----------------|------------|-------------|---------------|
| 1 | single entry node | `validate_single_entry/1` | — | `missing_entry.yaml -> :no_entry_node` | `rejects workflow with no entry node`, `rejects workflow with multiple entry nodes` |
| 2 | topological sort | `topological_sort/1` (via Graph) | `cycle a->b->a`, `3-node cycle with valid upstream entry`, `missing-dep takes precedence over cycle` | `cyclic.yaml -> :cycle` | `rejects workflow with a downstream cycle` |
| 3 | depends_on resolvable | `Graph.topological_sort/1` missing-dep branch | `missing dep returns {:error, {:missing_dep, id}}` | (covered by cyclic rewrite) | `rejects workflow with missing dep` |
| 4 | on_failure.to is strict ancestor | `validate_on_failure_ancestors/2` | — | `forward_edge_on_failure.yaml -> :on_failure_forward_edge` | `accepts on_failure pointing to a topological ancestor`, `rejects on_failure pointing to a descendant`, `rejects on_failure pointing to self` |
| 5 | every kind has contract | `validate_all_kinds_have_contracts/1` | — | (real workflow has all 5 kinds — full sweep implicit) | `accepts all 5 registered kinds` (iterated) |
| 6 | signature: null (v1) | `validate_signature_null/1` | — | `signature_populated.yaml -> :signature_must_be_null` | `rejects signature populated with an object`, `rejects signature populated with a string`, `accepts signature: null` |

## Checksum Algorithm Choice (D-94)

```elixir
term = {g.id, g.version, g.api_version, g.model_profile, g.caps,
        Enum.map(g.stages, fn s ->
          {s.id, s.kind, s.agent_role, s.depends_on, s.timeout_seconds,
           s.retry_policy, s.sandbox, s.model_preference, s.on_failure}
        end)}
bin = :erlang.term_to_binary(term, [:deterministic])
:crypto.hash(:sha256, bin) |> Base.encode16(case: :lower)
```

**Rationale:**

1. `:erlang.term_to_binary(_, :deterministic)` — ships with OTP, sorts map keys, normalises small-integer encoding. Independent of BEAM map iteration order (which depends on insertion order + resize state). Gives a reproducible 64-char hex string across nodes and restarts.
2. `:crypto.hash(:sha256, _)` — the D-94 integrity mechanism. Requires a SHA-256 collision to swap a workflow file and have rehydration still match; that's out of threat model. Other hash choices (`:blake2b`, `:sha3_256`) would also work but `:sha256` is the Phase 1 audit-payload precedent.
3. **Term shape is shape-significant fields ONLY** — metadata (description/author/tags) is intentionally excluded. D-94's goal is "did the workflow SEMANTICALLY change?"; editing a tag or description is cosmetic and shouldn't trigger `:workflow_changed` escalation.
4. **Stages are iterated in topological order** — the checksum captures the specific topsort the compiler produced. A reordering of stages in the YAML that produces a different valid topsort (e.g. diamond b vs c) would flip the sha. That's intentional: downstream stage_runs are keyed by `workflow_stage_id`; keep the ordering authoritative.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — fixture regression from Plan 02-01] cyclic.yaml single-char IDs would bypass compiler toposort**

- **Found during:** Task 2 setup — the loader_test `must_haves` truth #3 requires `cyclic.yaml -> :cycle`, but the current fixture (shipped by Plan 02-00, flagged as a deferred item by Plan 02-01 verification) uses stage IDs `a`/`b`/`c` which violate the D-58 regex `^[a-z][a-z0-9_]{1,31}$` (min 2 chars). JSV would reject the file at the schema layer BEFORE the compiler ran — the test would see `{:error, {:schema_invalid, _}}`, not `{:error, {:graph_invalid, :cycle, _}}`.
- **Fix:** Rewrote the fixture to `start` (valid entry, depends_on: [], satisfies D-58) + `loop_a` + `loop_b` with loop_a depending on [start, loop_b] and loop_b depending on [loop_a]. This gives a valid single entry node (D-62 validator 1 passes) AND a 2-cycle downstream (D-62 validator 2 fails at `:digraph.add_edge` with the :acyclic flag). The rejection boundary is now the compiler's toposort step — exactly what the test requires. Also updated `.planning/phases/02-workflow-engine-core/deferred-items.md` to add a Status column and mark the Plan 02-01 entry Resolved.
- **Files modified:** `test/support/fixtures/workflows/cyclic.yaml`, `.planning/phases/02-workflow-engine-core/deferred-items.md`
- **Verification:** `Loader.load("test/support/fixtures/workflows/cyclic.yaml")` returns `{:error, {:graph_invalid, :cycle, %{}}}`; loader_test's "cyclic.yaml rejected with :cycle" branch passes.
- **Committed in:** `0f7f7e6`

**2. [Rule 1 — atom load-order dependency] String.to_existing_atom/1 crashes under `mix run`**

- **Found during:** Task 1 smoke test (`mix run -e 'Kiln.Workflows.Loader.load!("priv/workflows/elixir_phoenix_feature.yaml")'`)
- **Issue:** RESEARCH.md Pattern 2 + plan spec `<interfaces>` suggested `String.to_existing_atom/1` for converting `kind`/`agent_role`/`sandbox` strings to atoms. These atoms (`:planning`, `:coder`, `:readonly`, etc.) exist in `Kiln.Stages.StageRun`'s `@kinds` / `@agent_roles` / `@sandboxes` module attributes — but only AFTER that module is loaded. Under `mix run` or `mix check`, module loading is lazy; `Kiln.Stages.StageRun` is not loaded when the Compiler runs, so `String.to_existing_atom("planner")` raised `ArgumentError: not an already existing atom`.
- **Fix:** Replaced `String.to_existing_atom/1` with three explicit module-attribute decode maps — `@kind_atoms`, `@agent_role_atoms`, `@sandbox_atoms` — inside `Kiln.Workflows.Compiler`. The `%{"planning" => :planning, ...}` literal syntax interns the atoms at Compiler's OWN compile time, giving a load-order-independent decode path. Also produces a cleaner error (`KeyError` on unknown value) than the opaque `ArgumentError` from `String.to_existing_atom/1`. JSV has already validated the string is a member of the D-58 enum before the decode runs, so `Map.fetch!/2` is safe.
- **Files modified:** `lib/kiln/workflows/compiler.ex` (added 3 module-attribute decode maps; replaced 3 String.to_existing_atom calls)
- **Verification:** `mix run -e 'Kiln.Workflows.Loader.load!("priv/workflows/elixir_phoenix_feature.yaml")'` succeeds, reports 5 stages + entry `plan` + 64-char checksum.
- **Committed in:** `f5f689d`

**3. [Rule 2 — critical functionality widening] CompiledGraph.model_profile stored as string, not atom**

- **Found during:** Task 1 compiler authoring
- **Issue:** Plan spec `<interfaces>` had `model_profile: atom()` in the CompiledGraph @type, wired via `String.to_existing_atom(raw["spec"]["model_profile"])`. But no bounded context has yet materialised the D-57 model-profile enum as atoms — `Kiln.ModelRegistry` is Phase 3 scope, and no `Ecto.Enum values:` list exists that would have interned `:elixir_lib` / `:phoenix_saas_feature` etc. `String.to_existing_atom` would always raise. Adding a 4th decode map would expand the enum SSOT surface needlessly.
- **Fix:** Kept `model_profile` as a string in the struct + @type. Downstream consumers (Plan 02-06 Transitions storing into `runs.model_profile_snapshot` JSONB, Plan 02-07 RunDirector snapshot assertion, Phase 3 ModelRegistry) read it as-is. Schema JSON remains the enum SSOT per D-57. No loss of type safety at the Ecto boundary (the column is `:map`, JSONB storage is string-native anyway).
- **Files modified:** `lib/kiln/workflows/compiled_graph.ex`, `lib/kiln/workflows/compiler.ex`
- **Verification:** `CompiledGraph.model_profile == "elixir_lib"` in the real-workflow smoke test; compiler_test asserts checksum churns when `model_profile` changes (i.e., the field is shape-significant for D-94).
- **Committed in:** `f5f689d`

### Non-breaking adjustments (widening)

**4. Shipped more tests than specified.** Plan acceptance criteria said 7 graph + 7 loader + 6 compiler = 20. Shipped 10 + 13 + 18 = 41. The extra tests cover branches the plan missed: compiler validator 6 has 3 separate branches (object / string / null-accept) to guard against a future refactor dropping any one; validator 4 has 3 branches (ancestor / descendant / self-equal-position) for threat T3; the graph ETS-leak regression runs on both success and error paths; the facade delegation is verified explicitly. Widening coverage for downstream plans' safety, not scope creep.

**Total deviations:** 3 Rule-1/Rule-2 auto-fixes (1 pre-existing fixture regression now resolved, 1 plan-spec atom-load-order bug, 1 plan-spec type-annotation-vs-reality mismatch); 1 non-breaking test-count widening. All in the commit chain; no uncommitted hangovers.

## Deferred Items Discharged

| Plan | Item | Resolved in |
|------|------|-------------|
| 02-01 | `test/support/fixtures/workflows/cyclic.yaml` uses single-char stage ids that violate D-58 regex | **02-05 Task 2** (`0f7f7e6`) — rewrote to valid-entry + downstream-cycle shape |

## Issues Encountered

None beyond the deviations above. No auth gates. No orchestration issues. No CI gate regressions.

## Authentication Gates

None required.

## Verification Evidence

- `mix compile --warnings-as-errors` (dev) — 0 warnings, clean
- `MIX_ENV=test mix compile --warnings-as-errors` — 0 warnings, clean
- `MIX_ENV=test mix test test/kiln/workflows/` — 46 tests, 0 failures (5 pre-existing schema-registry + 41 new graph/loader/compiler)
- `MIX_ENV=test mix test --exclude pending` — 206 tests, 0 failures (up from 165; +41 new)
- `KILN_SKIP_BOOTCHECKS=1 MIX_ENV=test mix run -e 'cg = Kiln.Workflows.load!("priv/workflows/elixir_phoenix_feature.yaml"); IO.puts("id=#{cg.id} stages=#{length(cg.stages)} entry=#{cg.entry_node} checksum_len=#{String.length(cg.checksum)}")'` — id=elixir_phoenix_feature stages=5 entry=plan checksum_len=64
- `mix check_no_signature_block` — OK (priv/workflows/elixir_phoenix_feature.yaml has signature: null)
- `mix check_bounded_contexts` — OK (13 contexts loaded)
- Acceptance greps (Task 1, 13 checks, all pass):
  - `grep -q "defstruct" lib/kiln/workflows/compiled_graph.ex` ✓
  - `grep -q "@enforce_keys" lib/kiln/workflows/compiled_graph.ex` ✓
  - `grep -q ":digraph.new(\[:acyclic\])" lib/kiln/workflows/graph.ex` ✓
  - `grep -q ":digraph.delete" lib/kiln/workflows/graph.ex` ✓
  - `grep -q "signature_must_be_null" lib/kiln/workflows/compiler.ex` ✓
  - `grep -q "on_failure_forward_edge" lib/kiln/workflows/compiler.ex` ✓
  - `grep -q "ContractRegistry.fetch" lib/kiln/workflows/compiler.ex` ✓
  - `grep -q ":crypto.hash(:sha256" lib/kiln/workflows/compiler.ex` ✓
  - `grep -q "SchemaRegistry.fetch(:workflow)" lib/kiln/workflows/loader.ex` ✓
  - `grep -q "JSV.normalize_error" lib/kiln/workflows/loader.ex` ✓
  - `grep -q "apiVersion: kiln.dev/v1" priv/workflows/elixir_phoenix_feature.yaml` ✓
  - `grep -q "signature: null" priv/workflows/elixir_phoenix_feature.yaml` ✓
  - `grep -c "kind:" priv/workflows/elixir_phoenix_feature.yaml` = 5 (>= 5) ✓
- Acceptance greps (Task 2, 8 checks, all pass):
  - `grep -q "defdelegate load(path), to: Loader" lib/kiln/workflows.ex` ✓
  - `grep -q "def checksum" lib/kiln/workflows.ex` ✓
  - `MIX_ENV=test mix test test/kiln/workflows/graph_test.exs` — 10 tests, 0 failures ✓
  - `MIX_ENV=test mix test test/kiln/workflows/loader_test.exs` — 13 tests, 0 failures ✓
  - `MIX_ENV=test mix test test/kiln/workflows/compiler_test.exs` — 18 tests, 0 failures ✓
  - `mix compile --warnings-as-errors` — clean ✓
  - `grep -q ":ets.all" test/kiln/workflows/graph_test.exs` ✓
  - `mix check_no_signature_block` — OK on priv/workflows/elixir_phoenix_feature.yaml ✓

## Next Plan Readiness

- **Plan 02-06 (Kiln.Runs.Transitions)** — can construct a run from a CompiledGraph: `runs.workflow_id = cg.id`, `runs.workflow_version = cg.version`, `runs.workflow_checksum = cg.checksum`, `runs.caps_snapshot = cg.caps`, `runs.model_profile_snapshot = %{profile: cg.model_profile, ...}`. The initial stage to dispatch is `cg.entry_node`.
- **Plan 02-07 (Kiln.Runs.RunDirector)** — D-94 rehydration integrity assertion: `Kiln.Workflows.load("priv/workflows/#{run.workflow_id}.yaml")` → if `cg.checksum != run.workflow_checksum` → escalate with `reason: :workflow_changed`. The compiled graph stays in memory for the duration of the rehydrated subtree; Plan 02-07 can decide whether to ets-cache or recompute-on-demand.
- **Plan 02-08 (Kiln.Stages.StageWorker)** — per-stage dispatch uses `cg.stages_by_id[run.current_stage_id]` to resolve `kind` (for ContractRegistry.fetch), `timeout_seconds` (for Oban timeout), `sandbox` (for Phase 3 sandbox worker), `retry_policy`, and `on_failure` (for post-complete next-stage routing).

## Known Stubs

None. Every module shipped is real behavior: CompiledGraph is the canonical in-memory shape; Graph.topological_sort/1 is the production DAG checker; Compiler.compile/1 runs 6 real validators; Loader.load/1 is the real YAML boundary; the facade delegates to real implementations. The realistic workflow is not a stub — it exercises every engine path the phase demands.

## Threat Flags

None. Plan 02-05 does not introduce new network endpoints, authentication paths, file-write patterns, or trust boundaries beyond what's already in the `<threat_model>` block of the plan. The 5 threats (T1-T5) listed in the plan are all mitigated structurally:

- **T1 (yaml atom exhaustion)** — `YamlElixir.read_from_file(path)` called without options; default `atoms: false` preserved; loader moduledoc documents the rule.
- **T2 (JSV $ref bomb)** — handled in Plan 02-01 (compile-time JSV build); no runtime schema loading in this plan.
- **T3 (on_failure equal-position bypass)** — `validate_on_failure_ancestors/2` uses `>=` (strict-less-than is the only valid ancestor relation); compiler_test covers self-equal-position reject branch.
- **T4 (checksum collision)** — SHA-256 + deterministic term serialisation; requires SHA-256 collision to swap.
- **T5 (:digraph ETS leak)** — mandatory `try/after :digraph.delete/1`; two separate 1000/500-iteration regression tests.

## Self-Check: PASSED

- All 8 created files exist on disk:
  - `lib/kiln/workflows/compiled_graph.ex` ✓
  - `lib/kiln/workflows/graph.ex` ✓
  - `lib/kiln/workflows/compiler.ex` ✓
  - `lib/kiln/workflows/loader.ex` ✓
  - `priv/workflows/elixir_phoenix_feature.yaml` ✓
  - `test/kiln/workflows/graph_test.exs` ✓
  - `test/kiln/workflows/loader_test.exs` ✓
  - `test/kiln/workflows/compiler_test.exs` ✓
- Both task commits present in `git log --all --oneline`:
  - `f5f689d` (feat(02-05): workflow loader pipeline + realistic 5-stage workflow) ✓
  - `0f7f7e6` (test(02-05): workflows facade + 3 D-62 validator coverage test files) ✓
- Full `MIX_ENV=test mix test --exclude pending` suite: 206 tests, 0 failures.
- `mix compile --warnings-as-errors` + `MIX_ENV=test mix compile --warnings-as-errors` both clean.
- `mix check_no_signature_block` passes against priv/workflows/elixir_phoenix_feature.yaml.
- `mix check_bounded_contexts` passes (13 contexts loaded).
- No unexpected file deletions in either task commit (`git diff --diff-filter=D --name-only HEAD~2 HEAD` returns nothing).
- Deferred item from Plan 02-01 (cyclic.yaml single-char IDs) is Resolved in `0f7f7e6`.

---

*Phase: 02-workflow-engine-core*
*Completed: 2026-04-20*
