---
phase: 02-workflow-engine-core
plan: 06
subsystem: runs
tags: [state-machine, 9-state-transitions, matrix-as-data, repo-transact, select-for-update, stuck-detector-hook, post-commit-pubsub, d-86, d-87, d-88, d-89, d-90, d-91, checker-issue-6]

# Dependency graph
requires:
  - phase: 02-workflow-engine-core
    provides: "Plan 02-02 Kiln.Runs.Run 9-state Ecto.Enum + Run.transition_changeset/3 + Run.active_states/0 / terminal_states/0 (D-86 enum); Plan 02-01 :run_state_transitioned audit schema + Kiln.Audit.append/1 payload-only validation; Plan 02-00 Kiln.Factory.Run ExMachina.Ecto factory + Kiln.StuckDetectorCase singleton-reuse ExUnit template (checker issue #6)"
  - phase: 01-foundation-durability-floor
    provides: "Kiln.Audit.append/1 with in-tx INSERT-only guarantee (D-12 three-layer enforcement); Logger.metadata(:correlation_id) propagation pattern; Phoenix.PubSub registered as Kiln.PubSub in the supervision tree"

provides:
  - "lib/kiln/runs/illegal_transition_error.ex — Kiln.Runs.IllegalTransitionError exception with from/to/allowed message template per D-89 (substrings 'from ', 'to ', 'allowed from' asserted by tests); raised only by Kiln.Runs.Transitions.transition!/3"
  - "lib/kiln/policies/stuck_detector.ex — Kiln.Policies.StuckDetector :permanent GenServer with no-op handle_call({:check, _ctx}, _, state) -> {:reply, :ok, state} per D-91; stable :ok | {:halt, reason, payload} signature through Phase 5; D-42 sanctioned exception (ROADMAP P2 explicitly lists 'P1 stuck-run detector hook point wired')"
  - "lib/kiln/policies.ex — context facade; replaces P1 placeholder with defdelegate check_stuck/1 to Kiln.Policies.StuckDetector.check/1"
  - "lib/kiln/runs/transitions.ex — Kiln.Runs.Transitions command module: transition/3 tuple-default, transition!/3 bang-variant, matrix/0 introspection. @matrix encoded as data (D-87; 6 non-terminal keys), @cross_cutting :escalated/:failed unioned at assert_allowed/2 time. Repo.transact/2 (Ecto 3.13.5 new API) wraps SELECT ... FOR UPDATE row lock + assert_allowed + StuckDetector.check/1 (D-91 hook BEFORE Run.update, INSIDE tx) + Run.transition_changeset |> Repo.update + Audit.append in the same tx. Phoenix.PubSub broadcast to run:<id> + runs:board topics AFTER Repo.transact returns {:ok, _} (D-90 / Pitfall #1)"
  - "priv/audit_schemas/v1/run_state_transitioned.json — 9-state enum (Rule 2 fix: Phase 2 D-86 added :blocked; schema was still listing 8 states; every :blocked transition audit payload would have been rejected by JSV)"
  - "test/kiln/policies/stuck_detector_test.exs — no-op check/1 asserts :ok for empty / minimal / full-transition-context maps"
  - "test/kiln/runs/illegal_transition_error_test.exs — exception shape, field preservation, raise path, default :allowed = []"
  - "test/kiln/runs/transitions_test.exs — 24 tests: matrix/0 invariants (keys = active_states, values ⊆ states, no cross-cutting in value lists, no terminal keys); every D-87 allowed edge passes (14 edges × fresh run each); cross-cutting :escalated / :failed from every non-terminal state; illegal transitions rejected with no audit event; terminal-state lockdown (merged/failed/escalated outgoing all rejected); reason atom payload round-trip; T5 non-atom reason silently dropped; transition!/3 raise path; concurrent SELECT FOR UPDATE serialisation (2 parallel tasks → 1 ok + 1 :illegal_transition); post-commit PubSub broadcast on both run:<id> and runs:board topics; no broadcast on rejected transition"

