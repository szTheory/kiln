---
phase: 02-workflow-engine-core
plan: 07
subsystem: infra
tags: [supervision-tree, dynamic-supervisor, permanent-genserver, run-director, run-subtree, one-for-all, transient, process-monitor, boot-scan, periodic-scan, rehydration, workflow-checksum, d-91, d-92, d-94, d-95, d-97, orch-02, orch-04, checker-issue-1, checker-issue-5, checker-issue-7]

# Dependency graph
requires:
  - phase: 02-workflow-engine-core
    provides: "Plan 02-02 Kiln.Runs.Run 9-state enum + Kiln.Runs.list_active/0 + runs_active_state_idx partial index; Plan 02-03 Kiln.Artifacts (13th bounded context); Plan 02-04 mix check_bounded_contexts Mix task source + check_oban_queue_budget!/0 (6th invariant in slot 4); Plan 02-05 Kiln.Workflows.SchemaRegistry + Kiln.Workflows.load/1 + CompiledGraph.checksum; Plan 02-06 Kiln.Runs.Transitions.transition/3 + Kiln.Policies.StuckDetector module"
  - phase: 01-foundation-durability-floor
    provides: "Kiln.Supervisor :one_for_one parent strategy + staged-boot pattern (infra children -> BootChecks.run!/0 -> Endpoint); Kiln.BootChecks.Error + invariant-chain template; Kiln.RunRegistry :unique Registry; D-42 child-count invariant as a test contract"

provides:
  - "lib/kiln/runs/run_supervisor.ex — DynamicSupervisor (:one_for_one, max_children: 10) per D-95 — per-run subtree host"
  - "lib/kiln/runs/run_subtree.ex — per-run Supervisor (:one_for_all, :transient) with a minimal Task.Supervisor lived-child (registered via Kiln.RunRegistry under {Kiln.Runs.RunSubtree.Tasks, run_id}) + public lived_child_pid/1 helper. Phase 3 swaps the Task.Supervisor for Kiln.Agents.SessionSupervisor + Kiln.Sandboxes.Supervisor."
  - "lib/kiln/runs/run_director.ex — :permanent singleton GenServer. init/1 returns {:ok, state} immediately and sends :boot_scan to self async (D-92 — no supervisor boot blocking). handle_info(:boot_scan / :periodic_scan) re-hydrates from Kiln.Runs.list_active/0; periodic scan every 30s via Process.send_after/3; {:DOWN, ref, :process, pid, reason} observes crashed subtrees + logs. D-94 workflow-checksum assertion via Kiln.Workflows.load/1 vs runs.workflow_checksum — mismatch / missing-file escalates the run through Kiln.Runs.Transitions.transition/3 with reason :workflow_changed (audit-paired, PubSub-broadcast). Periodic scan filters already-monitored runs via MapSet on monitor-table values — idempotent under repeated :boot_scan / :periodic_scan messages."
  - "lib/kiln/application.ex — infra_children extended 6 -> 9 (adds Kiln.Runs.RunSupervisor, {Kiln.Runs.RunDirector, []}, Kiln.Policies.StuckDetector in positions 7/8/9). KilnWeb.Endpoint remains the dynamic 10th child started via Supervisor.start_child/2 AFTER Kiln.BootChecks.run!/0. Post-boot `Supervisor.which_children(Kiln.Supervisor)` returns EXACTLY 10 entries."
  - "lib/kiln/boot_checks.ex — @context_modules extended 12 -> 13 (adds Kiln.Artifacts per D-97); context_count/0 returns 13; @type context_module union updated in lockstep. New 5th invariant check_workflow_schema_loads!/0 wired into run!/0 chain AFTER Plan 02-04's check_oban_queue_budget!/0 and BEFORE check_required_secrets!/0 — asserts Kiln.Workflows.SchemaRegistry.fetch(:workflow) returns {:ok, _}."
  - "test/kiln/application_test.exs — child-count assertion 7 -> 10; explicit assertions that Kiln.Runs.RunSupervisor + Kiln.Runs.RunDirector + Kiln.Policies.StuckDetector are alive + registered; forbidden-children list pruned of the 3 new legitimate children."
  - "test/kiln/boot_checks_test.exs — context_count/0 assertion 12 -> 13; new Kiln.Artifacts-in-@context_modules assertion; new describe block for :workflow_schema_loads (happy path); new describe block asserting Plan 02-04's :oban_queue_budget invariant is preserved in the run!/0 chain."
  - "test/kiln/runs/run_director_test.exs — unit tests for :boot_scan discovery, D-94 workflow-checksum-mismatch escalation path, and periodic-scan idempotency. Uses Kiln.RehydrationCase.reset_run_director_for_test/0 to mitigate threat T6 (pre-sandbox-allow DB-connection race). No @tag :skip — the previously-skipped :boot_scan test is live (checker issue #1)."
  - "test/integration/run_subtree_crash_test.exs — ORCH-02 signature test. Two scenarios: (a) single-crash absorption (:one_for_all restart + peer-subtree isolation + director survival); (b) budget-trip escalation (4 rapid kills exhaust max_restarts: 3 / max_seconds: 5; subtree terminates; RunDirector stays alive). Addresses checker issue #1 — ORCH-02 now has an active end-to-end test, not an @tag :skip stub."
  - ".check.exs — mix check_bounded_contexts gate comment updated to reflect ACTIVATED status (the two SSOTs — BootChecks @context_modules and the Mix task's @expected — are now in sync at 13; Plan 02-04 shipped the source with deferred activation per checker issue #5 option (b), Plan 02-07 is the paired activation)."