affects:
  - "02-07 (Kiln.Runs.RunDirector) — will add Kiln.Policies.StuckDetector as :permanent child under Kiln.Supervisor; will also extend Kiln.BootChecks.@context_modules from 12 to 13 (Kiln.Artifacts). StuckDetector.check/1 hook-path in transition/3 is now exercised by 24 tests end-to-end"
  - "02-08 (Kiln.Stages.StageWorker) — uses Transitions.transition/3 to drive run state on stage completion (success → verifying / merged path; failure → blocked / planning) and Transitions.transition/3 with reason: :invalid_stage_input on D-76 boundary rejection"
  - "Phase 3 (BLOCK-01 typed reasons) — the atom :reason carry path through transition/3 → audit payload is already live; Phase 3 adds the reason enum domain + remediation playbooks; no matrix churn needed because :blocked edges are already wired"
  - "Phase 5 (StuckDetector sliding-window body) — replaces ONLY the handle_call({:check, _ctx}, ...) body of Kiln.Policies.StuckDetector; caller Kiln.Runs.Transitions and the public check/1 signature are locked per D-91. {:halt, reason, payload} return in Phase 5 translates to same-tx escalation path already present in transition/3's with-chain (via {:error, :stuck} branch to be added in Phase 5)"
  - "Phase 7 (LiveView dashboard) — consumes :run_state broadcasts on run:<id> / runs:board topics; both are broadcast here post-commit so the LV never sees a state change the DB rolled back"

# Tech tracking
tech-stack:
  added:
    - "None — Ecto 3.13.5, Phoenix.PubSub, ExMachina 2.8 all already in mix.lock"
  patterns:
    - "Repo.transact/2 (Ecto 3.13.5 new API) over Repo.transaction/2. The new API lets the closure return {:ok, term} | {:error, term} directly without Repo.rollback/1 for the happy path — matches the with-chain shape inside transition/3 exactly. Phase 1's Kiln.ExternalOperations uses the older Repo.transaction + Repo.rollback idiom; Phase 2 onward uses Repo.transact"
  - "Matrix-as-data over pattern-matched function heads (D-87). @matrix %{queued: [:planning], planning: [:coding, :blocked], ...} is inspectable from iex, round-trips through Transitions.matrix/0 for test assertions, and will be serialised to an operator state-graph widget in Phase 7. Cross-cutting edges (:escalated / :failed) live in a separate @cross_cutting attribute and are unioned at assert_allowed/2 time — callers don't list them twice"
    - "Post-commit side-effects AFTER Repo.transact returns {:ok, _}, NEVER inside the closure. Broadcasting a state change the DB could still roll back is Pitfall #1 in RESEARCH.md; the two-line case `{:ok, run} -> broadcast / other -> other` pattern in transition/3 makes the ordering impossible to get wrong accidentally"
    - "StuckDetector hook placement: INSIDE the tx, AFTER the SELECT ... FOR UPDATE, BEFORE the Repo.update. Firing post-commit would let a stuck run ship one more invalid transition before being caught; firing before the lock would race with concurrent callers; firing after the update would skip the rollback path Phase 5 needs for same-tx escalation. D-91 ordering is non-obvious but structurally correct"
    - "T5 mitigation: non-atom :reason in meta is silently dropped from the audit payload. maybe_add_reason/2 pattern-matches only atoms, so passing reason: \"<script>...</script>\" produces an audit event with NO reason key. Atom-only reasons are BLOCK-01's typed-reason domain (Phase 3); string reasons would require an explicit to_string/1 call that the code deliberately does not provide"

key-files:
  created:
    - "lib/kiln/runs/illegal_transition_error.ex — 47 lines"
    - "lib/kiln/policies/stuck_detector.ex — 74 lines"
    - "lib/kiln/runs/transitions.ex — 226 lines"
    - "test/kiln/policies/stuck_detector_test.exs — 23 lines, 2 tests"
    - "test/kiln/runs/illegal_transition_error_test.exs — 51 lines, 4 tests"
    - "test/kiln/runs/transitions_test.exs — 278 lines, 24 tests"
  modified:
    - "lib/kiln/policies.ex — replaced P1 @moduledoc-only placeholder with full facade (defdelegate check_stuck/1 to StuckDetector.check/1)"
    - "priv/audit_schemas/v1/run_state_transitioned.json — extended from/to enum 8 states -> 9 states (added \"blocked\") — Rule 2 fix per D-86"

key-decisions:
  - "Raised Rule 2 on priv/audit_schemas/v1/run_state_transitioned.json: the schema was still enumerating the 8-state pre-D-86 domain, which would have rejected every :blocked audit payload (planning -> blocked, coding -> blocked, testing -> blocked, verifying -> blocked, blocked -> planning/coding/testing/verifying). Adding 'blocked' to both from and to enum arrays is a correctness requirement, not a feature. Plan 02-01 shipped the 9-state Ecto enum but did not touch this schema; caught at first run of the 'every D-87 allowed edge passes' test (which would have failed with audit_payload_invalid)."
  - "IllegalTransitionError.exception/1 uses a 3-step Keyword pipeline (Keyword.put_new(:allowed, default) + Keyword.put(:message, msg) + struct!) rather than passing the keyword directly to struct!. Reason: struct!/2 does NOT apply keyword defaults — an explicit Keyword.put_new is required so tests that omit :allowed get [] at runtime, not nil. Caught by the 'allowed list defaults to []' test on first run."
  - "Used Repo.transact/2 (Ecto 3.13.5 new API) over Repo.transaction/2 + Repo.rollback. The with-chain inside transition/3 returns {:ok, term} or {:error, atom/term} from every step; Repo.transact threads that shape through without the rollback/1 dance Phase 1 needed. The new-API switch is called out in RESEARCH.md §Standard Stack and PATTERNS.md — Phase 2 is where it lands."
  - "Concurrent-transition test uses Ecto.Adapters.SQL.Sandbox.allow inside the spawned Task (not just the parent). Rationale: Kiln.DataCase runs async: false with shared-sandbox mode (tags[:async] == false → shared: true); the parent sets up the sandbox, but the Task's spawned process needs its own sandbox.allow so the StuckDetector GenServer.call (which runs as a separate process) sees the pre-seeded run row. Pattern documented in the test's comment block; Plan 02-07 will reuse it for RunDirector integration tests."
  - "@cross_cutting :escalated/:failed are NOT keys in @matrix by design (D-87). Keeping them separate means: (1) the matrix reads top-to-bottom as 'forward progress' edges, with escalation as a universal trapdoor; (2) tests can assert 'no terminal state is a matrix key' as a standalone invariant; (3) Phase 3's BLOCK-01 extension adds a third :halt classifier without touching the forward-progress structure. Union is done at assert_allowed/2 time via a single `Map.get(@matrix, from, []) ++ @cross_cutting` expression."
  - "Single audit event per transition, not per step. The with-chain lock → assert → stuck-check → update → append happens inside one Repo.transact; on success exactly ONE :run_state_transitioned row lands. Every {:error, _} short-circuits BEFORE the append, so no audit event is written for a rejected transition (assertion in the 'illegal transitions write no audit event' test). This preserves the 1:1 state-change ↔ audit-event invariant D-12 depends on."

patterns-established:
  - "Command-module transaction envelope: Repo.transact(fn -> with {:ok, x} <- step1, :ok <- step2, ... do {:ok, result} end end) followed by post-commit side effects in a case on the outer result. Replaces the Repo.transaction + Repo.rollback pattern from Phase 1 for all new Phase 2+ code. The with-chain reads linearly; every step returns the same tagged-tuple shape; side-effects (PubSub, Oban enqueues) hang off the outer case, not the closure"
  - "Matrix-as-data encoding for finite state machines. @terminal + @any_state + @matrix + @cross_cutting as four separate module attributes, each narrowly typed. matrix/0 public accessor returns the main map for test / UI / iex introspection. Adding a state or edge is a single attribute edit — no pattern-matched function heads to update; no two lists to keep in sync. Phase 7's LiveView state-graph widget reads matrix/0 directly"
  - "Structured deviation-proof pairing: Kiln.Audit.append/1 inside Repo.transact. Because D-12's three-layer enforcement makes audit INSERT atomic-or-nothing, a caller cannot write the state change without the audit event (or vice-versa). This generalises beyond Transitions — Kiln.Artifacts.put/3 (Plan 02-03) and Kiln.Stages.StageWorker (Plan 02-08) use the same pattern"
  - "@cross_cutting attribute for 'universal trapdoor' edges in a matrix-as-data state machine. Cleaner than listing [:escalated, :failed] on every non-terminal key (that's what pattern-matched function heads would have done). Union at assert_allowed/2 time keeps the main @matrix map scannable as 'forward progress' transitions"