affects:
  - "02-08 (Kiln.Stages.StageWorker) — StageWorker will be dispatched by Oban into the :stages queue; its perform/1 reads the run's CompiledGraph via Kiln.Runs + Kiln.Workflows, validates input against Kiln.Stages.ContractRegistry, and calls Kiln.Runs.Transitions.transition/3 on completion. The rehydration + crash-isolation contract that 02-07 just proved is what lets StageWorker trust 'the run exists in DB + has a live per-run subtree when I run' as a precondition."
  - "Phase 3 (agents + sandboxes) — Kiln.Runs.RunSubtree's Phase 2 Task.Supervisor lived-child is replaced with Kiln.Agents.SessionSupervisor + Kiln.Sandboxes.Supervisor. The :one_for_all strategy, :transient restart type, Registry-based naming, lived_child_pid/1 helper contract, and the ORCH-02 integration test all remain unchanged — Phase 3 is a pure child-list swap inside init/1."
  - "Phase 3 (BLOCK-01 typed reasons) — RunDirector's D-94 escalation path uses Kiln.Runs.Transitions.transition/3 with reason :workflow_changed (an atom). When BLOCK-01's typed-reason enum domain lands in Phase 3, RunDirector's :workflow_changed reason must be admitted into that enum (it's already a typed atom, so the change is an enum-list extension, not a code refactor)."
  - "Phase 5 (StuckDetector full body + Artifacts Gc/Scrub activation) — StuckDetector is now a live :permanent child. When Phase 5 replaces the no-op handle_call({:check, _ctx}, ...) body with the sliding-window implementation, the child-spec + supervision shape remain as-is (zero supervisor-tree churn)."
  - "Phase 7 (LiveView dashboard) — Kiln.Runs.RunDirector is a PubSub consumer's dependency: LiveViews subscribe to `run:<id>` and `runs:board` topics broadcast by Kiln.Runs.Transitions.transition/3 (Plan 02-06). RunDirector's :workflow_changed escalation path produces audit-paired, PubSub-broadcast transitions, so the dashboard's 'workflow changed mid-run' affordance has a signal to surface."

# Tech tracking
tech-stack:
  added:
    - "None — DynamicSupervisor, Supervisor, GenServer, Process.monitor, Registry all ship with OTP."
  patterns:
    - "Per-run isolation via `:one_for_one` parent (RunSupervisor) + `:one_for_all` child (RunSubtree). RunSupervisor's strategy contains a subtree crash to the one run; RunSubtree's strategy forces the whole per-run tree to restart together when any agent crashes (consistent with CLAUDE.md 'if an agent crashes, the run recovers or escalates')."
    - "Phase-2 lived-child scaffold for ORCH-02 testability. Shipping a minimal Task.Supervisor child inside RunSubtree gives the integration test a real pid to kill without pulling forward Phase-3 agent code. The lived_child_pid/1 helper exposes the killable pid via Registry lookup. Phase 3 swaps the child list in init/1; the test + helper contract remain."
    - "Staged supervisor boot preserved, extended from 7 -> 10 children. Phase 1 locked the pattern (infra -> BootChecks.run!/0 -> Endpoint). Phase 2 adds 3 new infra children (RunSupervisor + RunDirector + StuckDetector) BEFORE BootChecks so the boot check chain runs against a tree that already has them. KilnWeb.Endpoint remains the dynamic 10th child — a failing BootChecks still leaves a 9-child tree without an Endpoint bound (the 'dead factory' signal per D-32)."
    - "Async boot-scan via `send(self(), :boot_scan)` in init/1 (D-92). Supervisor boot NEVER blocks on a DB query; the scan runs from handle_info/2 after the supervisor tree is fully up + endpoint has bound. Periodic scans (Process.send_after/3 every 30s) are belt-and-suspenders against a node-restart race that could deliver a subtree collapse before a fresh RunDirector completes its boot scan."
    - "Idempotent scan via MapSet filter on already-monitored run_ids. do_scan/1 builds a MapSet from state.monitors values (each value is {ref, run_id}), then Enum.reduce/3 over Runs.list_active/0 only spawning + monitoring runs NOT in the set. A burst of :periodic_scan messages (or :boot_scan followed by :periodic_scan) does NOT double-spawn subtrees."
    - "Workflow-checksum integrity assertion on rehydration (D-94). Before spawning a per-run subtree, assert_workflow_unchanged/1 compares the current on-disk sha256 against runs.workflow_checksum. Missing file OR checksum mismatch -> {:error, :workflow_changed} -> Kiln.Runs.Transitions.transition/3 with reason :workflow_changed (audit-paired, PubSub-broadcast). Operator sees a typed signal rather than silent subtree spawn against a mutated graph."
    - "Deferred-activation CI gate pattern fully realised. Plan 02-04 shipped the `mix check_bounded_contexts` source + wired it into `.check.exs` with a comment noting deferred activation; Plan 02-07 extended Kiln.BootChecks.@context_modules from 12 to 13 in lockstep with the Mix task's @expected SSOT. The gate is now ACTIVE and enforces '13 bounded contexts, no drift' on every CI build. This is the canonical pattern for Wave-1 scaffolding CI gates whose paired SSOT lands in a later wave."