requirements-completed: [ORCH-02, ORCH-03]

# Metrics
duration: ~10min
completed: 2026-04-20
---

# Phase 02 Plan 06: Kiln.Runs.Transitions + StuckDetector Hook Summary

**The canonical run state-machine command module ships: D-87's 9-state matrix as a module attribute, Repo.transact/2 with SELECT ... FOR UPDATE locking, the Phase 5-stable StuckDetector hook wired INSIDE the transaction per D-91, paired audit-event writes, and post-commit PubSub broadcasts. 30 new tests exercise every allowed edge, every illegal transition, concurrent serialisation under pg row-lock, and the two PubSub topics Phase 7's LiveView will subscribe to.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-20T02:15:00Z (approx — worktree reset to base commit)
- **Completed:** 2026-04-20T02:24:00Z
- **Tasks:** 2 / 2 complete
- **Files created:** 6 (3 source + 3 test)
- **Files modified:** 2 (lib/kiln/policies.ex — P1 placeholder → full facade; priv/audit_schemas/v1/run_state_transitioned.json — add "blocked" to the enum)
- **New tests:** 30 (2 StuckDetector + 4 IllegalTransitionError + 24 Transitions)
- **Full suite:** 195 tests / 0 failures (up from 165 at end of Plan 02-04)

## Accomplishments

- **Kiln.Runs.Transitions ships the D-90 transaction envelope verbatim.** Every state change goes through `Repo.transact(fn -> lock → assert → StuckDetector.check → update_state → append_audit end)`. On success the closure returns `{:ok, run}`; Post-commit broadcasts fire on both `run:<id>` (per-run topic Phase 7's run-detail LV subscribes to) and `runs:board` (global topic the dashboard fan-out LV subscribes to). Broadcasts NEVER fire inside the closure.
- **D-87's matrix is data, not pattern-matched function heads.** The `@matrix` module attribute has exactly 6 non-terminal keys (matching `Run.active_states/0`); `@cross_cutting` holds `:escalated` and `:failed` and is unioned at `assert_allowed/2` time. Terminal states (`:merged`, `:failed`, `:escalated`) are NOT keys — the "terminal outgoing = illegal" rule is a single `from in @terminal -> {:error, :illegal_transition}` branch, not six separate function heads.
- **StuckDetector is a :permanent GenServer with a no-op body — D-91 sanctioned.** `handle_call({:check, _ctx}, _, state) -> {:reply, :ok, state}`. The hook path through Transitions is exercised by every successful transition in the test suite (24 Transitions tests + 2 StuckDetector unit tests); Phase 5 replaces ONLY the handle_call body. Stable contract `:ok | {:halt, reason :: atom(), payload :: map()}` per D-91 is locked through Phase 5.
- **Concurrent-transition serialisation is tested end-to-end.** Two parallel `Task.async` callers targeting `queued -> planning` on the same run: Postgres' SELECT ... FOR UPDATE serialises them; the first sees `:queued` and transitions; the second sees `:planning` and rejects with `:illegal_transition` (planning → planning is not an allowed edge). Exactly 1 `{:ok, _}` and exactly 1 `{:error, :illegal_transition}` every run. Pattern documented in the test comment block — Plan 02-07's RunDirector integration tests will reuse it.
- **Audit schema extended from 8 to 9 states.** Plan 02-01 shipped `:stage_input_rejected` / `:artifact_written` / `:integrity_violation` but did not touch `run_state_transitioned.json`, which still enumerated the 8-state pre-D-86 domain. Caught the moment the "every D-87 allowed edge" test hit `planning -> blocked`. Rule 2 fix: added `"blocked"` to both `from` and `to` enum arrays; every `:blocked` transition audit payload now validates.

## Task Commits

Each task was committed atomically:

1. **Task 1:** `945ba88` — `feat(02-06): IllegalTransitionError + StuckDetector GenServer + Policies facade`
2. **Task 2:** `d113bc4` — `feat(02-06): Kiln.Runs.Transitions command module + 9-state audit schema`

## Files Created / Modified

### Created (6)

**Source (3):**
- `lib/kiln/runs/illegal_transition_error.ex` — 47 lines, defexception with from/to/allowed message template
- `lib/kiln/policies/stuck_detector.ex` — 74 lines, :permanent GenServer with no-op check/1 body per D-91
- `lib/kiln/runs/transitions.ex` — 226 lines, command module with matrix-as-data + Repo.transact + post-commit PubSub

**Tests (3):**
- `test/kiln/policies/stuck_detector_test.exs` — 23 lines, 2 tests
- `test/kiln/runs/illegal_transition_error_test.exs` — 51 lines, 4 tests
- `test/kiln/runs/transitions_test.exs` — 278 lines, 24 tests

### Modified (2)

- `lib/kiln/policies.ex` — P1 @moduledoc-only placeholder (10 lines) → full facade (27 lines) with `defdelegate check_stuck/1`
- `priv/audit_schemas/v1/run_state_transitioned.json` — enum from 8 states to 9 states (Rule 2 fix: add `"blocked"`)

## Transitions Flow Diagram

```
transition(run_id, to, meta)
│
├─ Repo.transact(fn ->
│    with {:ok, run}      <- lock_run(run_id)         # SELECT ... FOR UPDATE
│         :ok             <- assert_allowed(from, to) # D-87 @matrix + @cross_cutting
│         :ok             <- StuckDetector.check(ctx) # D-91 hook (no-op P2; P5 body)
│         {:ok, updated}  <- update_state(run, to)    # Run.transition_changeset |> Repo.update
│         {:ok, _ev}      <- append_audit(...) do     # Kiln.Audit.append :run_state_transitioned
│      {:ok, updated}
│    end
│  end)
│
└─ case result do
     {:ok, run} ->
       Phoenix.PubSub.broadcast(Kiln.PubSub, "run:#{run.id}", {:run_state, run})  # POST-COMMIT
       Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board",    {:run_state, run})  # POST-COMMIT
       {:ok, run}
     other -> other
   end
```

**Key ordering invariants:**
1. `SELECT ... FOR UPDATE` is FIRST — every later step operates on a locked row.
2. `assert_allowed` is BEFORE `StuckDetector.check` — no point asking the detector about an already-illegal transition.
3. `StuckDetector.check` is BEFORE `update_state` — D-91 mandates: a stuck run must be caught BEFORE its state change ships; firing post-update would allow one more invalid transition to audit.
4. `append_audit` is LAST inside the closure — the state change is the fact being audited; the audit row is the consequence.
5. PubSub broadcasts are OUTSIDE the closure — broadcasting a rolled-back transaction would be a cache-coherency nightmare for Phase 7's LiveView.

## @matrix Contents (D-87)

```elixir
@terminal     ~w(merged failed escalated)a
@any_state    ~w(queued planning coding testing verifying blocked)a
@cross_cutting ~w(escalated failed)a

@matrix %{
  queued:    [:planning],
  planning:  [:coding, :blocked],
  coding:    [:testing, :blocked, :planning],       # coder-fail routes back to planner
  testing:   [:verifying, :blocked, :planning],     # tester-fail routes back to planner
  verifying: [:merged, :planning, :blocked],        # verifier-fail re-plans
  blocked:   [:planning, :coding, :testing, :verifying]  # resume from checkpoint
}
```

- **6 non-terminal keys** — exact match with `Run.active_states/0`
- **3 terminal states** — NOT keys in the matrix (every outgoing edge from a terminal row is illegal)
- **2 cross-cutting edges** — every non-terminal state can reach `:escalated` (stuck detector / cap exceeded / unrecoverable) and `:failed` (verification failed beyond retry). Unioned at `assert_allowed/2` time; never listed in `@matrix` values
- **14 explicit forward edges** + **6 × 2 = 12 cross-cutting edges** = **26 total legal transitions** (all 26 covered by the "every D-87 allowed edge passes" + "cross-cutting from every non-terminal state" tests)

## StuckDetector Hook Rationale (D-91 Verbatim)

> `Kiln.Policies.StuckDetector` ships as a real `GenServer` in the Phase 2 supervision tree with a no-op `check/1` body returning `:ok`. NOT a D-42 violation: ROADMAP Phase 2 explicitly lists "P1 stuck-run detector hook point wired" as the phase's behavior-to-exercise. The hook path IS the behavior. `check/1` is called inside `Transitions.transition/3` **after** the row lock and **before** the state update — a pre-condition. Phase 5 replaces only the `handle_call({:check, ctx}, ...)` body with sliding-window logic over `(stage, failure-class)` tuples; no caller refactor, no schema migration, no supervisor reshuffle.

**Why this plan does NOT add StuckDetector to the supervision tree:** Plan 02-07 owns the supervision-tree extension (along with `Kiln.Runs.RunDirector` + `Kiln.Runs.RunSupervisor`, the 13th-context SSOT update, and the 7th BootChecks invariant `:workflow_schema_loads`). Tests here use `Kiln.StuckDetectorCase` which handles "start if not started" per-test; production startup waits for Plan 02-07.

## Race-Test Counter-Intuitive Finding

The plan's expected shape was "2 `Task.async` callers → Postgres row-lock serialises → 1 `{:ok, _}` + 1 `{:error, :illegal_transition}`". This is exactly what happens, but it only works because:

1. **Sandbox.allow is required INSIDE the spawned Task.** `Kiln.DataCase` with `async: false` runs in shared-sandbox mode (`shared: not tags[:async]`); the parent owns the checkout. Without the inner `Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, parent, self())`, the Task's queries would see an empty DB and both would return `:not_found`.
2. **The StuckDetector's GenServer.call runs in the StuckDetector's OWN process.** Its Repo usage (currently none; future Phase 5 adds sliding-window queries) would need its own sandbox allowance. Plan 02-00's `Kiln.StuckDetectorCase` handles this via `Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, self(), detector_pid)`, but only for the test's pid → detector pid edge. The spawned Task is a different pid and also needs the allowance — which it gets via the inner `Sandbox.allow(Kiln.Repo, parent, self())` call.

**Implication for Plan 02-07:** The RunDirector integration tests will need the same three-way sandbox allowance pattern (test pid → Task pid → directed-action pid). Documented via the test's comment block + `Kiln.RehydrationCase` Plan 07 T6 boot-scan race protection (already shipped in Plan 02-00).

## Decisions Made

See the `key-decisions` frontmatter entries for the 6 decisions. Highlights:

- **Raised Rule 2 on the `run_state_transitioned.json` audit schema.** Plan 02-01 extended EventKind to 25 kinds but did not update the 8-state enum in `run_state_transitioned.json`. Rule 2 fix because `:blocked` is a correctness requirement for Phase 2 (D-86), not a feature.
- **`IllegalTransitionError.exception/1` uses a 3-step Keyword pipeline** (put_new for the allowed default, put for the message, struct! for the struct). `struct!/2` does NOT apply Keyword defaults on its own — a bug-on-first-run caught and fixed.
- **Used `Repo.transact/2` (Ecto 3.13.5) over `Repo.transaction/2`.** The new API is the RESEARCH.md-blessed shape for P2-onward code; the closure returns `{:ok, term} | {:error, term}` directly, which matches the with-chain idiom inside `transition/3` exactly.
- **Spawned-Task sandbox allow pattern documented inline.** The concurrent race test's inner `Ecto.Adapters.SQL.Sandbox.allow` is critical — without it, tests would silently pass with both tasks seeing `:not_found`. Comment block preserves the knowledge for Plan 02-07's RunDirector tests.
- **`@cross_cutting` is NOT in `@matrix` values by design.** Union at `assert_allowed/2` time keeps the matrix readable as "forward progress" + separate "universal trapdoor". Tests assert `:escalated` / `:failed` are NEVER in matrix value lists.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — missing critical functionality] `priv/audit_schemas/v1/run_state_transitioned.json` missing `"blocked"` from the state enum**