key-files:
  created:
    - "lib/kiln/runs/run_supervisor.ex (37 lines) — DynamicSupervisor :one_for_one max_children: 10"
    - "lib/kiln/runs/run_subtree.ex (111 lines) — per-run Supervisor :one_for_all :transient + Task.Supervisor lived-child + lived_child_pid/1 helper"
    - "lib/kiln/runs/run_director.ex (172 lines) — :permanent singleton GenServer with boot-scan + periodic-scan + DOWN-handler + D-94 workflow-checksum assertion"
    - "test/kiln/runs/run_director_test.exs (112 lines, 3 tests) — :boot_scan discovery + D-94 escalation + periodic-scan idempotency"
    - "test/integration/run_subtree_crash_test.exs (166 lines, 2 tests) — ORCH-02 single-crash absorption + budget-trip escalation"
  modified:
    - "lib/kiln/application.ex — infra_children extended 6 -> 9; D-42 comment block updated to cite D-92..D-96 alongside; 10-child post-boot invariant documented"
    - "lib/kiln/boot_checks.ex — @context_modules 12 -> 13 (adds Kiln.Artifacts); @type context_module union updated; new check_workflow_schema_loads!/0 helper wired into run!/0 chain"
    - "test/kiln/application_test.exs — 7-child assertion -> 10-child assertion; explicit assertions for Kiln.Runs.RunSupervisor/RunDirector + Kiln.Policies.StuckDetector presence + liveness; forbidden-children list pruned of the 3 now-legitimate modules"
    - "test/kiln/boot_checks_test.exs — context_count/0 assertion 12 -> 13; Kiln.Artifacts SSOT presence assertion; :workflow_schema_loads happy-path test; :oban_queue_budget preservation test"
    - "test/kiln_web/health_plug_test.exs — [Rule 1 auto-fix] contexts-count assertions 12 -> 13 (two call sites) to match Kiln.HealthPlug.status/0's updated return; D-97 spec-upgrade also governs the /health probe payload"
    - ".check.exs — mix check_bounded_contexts comment updated to reflect ACTIVATED status (the two SSOTs are now in sync)"

key-decisions:
  - "Kiln.Runs.RunSubtree ships with a Task.Supervisor lived-child in Phase 2 even though Phase 3 will replace it. Rationale: the ORCH-02 integration test (checker issue #1 mandatory) needs a real pid under the subtree to kill; shipping RunSubtree as a truly-empty Supervisor would leave the test with nothing killable, forcing either (a) deferring the test to Phase 3 (regression of the checker fix), or (b) injecting mock children at test time (complicates the test + divorces test behavior from production shape). Minimal lived-child = honest production behavior + testable today. Phase 3's swap is a one-line change inside init/1's children list."
  - "lived_child_pid/1 exposes the lived-child pid via Registry lookup rather than a `Supervisor.which_children/1` scan. Rationale: Registry.lookup/2 is O(1) and returns {pid, metadata}; Supervisor.which_children/1 is O(N) and returns [{id, pid, type, modules}]. For a subtree with a single lived-child the difference is trivial; for Phase 3's subtree with multiple agent + sandbox children, a name-keyed lookup stays direct while a `which_children` scan would need to filter by id-tuple."
  - "RunDirector runs as a live singleton across the full MIX_ENV=test run (started by Kiln.Application). Unit tests interact with the live singleton rather than spawning per-test instances. Rationale: RunDirector is a :permanent :one_for_one child; spawning per-test instances would leak processes across tests (the supervisor wouldn't own them, so on_exit cleanup becomes manual). Per-test RunSupervisor cleanup via DynamicSupervisor.terminate_child/2 in setup/1 gives deterministic child counts without touching the director itself."
  - "RunSupervisor cleanup is explicitly required in every test setup that interacts with the live singleton. RunDirector is singleton; its monitor table persists across tests. If a prior test spawned a subtree that the current test doesn't clean up, the current test's :boot_scan sees 'already-monitored' and skips spawning — corrupting every subsequent assertion that relies on child-count post-boot-scan. The setup/1 cleanup loop (DynamicSupervisor.terminate_child across all which_children) reverts to a known empty state."
  - "The D-94 workflow-checksum assertion treats a MISSING workflow file identically to a checksum mismatch — both return {:error, :workflow_changed}. Rationale: a missing file means the on-disk graph is effectively `nil`, which is semantically 'a graph different from the frozen checksum' regardless of whether the file was ever there. Operator sees a typed :workflow_changed escalation either way; the Logger.error/2 line discriminates missing-file from checksum-mismatch for diagnostics without adding a second typed reason."
  - "handle_info/2 catch-all clause added (`def handle_info(_msg, state), do: {:noreply, state}`). Rationale: RunDirector is :permanent; an unexpected message from a stray monitor, a test helper, or an unrelated Process.send/2 in production would otherwise crash the director and trigger a supervisor restart loop. The catch-all is minimal and doesn't hide bugs — unexpected messages are silently dropped (same outcome as a process with no catch-all that's since restarted), but the director itself stays alive and the boot scan eventually reconciles state from Postgres."
  - "test/kiln_web/health_plug_test.exs updated with [Rule 1 auto-fix] 12 -> 13. The D-97 spec upgrade in this plan extends the context count visible via Kiln.HealthPlug.status/0; the health-probe test's hard-coded '12' would have failed the moment BootChecks.@context_modules changed. Auto-fixing this is critical: /health is the operator's liveness signal; a failing test on a correct production code path means the contract isn't safely checked."