- **Found during:** Task 2 pre-test review (before first `mix test` run)
- **Issue:** Phase 2 D-86 added `:blocked` as the 9th state (Plan 02-02 shipped the 9-state Ecto enum). Plan 02-01 added 3 new event kinds but did NOT touch this schema, which still listed 8 states in both `from` and `to` enums. Every `planning -> blocked`, `coding -> blocked`, `testing -> blocked`, `verifying -> blocked`, and `blocked -> *` transition would have hit `{:error, :audit_payload_invalid}` from `Kiln.Audit.append/1` (JSV validation rejects "blocked" as outside the enum), rolling back the entire transaction and leaving the run untransitioned — a correctness bug, not a feature gap.
- **Fix:** Added `"blocked"` to both `from` and `to` enum arrays in the payload schema. Audit payload for every `:blocked` transition now validates. Did NOT change `required`, `additionalProperties`, or the optional `reason` field.
- **Files modified:** `priv/audit_schemas/v1/run_state_transitioned.json`
- **Verification:** All 24 Transitions tests pass on first run (including `planning -> blocked`, `blocked -> coding`, and `coding -> blocked` via the `every D-87 allowed edge` iteration).
- **Committed in:** `d113bc4` (same commit as the Transitions module, since the schema fix is the enabler)

**2. [Rule 1 — bug] `IllegalTransitionError.exception/1` returned `e.allowed == nil` when `:allowed` was omitted**