patterns-established:
  - "Per-run subtree lifecycle: RunDirector spawns via DynamicSupervisor.start_child/2 + Process.monitor/1 the returned pid. The monitor ref is stored in state.monitors keyed by pid (value is {ref, run_id}). Teardown is `{:DOWN, ref, :process, pid, reason}` -> Map.pop the pid out of state.monitors + Logger.warning. The next periodic scan re-hydrates the run if it's still active in DB. This pattern generalises: any long-lived resource hung off a DynamicSupervisor with a boot-scan rehydration contract follows the same monitor-table + DOWN-handler shape."
  - "Boot-scan idempotency via MapSet on monitor-table values. Building `MapSet.new(Map.values(monitors), fn {_ref, id} -> id end)` and filtering Runs.list_active/0 by non-membership makes repeated scans free. Generalisable to any periodic-reconciliation pattern where the local state is a subset of an external source of truth."
  - "Deferred-activation CI gate: Wave N ships source + .check.exs wiring; Wave N+K ships the paired SSOT update. Gate is wired but passes trivially (all Wave N+K-dependent assertions are satisfied by runtime check, not compile-time reference). Wave N+K lands the last piece + the gate starts enforcing end-to-end. Plan 02-04 + 02-07 are the canonical example; generalises to any future Wave 1 scaffolding whose invariant validation needs a Wave-M-only module."
  - "Integration-test crash-isolation pattern: seed two runs, trigger :boot_scan, kill a lived-child pid under one subtree, assert (a) director survives (pid unchanged), (b) peer subtree is untouched (lived-child pid unchanged on the unaffected run), (c) affected run recovers OR escalates OR awaits rehydration. Applicable to any per-resource supervisor tree where the parent strategy is :one_for_one + children are long-lived workers."

requirements-completed: [ORCH-02, ORCH-04]

# Metrics
duration: ~9min
completed: 2026-04-20
---

# Phase 02 Plan 07: RunDirector + RunSupervisor + RunSubtree + 10-Child Supervision Tree Summary