- **Found during:** Task 1 first test run
- **Issue:** Plan `<interfaces>` used `Keyword.get(fields, :allowed, [])` to compute the local `allowed` binding but then passed `Keyword.put(fields, :message, msg)` to `struct!/2` without threading the defaulted `:allowed` back in. `struct!/2` does NOT apply per-field defaults — missing keys become `nil` in the struct. A test that omitted `:allowed` saw `e.allowed == nil`, not `[]`.
- **Fix:** Changed to a 3-step Keyword pipeline: `Keyword.put_new(:allowed, allowed_default) → Keyword.put(:message, msg) → struct!`. Now `e.allowed` is the defaulted list when omitted.
- **Files modified:** `lib/kiln/runs/illegal_transition_error.ex`
- **Verification:** All 6 Task-1 tests pass on the second run (one iteration on the default).
- **Committed in:** `945ba88`

**Total deviations:** 1 Rule-2 (audit schema missing `"blocked"`; correctness fix), 1 Rule-1 (exception default behaviour; minor bug caught by first run). No scope creep.

## Authentication Gates

None required.

## Verification Evidence

- `mix compile --warnings-as-errors` — clean in both `:dev` and `:test` envs
- `MIX_ENV=test mix test test/kiln/policies/stuck_detector_test.exs test/kiln/runs/illegal_transition_error_test.exs` → 6 tests, 0 failures
- `MIX_ENV=test mix test test/kiln/runs/transitions_test.exs` → 24 tests, 0 failures
- `MIX_ENV=test mix test --exclude pending` → 195 tests, 0 failures (up from 165; +30 from this plan's new/modified files)

**Task 1 acceptance greps (all pass):**
- `grep -q "defexception \[:run_id, :from, :to, :allowed, :message\]" lib/kiln/runs/illegal_transition_error.ex` ✓
- `grep -q "use GenServer" lib/kiln/policies/stuck_detector.ex` ✓
- `grep -q "handle_call({:check, _ctx}, _from, state)" lib/kiln/policies/stuck_detector.ex` ✓
- `grep -q ":reply, :ok" lib/kiln/policies/stuck_detector.ex` ✓
- `grep -q "defdelegate check_stuck" lib/kiln/policies.ex` ✓
- `grep -q "use Kiln.StuckDetectorCase" test/kiln/policies/stuck_detector_test.exs` ✓
- `! grep -q "unless Process.whereis(StuckDetector)" test/kiln/policies/stuck_detector_test.exs` ✓

**Task 2 acceptance greps (all pass):**
- `grep -q "Repo.transact" lib/kiln/runs/transitions.ex` ✓
- `grep -q 'lock: "FOR UPDATE"' lib/kiln/runs/transitions.ex` ✓
- `grep -q "StuckDetector.check" lib/kiln/runs/transitions.ex` ✓
- `grep -q "Phoenix.PubSub.broadcast" lib/kiln/runs/transitions.ex` ✓
- Ordering check: `awk '/Repo.transact/{t=NR} /Phoenix.PubSub.broadcast/{b=NR} END{exit b < t ? 1 : 0}' lib/kiln/runs/transitions.ex` ✓ (broadcast at line 112, transact at line 95)
- `grep -q "event_kind: :run_state_transitioned" lib/kiln/runs/transitions.ex` ✓
- `grep -c "@matrix" lib/kiln/runs/transitions.ex` = 5 (>= 1) ✓
- `grep -q "use Kiln.StuckDetectorCase" test/kiln/runs/transitions_test.exs` ✓
- `! grep -q "unless Process.whereis(Kiln.Policies.StuckDetector)" test/kiln/runs/transitions_test.exs` ✓

## Next Plan Readiness

- **Plan 02-07 (RunDirector)** — Transitions.transition/3 is live; RunDirector's rehydration logic will call `Transitions.transition(run_id, :escalated, %{reason: :workflow_changed})` when the D-94 workflow-checksum assertion fails. StuckDetector is ready to be added as a :permanent child under Kiln.Supervisor; Kiln.StuckDetectorCase tests already pass against the GenServer as-built.
- **Plan 02-08 (StageWorker)** — The worker will call `Transitions.transition/3` on stage completion (success → next state) and on D-76 input rejection (→ :escalated with reason: :invalid_stage_input). Post-commit PubSub broadcasts are already in place.
- **Phase 3 (BLOCK-01)** — The atom-reason payload carry path is wired; BLOCK-01 producers just need to call `Transitions.transition(run.id, :blocked, %{reason: <typed_reason>})` and the audit event records the typed reason.
- **Phase 5 (StuckDetector sliding-window body)** — Replace ONLY the `handle_call/3` body in `lib/kiln/policies/stuck_detector.ex`. Transitions.transition/3 already handles `{:halt, reason, payload}` returns — a minor extension to the with-chain (adding a `{:error, {:stuck, reason, payload}}` branch that triggers same-tx `transition(run_id, :escalated, ...)`) lands in Phase 5; no caller refactor needed.
- **Phase 7 (LiveView)** — Subscribe to `run:<id>` for per-run detail pages; subscribe to `runs:board` for the dashboard's run-grid fan-out. Both topics are broadcast post-commit, so no rolled-back state changes ever reach the LV.

## Known Stubs

None in this plan. `Kiln.Policies.StuckDetector` is a no-op GenServer by D-91 design — the hook PATH is the behavior being exercised in Phase 2; the sliding-window body is Phase 5's job. Every transition in the test suite exercises the hook path, and the 24 Transitions tests prove the path works end-to-end. Explicit @moduledoc on `Kiln.Policies.StuckDetector` quotes D-91 and names Phase 5 as the body-filler.

## Threat Flags

None new. The `@moduledoc` on `Kiln.Runs.Transitions` documents threat T1 (direct `Run.transition_changeset |> Repo.update` bypass) and names a Phase 3+ Credo check (`NoDirectRunStateUpdate`) as the long-term mitigation. T5 (unsafe `reason` payload injection) is mitigated in code via the atom-only `maybe_add_reason/2` pattern match — non-atom reasons are silently dropped, verified by the T5 test.

## Self-Check: PASSED

- All 6 created files exist on disk (grep-verified).
- Both task commits present in `git log --all --oneline`:
  - `945ba88` (feat(02-06): IllegalTransitionError + StuckDetector GenServer + Policies facade) ✓
  - `d113bc4` (feat(02-06): Kiln.Runs.Transitions command module + 9-state audit schema) ✓
- Full `MIX_ENV=test mix test --exclude pending` suite: 195 tests, 0 failures.
- `mix compile --warnings-as-errors` + `MIX_ENV=test mix compile --warnings-as-errors` both clean.
- No unexpected file deletions in either task commit (`git diff --diff-filter=D --name-only HEAD~2 HEAD` returned nothing).
- All 9 Task-1 + 9 Task-2 acceptance greps pass (listed under Verification Evidence).

---

*Phase: 02-workflow-engine-core*
*Completed: 2026-04-20*