**Three new OTP primitives ship — RunSupervisor (DynamicSupervisor, max_children: 10), RunSubtree (per-run :one_for_all :transient supervisor with a Task.Supervisor lived-child for ORCH-02 testability), and RunDirector (:permanent singleton with async boot-scan + 30s periodic-scan + DOWN-handler + D-94 workflow-checksum assertion) — extending Kiln.Application from 7 to 10 children; BootChecks extends to 13 contexts (admits Kiln.Artifacts per D-97) and gains the 5th invariant `check_workflow_schema_loads!/0`; the ORCH-02 crash-isolation integration test (checker issue #1) + the `mix check_bounded_contexts` CI gate (checker issue #5 option (b) paired SSOT activation) both ship end-to-end.**

## Performance

- **Duration:** ~9 min (558 s)
- **Started:** 2026-04-20T02:32:23Z
- **Completed:** 2026-04-20T02:41:41Z
- **Tasks:** 3 / 3 complete
- **Files created:** 5 (3 source + 2 test)
- **Files modified:** 6 (lib/kiln/application.ex, lib/kiln/boot_checks.ex, test/kiln/application_test.exs, test/kiln/boot_checks_test.exs, test/kiln_web/health_plug_test.exs, .check.exs)
- **New tests:** 12 (3 RunDirector unit + 6 Application + 3 BootChecks + 2 ORCH-02 integration, offset partially by replaced assertions in existing tests)
- **Full suite (excluding pending, including integration):** 247 tests, 0 failures (up from 236 at end of Wave 2)

## Accomplishments

- **Kiln.Runs.RunSupervisor + RunSubtree + RunDirector ship in a single atomic Task 1 commit.** Three OTP primitives with tight contracts: DynamicSupervisor :one_for_one host (D-95), per-run Supervisor :one_for_all :transient worker (CLAUDE.md agent-isolation convention), and :permanent singleton GenServer with staged async boot (D-92). The D-94 workflow-checksum assertion lives inside RunDirector's spawn_subtree/1 private helper — missing workflow file OR checksum drift both escalate the run via Kiln.Runs.Transitions.transition/3 with reason :workflow_changed.
- **Kiln.Application moved from 7 children to 10, preserving the staged boot shape.** `infra_children` grows from 6 -> 9 entries; KilnWeb.Endpoint remains the dynamic 10th child added via Supervisor.start_child/2 AFTER Kiln.BootChecks.run!/0 — so a failing boot check still halts the BEAM BEFORE the endpoint binds a port (dead-factory signal per D-32). The 3 new children (RunSupervisor, RunDirector, StuckDetector) slot in between Oban and the boot-check call.
- **Kiln.BootChecks extends to 13 contexts + 6 invariants (5 from Plan 02-04 + this plan's `:workflow_schema_loads`).** @context_modules now lists Kiln.Artifacts as the 13th entry (D-97 spec upgrade; Plan 02-03 shipped the module, Plan 02-07 paired the SSOT). The new 5th invariant check_workflow_schema_loads!/0 asserts Kiln.Workflows.SchemaRegistry.fetch(:workflow) returns `{:ok, _}` at boot — a corrupted workflow JSON schema now fails loud with a diagnostic message instead of at first workflow load. Plan 02-04's :oban_queue_budget invariant is preserved verbatim; a dedicated test asserts run!/0 still exercises it so a future refactor can't accidentally drop or reorder it.
- **ORCH-02 crash isolation has an active end-to-end test (checker issue #1 resolved).** `test/integration/run_subtree_crash_test.exs` kills a real Task.Supervisor lived-child under a real RunSubtree and asserts (a) the director's pid is unchanged, (b) the peer subtree's lived-child pid is unchanged, (c) the affected run recovers OR escalates OR awaits rehydration. A second test hammers the subtree with 4 rapid kills to exhaust the max_restarts: 3 / max_seconds: 5 budget — the subtree terminates but the director STAYS ALIVE. The previous `@tag :skip` stub is gone.
- **`mix check_bounded_contexts` CI gate is ACTIVE end-to-end (checker issue #5 option (b) resolved).** Plan 02-04 shipped the Mix task source + .check.exs wiring with a deferred-activation comment. Plan 02-07 ships the paired BootChecks @context_modules extension from 12 to 13 — the two SSOTs are now in sync, and every CI build enforces "13 bounded contexts, no drift" on top of the existing per-context compile checks.
- **Threat T6 mitigation proven in production tests (checker issue #7 resolved).** Both test files that drive RunDirector (run_director_test.exs + run_subtree_crash_test.exs) use `Kiln.RehydrationCase.reset_run_director_for_test/0` in `setup` — the helper forces the live singleton's Repo connection into the test's Ecto sandbox BEFORE sending a fresh :boot_scan, eliminating the pre-sandbox-allow race. The helper was shipped in Plan 02-00 and exercised end-to-end here for the first time.

## Task Commits

Each task was committed atomically:

1. **Task 1: RunSupervisor + RunSubtree + RunDirector + run_director_test.exs** — `981fa2c` (feat)
2. **Task 2: Application 7 -> 10 + BootChecks 13 contexts + check_workflow_schema_loads! + activate bounded-contexts CI gate** — `bd1a211` (feat)
3. **Task 3: ORCH-02 crash-isolation integration test (test/integration/run_subtree_crash_test.exs)** — `05bbc16` (test)

## Files Created / Modified

### Created (5)

**Elixir source (3):**
- `lib/kiln/runs/run_supervisor.ex` — 37 lines. DynamicSupervisor, :one_for_one, max_children: 10 (D-95).
- `lib/kiln/runs/run_subtree.ex` — 111 lines. Per-run Supervisor, :one_for_all, :transient, Registry-named via Kiln.RunRegistry; Task.Supervisor lived-child for ORCH-02 testability; lived_child_pid/1 helper.
- `lib/kiln/runs/run_director.ex` — 172 lines. :permanent singleton GenServer. init/1 -> send(self(), :boot_scan). handle_info(:boot_scan | :periodic_scan) -> do_scan/1 + Process.send_after/3. handle_info({:DOWN, ...}) -> Map.pop monitor table + Logger.warning. assert_workflow_unchanged/1 -> File.exists? + Kiln.Workflows.load/1 + checksum compare -> {:error, :workflow_changed} on drift -> transition/3 to :escalated.

**Tests (2):**
- `test/kiln/runs/run_director_test.exs` — 112 lines, 3 tests. :boot_scan discovery; D-94 mismatched-workflow-file escalation; periodic-scan idempotency.
- `test/integration/run_subtree_crash_test.exs` — 166 lines, 2 tests. ORCH-02 single-crash absorption + budget-trip escalation.

### Modified (6)

- `lib/kiln/application.ex` — infra_children grew from 6 -> 9 entries; D-42 comment block updated to reference D-92..D-96; 10-child post-boot invariant documented.
- `lib/kiln/boot_checks.ex` — @context_modules 12 -> 13 (appends Kiln.Artifacts); @type context_module union updated in lockstep; context_count/0 returns 13; new check_workflow_schema_loads!/0 private helper + wire into run!/0 chain AFTER check_oban_queue_budget!/0 and BEFORE check_required_secrets!/0.
- `test/kiln/application_test.exs` — 7-child assertion -> 10-child assertion; explicit per-child-id assertions for the 10 post-boot children; positive liveness checks for the 3 new children; forbidden-children list pruned of the 3 now-legitimate modules.
- `test/kiln/boot_checks_test.exs` — context_count/0 assertion 12 -> 13; new Kiln.Artifacts SSOT-membership assertion; new :workflow_schema_loads happy-path describe; new :oban_queue_budget preservation describe.
- `test/kiln_web/health_plug_test.exs` — [Rule 1 auto-fix] two 12 -> 13 assertion updates to match Kiln.HealthPlug.status/0's now-13 contexts count (D-97 spec upgrade drifted the health-probe test without this fix).
- `.check.exs` — `mix check_bounded_contexts` wire comment updated to reflect ACTIVATED status (the two SSOTs are in sync post-Plan 02-07).

## Supervision Tree Diff (7 -> 10 children)

```
Phase 1 (7 children, D-42):          Phase 2 Plan 07 (10 children, D-92..D-96):
  KilnWeb.Telemetry                    KilnWeb.Telemetry
  Kiln.Repo                            Kiln.Repo
  Phoenix.PubSub                       Phoenix.PubSub
  Finch (Kiln.Finch)                   Finch (Kiln.Finch)
  Registry (Kiln.RunRegistry)          Registry (Kiln.RunRegistry)
  Oban                                 Oban
  KilnWeb.Endpoint                     Kiln.Runs.RunSupervisor          <-- NEW (7th; DynamicSupervisor, max_children: 10)
                                       {Kiln.Runs.RunDirector, []}      <-- NEW (8th; :permanent GenServer, boot-scan deferred)
                                       Kiln.Policies.StuckDetector      <-- NEW (9th; :permanent GenServer, no-op check/1)
                                       KilnWeb.Endpoint                  (10th; dynamic via Supervisor.start_child/2)
```

Staged-boot pattern preserved: infra_children (9) -> `Kiln.BootChecks.run!/0` -> `Kiln.Telemetry.ObanHandler.attach/0` -> `Supervisor.start_child(_, KilnWeb.Endpoint.child_spec([]))`. A failing boot-check leaves a 9-child tree with no Endpoint bound — the "dead factory" signal.

## BootChecks Invariant Chain (5 -> 6; `@context_modules` 12 -> 13)

```
Plan 04 (5 invariants):               Plan 07 (6 invariants):
  check_contexts_compiled! (12)         check_contexts_compiled! (13)       <-- SSOT extended
  check_audit_revoke_active!            check_audit_revoke_active!
  check_audit_trigger_active!           check_audit_trigger_active!
  check_oban_queue_budget! (<= 16)      check_oban_queue_budget! (<= 16)    (preserved verbatim)
                                        check_workflow_schema_loads!         <-- NEW (Plan 07)
  check_required_secrets!               check_required_secrets!
```

@context_modules ADDITION (alphabetical-append since Plan 02-03 shipped the context):

```diff
 @context_modules [
   Kiln.Specs,
   Kiln.Intents,
   Kiln.Workflows,
   Kiln.Runs,
   Kiln.Stages,
   Kiln.Agents,
   Kiln.Sandboxes,
   Kiln.GitHub,
   Kiln.Audit,
   Kiln.Telemetry,
   Kiln.Policies,
-  Kiln.ExternalOperations
+  Kiln.ExternalOperations,
+  Kiln.Artifacts
 ]
```

## RunDirector State Struct Shape

```elixir
%{
  monitors: %{
    pid() => {monitor_ref :: reference(), run_id :: Ecto.UUID.t()}
  }
}
```

Single-key state kept minimal on purpose — the monitor table IS the rehydration ledger. `state.monitors` is populated by successful `DynamicSupervisor.start_child/2` returns (wrapped in `Process.monitor/1`) and depopulated by `{:DOWN, ref, :process, pid, reason}` messages. Idempotency is enforced by building a `MapSet` from `Map.values/1` and filtering `Kiln.Runs.list_active/0` by non-membership before spawning.

## RunSubtree Phase-2 Lived-Child and Phase-3 Migration

**Phase 2 (this plan):**

```elixir
def init(opts) do
  run_id = Keyword.fetch!(opts, :run_id)
  children = [
    {Task.Supervisor,
     name: {:via, Registry, {Kiln.RunRegistry, {__MODULE__.Tasks, run_id}}}}
  ]
  Supervisor.init(children, strategy: :one_for_all, max_restarts: 3, max_seconds: 5)
end
```

The Task.Supervisor exists solely to give the integration test a killable pid. It's a legitimate lived child (not a stub — a real OTP Task.Supervisor is being supervised; its behavior is "await dynamic task spawn requests"). Phase 3's swap is line-level:

**Phase 3 (future):**

```elixir
def init(opts) do
  run_id = Keyword.fetch!(opts, :run_id)
  children = [
    {Kiln.Agents.SessionSupervisor, run_id: run_id},
    {Kiln.Sandboxes.Supervisor, run_id: run_id}
  ]
  Supervisor.init(children, strategy: :one_for_all, max_restarts: 3, max_seconds: 5)
end
```

Contract preserved across the swap:
- Supervisor strategy (`:one_for_all`) — UNCHANGED.
- Supervisor name (`{:via, Registry, {Kiln.RunRegistry, {__MODULE__, run_id}}}`) — UNCHANGED.
- Restart type (`:transient`) — UNCHANGED.
- Restart budget (3 restarts / 5 seconds) — UNCHANGED.
- `lived_child_pid/1` helper — UNCHANGED (if Phase 3 keeps the helper shape; or replaced by a `children/1` query returning all per-run pids).
- `test/integration/run_subtree_crash_test.exs` — UNCHANGED (kills the first pid returned by `lived_child_pid/1`; Phase 3's Kiln.Agents.SessionSupervisor replaces the killed process).

## ORCH-02 Signature-Test Location Note

The ORCH-02 end-to-end crash-isolation test lives at:

**`test/integration/run_subtree_crash_test.exs`**

- `@moduletag :integration` + `@moduletag :run_subtree_crash` for selective CI invocation
- Two tests: single-crash absorption + budget-trip escalation
- No `@tag :skip` on any test
- Uses `Kiln.RehydrationCase` for the threat-T6 sandbox-race mitigation
- Director-survival assertion (`Process.whereis(RunDirector) != nil`) is the ORCH-02 contract

## Decisions Made

See the `key-decisions` frontmatter entries for the 7 decisions. Highlights:

- **Phase 2 RunSubtree ships with a Task.Supervisor lived-child** — the ORCH-02 integration test (checker issue #1) requires a real killable pid; deferring to Phase 3 would regress the checker fix, and injecting mock children at test time would divorce test behavior from production shape.
- **lived_child_pid/1 exposes via Registry lookup (O(1))** rather than `Supervisor.which_children/1` scan (O(N)) — stays direct for Phase 3's multi-child subtree.
- **RunDirector runs as a live singleton across the test run** — spawning per-test instances would leak unsupervised processes; per-test RunSupervisor cleanup via `DynamicSupervisor.terminate_child/2` loop gives deterministic state.
- **Missing workflow file treated as :workflow_changed** — semantically "different graph from frozen checksum"; one typed reason covers both branches.
- **handle_info/2 catch-all clause added** — RunDirector is :permanent; a stray message must not crash it into a restart loop.
- **test/kiln_web/health_plug_test.exs auto-updated 12 -> 13** — D-97 spec upgrade drifted the health probe payload; Rule 1 auto-fix essential for operator liveness signal correctness.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — test assertion drift] test/kiln_web/health_plug_test.exs asserted contexts == 12, but D-97 spec-upgrade landing in this plan drifts it to 13**

- **Found during:** Task 2 verification (`MIX_ENV=test mix test --exclude pending` surfaced 2 failures at `test/kiln_web/health_plug_test.exs:30` and `:64`)
- **Issue:** The D-97 spec upgrade extends the 12-context invariant to 13 at the BootChecks SSOT layer, and `Kiln.HealthPlug.status/0` reads from `Kiln.BootChecks.context_count/0`. Without updating the `/health` probe test assertions, the full suite would fail even though production code is correct. This is the kind of drift D-97 explicitly calls out in its hand-off note to this plan.
- **Fix:** Updated two `assert body["contexts"] == 12` and `assert payload["contexts"] == 13` -> both now assert `== 13`; the first diagnostic message updated from "D-42 locks the 12-context count" to "D-97 (Plan 02-07 spec upgrade) locks the 13-context count".
- **Files modified:** `test/kiln_web/health_plug_test.exs`
- **Verification:** `MIX_ENV=test mix test test/kiln_web/health_plug_test.exs` exits 0; full suite (247 / 0 failures) confirms no cross-test regression.
- **Committed in:** `bd1a211` (Task 2 commit — the spec upgrade + paired test update land in the same atomic change)

### Plan Spec Adjustments (not bugs — hardening)

**2. [Rule 3 — defensive code] `handle_info/2` catch-all clause added to RunDirector**

- **Found during:** Task 1 authoring (stack-trace-reliability review before commit)
- **Issue:** The plan's `<interfaces>` RunDirector pattern defines three `handle_info/2` clauses (`:boot_scan`, `:periodic_scan`, `{:DOWN, ...}`). An unexpected message — e.g., a test helper's stray `send/2`, a monitor ref from a process that the director didn't create, or any future integration's accidental message — would NOT pattern-match and would crash the director with `FunctionClauseError`. Under `:permanent` supervision, the supervisor would restart the director — but the restart re-runs `init/1` which re-sends `:boot_scan` and re-scans Postgres. Repeated unexpected messages -> repeated crash-restart loop -> supervisor budget trip -> whole BEAM exits. Defensive catch-all = minimum Rule-3 hardening to keep the director alive under unexpected input.
- **Fix:** Added `def handle_info(_msg, state), do: {:noreply, state}` at the end of the handle_info group. Docstring-comment notes the rationale (don't crash on strays; unexpected messages are silently dropped; boot-scan eventually reconciles).
- **Files modified:** `lib/kiln/runs/run_director.ex`
- **Verification:** All 3 RunDirector tests pass; `mix compile --warnings-as-errors` clean (the catch-all clause uses `_msg` so the unused-variable warning isn't triggered).
- **Committed in:** `981fa2c` (Task 1 commit)

**Total deviations:** 2 auto-fixes — 1 Rule 1 (test-assertion drift) + 1 Rule 3 (defensive `handle_info` catch-all). No scope creep; both within-file, one-line changes.

## Authentication Gates

None required — this plan only ships OTP + config + test changes. No external services.

## Verification Evidence

- `mix compile --warnings-as-errors` (dev) — 0 warnings, clean.
- `MIX_ENV=test mix compile --warnings-as-errors` — 0 warnings, clean.
- `mix check_bounded_contexts` — OK — 13 contexts compiled.
- `MIX_ENV=test mix test test/kiln/application_test.exs test/kiln/boot_checks_test.exs` — 23 tests, 0 failures.
- `MIX_ENV=test mix test test/kiln/runs/run_director_test.exs` — 3 tests, 0 failures.
- `MIX_ENV=test mix test test/integration/run_subtree_crash_test.exs --include integration` — 2 tests, 0 failures.
- `MIX_ENV=test mix test --exclude pending --include integration` — 247 tests, 0 failures (up from 236 at end of Wave 2; +3 RunDirector +6 Application +3 BootChecks +2 integration, partially offset by replaced assertions).
- Smoke: `mix run --no-start -e 'IO.inspect(Kiln.BootChecks.context_count())'` -> 13.
- All 12 Task 1 acceptance greps pass.
- All 9 Task 2 acceptance greps pass.
- All 5 Task 3 acceptance greps pass.

## Checker-Issue Resolutions

| Issue | Description | Resolution |
|-------|-------------|-----------|
| #1    | ORCH-02 only covered by `@tag :skip` stub | `test/integration/run_subtree_crash_test.exs` ships with 2 active end-to-end tests; no `@tag :skip` anywhere |
| #5 (b)| `mix check_bounded_contexts` deferred activation | Paired SSOT update landed (BootChecks @context_modules 12 -> 13); gate now enforces 13-context invariant on every CI build |
| #7    | Threat T6 (RunDirector boot-scan DB-race) | Both run_director_test.exs + run_subtree_crash_test.exs use `use Kiln.RehydrationCase` + `reset_run_director_for_test/0` in setup |

## Next Plan Readiness

- **Plan 02-08 (StageWorker + integration tests + doc spec upgrades)** — the supervision tree is now 10 children and RunDirector is a live :permanent singleton. StageWorker's Oban job can assume (a) the run exists in DB, (b) a live per-run subtree supervises the run, (c) killing the StageWorker's executing pid triggers the :one_for_all restart -> either recovery or escalation via D-94-or-bounded-autonomy paths. The ORCH-02 + ORCH-04 contracts are both proven in tests.
- **Phase 3 (BLOCK-01 + agent adapters)** — RunSubtree's Task.Supervisor lived-child is ready to be swapped for `Kiln.Agents.SessionSupervisor` + `Kiln.Sandboxes.Supervisor`. Contract-stable: strategy, restart type, budget, and name all preserved.
- **Phase 5 (StuckDetector full body)** — StuckDetector is now in the supervision tree as a :permanent child. Phase 5 replaces ONLY the `handle_call/3` body; no supervisor reshuffle, no caller refactor, no schema migration.
- **Phase 7 (LiveView)** — Kiln.HealthPlug now reports `contexts: 13`; LiveView subscriptions to `run:<id>` + `runs:board` PubSub topics work the same whether the transition came from Kiln.Runs.Transitions.transition/3 directly OR from RunDirector's D-94 escalation path.

## Known Stubs

None new in this plan — the Task.Supervisor lived-child inside RunSubtree is NOT a stub; it's a real OTP Task.Supervisor with real supervision behavior. Its replacement in Phase 3 (with Kiln.Agents.SessionSupervisor + Kiln.Sandboxes.Supervisor) is a planned shape migration, not a "fix the stub" obligation.

## TDD Gate Compliance

N/A — this plan is `type: execute`, not `type: tdd`. Three tasks committed as `feat` + `feat` + `test`:

1. `981fa2c` (feat) — sources + unit test
2. `bd1a211` (feat) — config + BootChecks wiring + test assertion updates
3. `05bbc16` (test) — ORCH-02 integration test

The final `test` commit is a test-only addition, which aligns with conventional-commit `test:` prefix semantics.

## Threat Flags

None new. The plan's `<threat_model>` listed 6 threats (T1-T6):

- **T1 (RunDirector crash loops)** — mitigated by the catch-all `handle_info/2` clause (Rule 3 auto-fix above) + per-run `{:error, reason} -> Logger.error` in `do_scan/1` (no single bad run crashes the director).
- **T2 (max_children: 10 blocks starts)** — documented in RunSupervisor @moduledoc; periodic scan re-attempts as slots free.
- **T3 (workflow checksum TOCTOU)** — acknowledged in plan; sub-second window; acceptable for v1.
- **T4 (boot-time JSV schema compile failure halts BEAM)** — intentional per D-32; `KILN_SKIP_BOOTCHECKS=1` is the P1 escape hatch.
- **T5 (RunDirector :permanent restart loop on DB failure)** — bounded by Kiln.Supervisor's `:one_for_one` default `max_restarts: 3 in 5_seconds`; after budget trip the BEAM exits with a diagnostic, consistent with Kiln's fail-loud ethos.
- **T6 (RunDirector boot-scan sandbox race)** — mitigated end-to-end by `Kiln.RehydrationCase.reset_run_director_for_test/0`; both test files in this plan use it.

## Self-Check: PASSED

- All 5 created files exist on disk:
  - `lib/kiln/runs/run_supervisor.ex` — FOUND
  - `lib/kiln/runs/run_subtree.ex` — FOUND
  - `lib/kiln/runs/run_director.ex` — FOUND
  - `test/kiln/runs/run_director_test.exs` — FOUND
  - `test/integration/run_subtree_crash_test.exs` — FOUND
- All 3 task commits present in `git log --all --oneline`:
  - `981fa2c` (feat(02-07): RunSupervisor + RunSubtree + RunDirector modules) — FOUND
  - `bd1a211` (feat(02-07): Application 7→10 + BootChecks 13 contexts + workflow_schema_loads + activate bounded-contexts CI gate) — FOUND
  - `05bbc16` (test(02-07): ORCH-02 crash-isolation integration test) — FOUND
- Full `MIX_ENV=test mix test --exclude pending --include integration` suite: 247 tests, 0 failures.
- `mix compile --warnings-as-errors` + `MIX_ENV=test mix compile --warnings-as-errors` both clean.
- `mix check_bounded_contexts` exits 0 with "OK — 13 contexts compiled".
- No unexpected file deletions (git diff --diff-filter=D --name-only across the 3 commits returned nothing).
- No accidental modifications to `prompts/software dark factory prompt.txt` (pre-existing uncommitted file left alone).

---

*Phase: 02-workflow-engine-core*
*Completed: 2026-04-20*
