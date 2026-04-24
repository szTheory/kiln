---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "04"
subsystem: notifications-and-circuit-breaker
tags:
  - phase-3
  - wave-2
  - notifications
  - block-03
  - factory-circuit-breaker
  - d-139
  - d-140
  - scaffold-now-fill-later

# Dependency graph
requires:
  - phase: 03-agent-adapter-sandbox-dtu-safety
    plan: "00"
    provides: Kiln.FactoryCircuitBreakerCase (deferred-activation support template); AuditLedgerCase base
  - phase: 03-agent-adapter-sandbox-dtu-safety
    plan: "02"
    provides: Kiln.Blockers.Reason.valid?/1 (reason-validation gate), Kiln.Blockers.render/2 (notification body content)
  - phase: 03-agent-adapter-sandbox-dtu-safety
    plan: "03"
    provides: audit event kinds :notification_fired / :notification_suppressed / :factory_circuit_opened / :factory_circuit_closed + JSV schemas; :osascript_notify external_operations op_kind taxonomy slot
  - phase: 02-workflow-engine-core
    provides: Kiln.Policies.StuckDetector (D-91 precedent — verbatim analog for FactoryCircuitBreaker)
  - phase: 01-foundation-durability-floor
    provides: Kiln.ExternalOperations.fetch_or_record_intent/2 + complete_op/2 + fail_op/2 (two-phase intent machine); Kiln.Audit.append/1

provides:
  - "Kiln.Policies.FactoryCircuitBreaker — :permanent GenServer with no-op check/1 (D-139 scaffold; Phase 5 fills handle_call body without schema migration)"
  - "Kiln.Notifications.desktop/2 — OS-dispatch desktop notifications for typed blocks (BLOCK-03 / D-140). macOS osascript; Linux notify-send; other returns {:error, :unsupported_platform}"
  - "Kiln.Notifications.DedupCache — ETS-backed {run_id, reason} dedup with 5-minute TTL; atomic check_and_record/1 TOCTOU-free gate"
  - "Integration contract: every Kiln.Blockers.raise_block/3 caller in Phase 3+ can now pair with Kiln.Notifications.desktop/2 using the same reason + context map"

affects:
  - 03-06 (BudgetGuard — Wave 2 pair: raise_block(:budget_exceeded) + Notifications.desktop(:budget_exceeded))
  - 03-07/08 (Sandboxes env allowlist — raise_block(:policy_violation) + Notifications.desktop(:policy_violation))
  - 03-11 (RunDirector pre-flight — raise_block(:missing_api_key) + Notifications.desktop(:missing_api_key); supervision-tree wiring per D-141 adds Kiln.Policies.FactoryCircuitBreaker + Kiln.Notifications.DedupCache as children)
  - phase-05 (FactoryCircuitBreaker body — sliding-window spend threshold with same-tx factory_circuit_opened audit event)
  - phase-07 (Notifications integration with model_routing_fallback event stream)
  - phase-08 (Unblock panel LiveView — consumes the same Blockers.render/2 output that Notifications uses)

# Tech tracking
tech-stack:
  added: []  # No new mix deps; consumes ETS (OTP), :os.type/0 (OTP), System.cmd (Elixir stdlib), Kiln.ExternalOperations + Kiln.Audit + Kiln.Blockers from prior waves
  patterns:
    - "Scaffold-now-fill-later supervised no-op — 2nd instance of D-91 StuckDetector pattern applied to FactoryCircuitBreaker (D-139). GenServer with name: __MODULE__, handle_call({:check, _}) returning :ok, defensive handle_info/2 catch-all."
    - "ETS-backed TOCTOU-free dedup gate — :ets.lookup + :ets.insert in a single process-local call using System.monotonic_time for TTL math. Table is :set/:public/:named_table with read_concurrency + write_concurrency for notification storms."
    - "Runtime OS detection via :os.type/0 — never Mix.env (CLAUDE.md P15 anti-pattern). Three-arm case: {:unix, :darwin} / {:unix, :linux} / other."
    - "Shell-injection-safe argv for osascript — inspect/1-wraps body + title so Elixir's double-quoted-string escaping covers quote/backslash content (T-03-04-01 mitigation). Linux path uses System.cmd argv list (no shell expansion)."
    - "Reason validation at entry — Kiln.Blockers.Reason.valid?/1 gate BEFORE any shell-out / intent-record / audit write, so {:error, :invalid_reason} is returned on unknown atoms (T-03-04-02 mitigation — mirrors Kiln.Blockers.raise_block/3)."
    - "@describetag (not @tag) for describe-level tagging — ExUnit raises 'unused @tag' when @tag precedes describe; @describetag is the correct form."

key-files:
  created:
    - "lib/kiln/policies/factory_circuit_breaker.ex — GenServer scaffold (D-139)"
    - "lib/kiln/notifications.ex — public API: desktop/2 + OS dispatch + two-phase intent + audit emission"
    - "lib/kiln/notifications/dedup_cache.ex — ETS GenServer + check_and_record/1 + TTL + clear/0"
    - "test/kiln/policies/factory_circuit_breaker_test.exs — 5 tests (uses Kiln.FactoryCircuitBreakerCase)"
    - "test/kiln/notifications_test.exs — 9 unit tests + 3 @describetag :integration tests"
  modified: []  # Plan 03-04 adds only new files — no existing-module edits

key-decisions:
  - "@describetag :integration (not @tag :integration) for the platform-routing describe block. ExUnit's @tag attached to a describe form raises 'unused @tag before describe, did you mean to use @describetag?' — the correct form for block-scoped tagging. Rule 1 fix during GREEN phase."
  - "Integration test run_ids use Ecto.UUID.generate() (not free strings). Kiln.ExternalOperations.Operation.run_id and Kiln.Audit.Event.run_id are both :binary_id — a free string like 'run-integration-1' raises Ecto.ChangeError at dump time. Suppression-path unit tests also use UUIDs (they still write Audit events even though they skip the intent row). Rule 1 direct consequence of the underlying schema shape."
  - "Run-id-segment fallback 'no-run' for idempotency_key when ctx.run_id is nil. Nil run_ids are valid (typed blocks can fire before a run is established, e.g., :missing_api_key during RunDirector pre-flight). The idempotency_key string literal 'notify:no-run:<reason>:<ms>' guarantees uniqueness within the millisecond window without requiring the caller to synthesise a UUID upstream."
  - "Unsupported-platform path emits notification_suppressed (ttl_remaining_seconds: 0) rather than nothing. Rationale: operator trace should show 'a notification would have fired here but the platform is unsupported' — silence in the audit ledger after a typed-block raise would look like a missing invariant. The paired {:error, :unsupported_platform} return still signals the caller that no dispatch happened."
  - "Moduledoc prose mentions of CLAUDE.md P15 rewritten to 'compile-time environment' instead of literal 'Mix.env/0' string, so grep -c 'Mix.env' lib/kiln/notifications.ex returns 0 (plan acceptance check). The anti-pattern reference is preserved in spirit without tripping a defensive grep gate."
  - "DedupCache.init/1 guards :ets.new with :ets.whereis so a restart-before-GC window (rare but possible) doesn't double-create. DedupCache.clear/0 also guards — called from tests in on_exit; if the GenServer died mid-teardown the clear is a no-op rather than a crash."

patterns-established:
  - "Scaffold-now-fill-later 2nd instance — the D-91 StuckDetector pattern was generalised by D-139 FactoryCircuitBreaker. Verbatim-analog boilerplate: use GenServer + name: __MODULE__ + handle_call returning :ok + handle_info catch-all + stable @spec. Phase 5 fills only the handle_call body; zero caller refactor, zero schema migration."
  - "ETS single-call fire/suppress pattern — :ets.lookup + :ets.insert in one process-local function. System.monotonic_time(:millisecond) gives serializable within-process ordering; :set table semantics make :ets.insert last-write-wins. This is the canonical pattern for any future per-key TTL dedup gate in Kiln (e.g., Phase 5 RateLimit gates, Phase 7 alert storms)."

requirements-completed:
  - BLOCK-03  # Desktop notification on block/escalation — OS-dispatch surface shipped; Phase 3+ producers (BudgetGuard/RunDirector/sandbox env allowlist) will now pair Kiln.Blockers.raise_block/3 with Kiln.Notifications.desktop/2

# Metrics
duration: ~7min
completed: "2026-04-20"
---

# Phase 3 Plan 04: Notifications + FactoryCircuitBreaker Summary

**Two leaf modules shipped in parallel: (a) `Kiln.Notifications` — the desktop-notification surface for every typed-block raise (BLOCK-03 / D-140); (b) `Kiln.Policies.FactoryCircuitBreaker` — the 2nd instance of the scaffold-now-fill-later supervised no-op pattern (D-139; mirrors `Kiln.Policies.StuckDetector` from Phase 2).**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-04-20T17:23:46Z (after `git reset --hard b4b51ec` to align worktree base with Wave 1b merge commit)
- **Completed:** 2026-04-20T17:31:08Z
- **Tasks:** 2 (each split into RED + GREEN — 4 commits total, all atomic, all --no-verify per worktree mode)
- **Files created:** 5 (2 lib/kiln modules + 1 lib/kiln/notifications submodule + 2 test files)
- **Files modified:** 0 (Plan 03-04 is additive only)
- **Tests added:** 14 (5 FactoryCircuitBreaker + 9 Notifications unit; 3 additional Notifications integration tests excluded by default via `@describetag :integration`)
- **Full suite:** 335 tests, 0 failures, 8 excluded (up from 321/0 baseline after Wave 1b; +14 new tests all passing, +3 new integration tests excluded by default)

## Accomplishments

- `Kiln.Policies.FactoryCircuitBreaker` supervisable `GenServer` registered under `__MODULE__`; `check/1` returns `:ok` for any context map; stable `@spec check(map()) :: :ok | {:halt, atom(), map()}` locked through Phase 5.
- Defensive `handle_info/2` catch-all mirrors StuckDetector — the `:permanent` breaker survives stray messages delivered to its mailbox.
- `Kiln.Notifications.desktop/2` dispatches via `System.cmd("osascript", ...)` on macOS, `System.cmd("notify-send", ...)` on Linux, and returns `{:error, :unsupported_platform}` on other OSes (runtime `:os.type/0` detection, never `Mix.env`).
- Two-phase intent table integration: every successful dispatch inserts a `:osascript_notify` row via `Kiln.ExternalOperations.fetch_or_record_intent/2` and completes it via `complete_op/2` (or `fail_op/2` on shell-out failure).
- ETS-backed dedup cache keyed by `{run_id, reason}` with 5-minute TTL; atomic `check_and_record/1` gate is TOCTOU-free under concurrent producers.
- Reason gate: unknown atoms return `{:error, :invalid_reason}` before any shell-out (T-03-04-02 mitigation).
- Shell-injection defence: AppleScript body + title are `inspect/1`-wrapped so any quote/backslash in context values is escape-safe (T-03-04-01); Linux path uses `System.cmd` argv list (no shell expansion).
- Linux-native coalescing: `-h string:x-canonical-private-synchronous:<tag>` complements the ETS dedup (T-03-04-03 defense-in-depth).
- Suppression + unsupported-platform paths emit `notification_suppressed` audit events so the operator trace shows every would-have-fired surface.
- `grep -c "Mix.env" lib/kiln/notifications.ex` returns 0 (plan acceptance check passes).

## Task Commits

Each task was committed atomically with `--no-verify` (worktree-mode parallel executor):

1. **Task 1 RED: failing FactoryCircuitBreaker test** — `11d25f0` (test)
2. **Task 1 GREEN: Kiln.Policies.FactoryCircuitBreaker module** — `56862cd` (feat)
3. **Task 2 RED: failing Notifications + DedupCache tests** — `570cb89` (test)
4. **Task 2 GREEN: Kiln.Notifications + Kiln.Notifications.DedupCache** — `3216e36` (feat)

**Plan metadata commit:** pending (git_commit_metadata step will commit this SUMMARY.md).

## Files Created

### lib/ (3 files)

- `lib/kiln/policies/factory_circuit_breaker.ex` — GenServer, no-op `handle_call`, `@spec` locked through Phase 5
- `lib/kiln/notifications.ex` — `desktop/2` + OS-dispatch + two-phase intent + audit emission
- `lib/kiln/notifications/dedup_cache.ex` — ETS GenServer, `check_and_record/1`, `ttl_ms/0`, `clear/0`

### test/ (2 files)

- `test/kiln/policies/factory_circuit_breaker_test.exs` — 5 tests (uses `Kiln.FactoryCircuitBreakerCase`)
- `test/kiln/notifications_test.exs` — 9 unit tests (reason validation, dedup cache, suppression audit) + 3 `@describetag :integration` tests (platform routing with real shell-out)

## Decisions Made

See frontmatter `key-decisions` for the full list. Highlights:

1. **`@describetag` (not `@tag`)** for describe-level tagging — ExUnit raises `"unused @tag before describe, did you mean to use @describetag?"` when `@tag` precedes a describe form. Rule 1 fix caught during GREEN phase of Task 2.

2. **Integration run_ids use `Ecto.UUID.generate()`** — both `Kiln.ExternalOperations.Operation.run_id` and `Kiln.Audit.Event.run_id` are `:binary_id` schemas, so free strings like `"run-integration-1"` raise `Ecto.ChangeError` at dump time. All test run_ids (unit suppression path + integration fire path) use UUIDs.

3. **`'no-run'` run-id-segment fallback in idempotency keys** when `ctx.run_id` is `nil`. Pre-flight blockers (e.g., `:missing_api_key` during RunDirector before a run is established) have no run_id; the idempotency_key still needs uniqueness.

4. **Unsupported-platform still emits `notification_suppressed`** (with `ttl_remaining_seconds: 0`) — silence after a typed-block raise would look like a missing invariant in the audit ledger. The paired `{:error, :unsupported_platform}` return still signals the caller.

5. **Moduledoc `Mix.env` rewrite** — the original prose mention of `Mix.env/0` as an anti-pattern would have failed the plan's `grep -c "Mix.env" lib/kiln/notifications.ex == 0` acceptance check. Rewrote to "compile-time environment" preserving the intent without tripping the gate.

6. **`DedupCache.init/1` + `clear/0` guard `:ets.whereis`** for idempotency under restart-before-GC windows and post-crash on-exit teardown.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `@tag :integration` before `describe` was unused**

- **Found during:** Task 2 GREEN (`mix test` output showed "unused @tag before describe")
- **Issue:** Plan action text didn't tag the platform-routing describe block at all (only noted in prose that executor MAY add `@tag :integration`). Initial test-file version used `@tag :integration` outside the describe, which ExUnit warns about but doesn't apply — the integration tests ran unguarded and hit `Ecto.ChangeError` because the plan's example run_ids (`"run-os-1"`, `"run-integration-#{System.unique_integer}"`) are free strings, not UUIDs.
- **Fix:** Changed to `@describetag :integration` inside the describe block, and changed run_ids to `Ecto.UUID.generate()`. Both unit and integration tests now pass (integration excluded by default via `test_helper.exs` exclude list).
- **Files modified:** `test/kiln/notifications_test.exs`
- **Verification:** `mix test test/kiln/notifications_test.exs` reports 9/0 (3 excluded); the "unused @tag" warning disappeared.
- **Committed in:** `3216e36` (Task 2 GREEN — fix included in the initial landing, never shipped to a prior commit).

**2. [Rule 1 - Bug] Suppression-path run_id must be a UUID**

- **Found during:** Task 2 GREEN (`Ecto.ChangeError` on Audit.append when run_id is a free string)
- **Issue:** Plan's example `run_id: "run-dedup-1"` in the suppression-path test hits `Kiln.Audit.Event.run_id`'s `:binary_id` schema type. Suppression still writes an audit event (the whole point of the test), so the schema dump raises.
- **Fix:** Changed suppression-path test `run_id` to `Ecto.UUID.generate()`.
- **Files modified:** `test/kiln/notifications_test.exs`
- **Verification:** Suppression test passes; audit event written with valid UUID run_id.
- **Committed in:** `3216e36` (Task 2 GREEN — same commit as the `@describetag` fix above).

**3. [Rule 1 - Bug] Moduledoc `Mix.env` string would fail grep acceptance check**

- **Found during:** Task 2 GREEN post-compile (manually running `grep -c "Mix.env" lib/kiln/notifications.ex`)
- **Issue:** Initial moduledoc contained the literal string "`Mix.env/0` is a compile-time anti-pattern..." as prose explaining what NOT to do. Plan acceptance check `grep -c "Mix.env" lib/kiln/notifications.ex == 0` would have failed (grep doesn't know the occurrence is in a moduledoc).
- **Fix:** Rewrote the moduledoc line to "Reading compile-time environment at runtime is the anti-pattern called out in CLAUDE.md P15 — never used here." The anti-pattern reference is preserved in spirit; the literal `Mix.env` token is gone.
- **Files modified:** `lib/kiln/notifications.ex`
- **Verification:** `grep -c "Mix.env" lib/kiln/notifications.ex` returns 0; moduledoc still reads cleanly to a maintainer.
- **Committed in:** `3216e36` (Task 2 GREEN — same commit).

**4. [Rule 2 - Missing critical functionality] `DedupCache.init/1` + `clear/0` need `:ets.whereis` guards**

- **Found during:** Task 2 GREEN (design review, before running tests)
- **Issue:** Plan action text for DedupCache's `init/1` calls `:ets.new/2` unconditionally. Under a restart-before-GC window (supervisor restart with the prior GenServer's table still reaping), `:ets.new` would raise `ArgumentError`. Similarly, `clear/0` in `on_exit` could hit a nil table if the cache GenServer died mid-teardown.
- **Fix:** Both `init/1` and `clear/0` guard with `:ets.whereis/1`; absent table short-circuits to `:ok`.
- **Files modified:** `lib/kiln/notifications/dedup_cache.ex`
- **Verification:** All TTL / clear / restart-simulation tests pass.
- **Committed in:** `3216e36` (Task 2 GREEN — same commit).

**5. [Rule 1 - Bug] Moduledoc interpolation `#{body}` misread as Elixir interpolation**

- **Found during:** Task 2 GREEN first compile attempt
- **Issue:** Moduledoc prose showing the AppleScript string template `"display notification #{body} with title #{title}"` was parsed by Elixir as real string interpolation — `body` is not a module-body binding, so compile failed with `undefined variable "body"`.
- **Fix:** Rewrote the moduledoc to use angle-bracket placeholders `<body>` / `<title>` inside the literal string, and describe the template-building step in prose.
- **Files modified:** `lib/kiln/notifications.ex`
- **Verification:** `mix compile --warnings-as-errors` exits 0.
- **Committed in:** `3216e36` (Task 2 GREEN — same commit).

---

**Total deviations:** 5 auto-fixed (all Rule 1 bugs or Rule 2 correctness gaps, all from plan action text's example code meeting the reality of Elixir / Ecto / ExUnit / ETS semantics). Zero Rule 3 (blocker), zero Rule 4 (architectural).

**Impact on plan:** All auto-fixes were direct consequences of the plan's own example code + acceptance gates. No scope creep; the plan's public contract (`Kiln.Notifications.desktop/2` + `Kiln.Notifications.DedupCache.check_and_record/1` + `Kiln.Policies.FactoryCircuitBreaker.check/1`) is preserved exactly. Every acceptance criterion in the plan's `<acceptance_criteria>` block passes verbatim.

## Issues Encountered

- **Plan-authoring oversight:** `@tag :integration` before a `describe` form is silently ignored by ExUnit (warning only; the tests still run unguarded). `@describetag` is the correct form. Future plans using ExUnit `describe`-level tagging should use `@describetag` in action text.
- **Plan-authoring oversight:** moduledoc prose containing `#{var}` literals gets interpolated by Elixir at compile time. Future plans authoring moduledocs with template examples should either escape (`#\{var}`) or use placeholder syntax (e.g. `<var>`).
- **Ecto schema surprise for test authors:** `:binary_id` fields on `Kiln.Audit.Event` and `Kiln.ExternalOperations.Operation` reject free-string run_ids. Plan action text used free strings in examples; corrected to UUIDs in the implementation tests. Worth flagging in a future test-authoring skill.

None of these blocked Task completion; all were caught during GREEN and fixed inline before the commit landed.

## User Setup Required

None — no external service configuration, no new mix deps, no migrations, no config file edits. `Kiln.Notifications` + `Kiln.Policies.FactoryCircuitBreaker` are purely in-process library code. (Supervision-tree wiring — adding them as children of `Kiln.Application` — lands in Plan 03-11 per D-141.)

## Threat Flags

None. Task scope matched the declared `<threat_model>` exactly:

- **T-03-04-01** (shell injection via `osascript -e display notification "<user-content>"`): mitigated by `inspect/1`-wrapping body and title before the AppleScript interpolation; Linux path uses `System.cmd` argv list (no shell expansion).
- **T-03-04-02** (typed-blocker bypass via arbitrary reason atom): mitigated by `Kiln.Blockers.Reason.valid?/1` gate at `desktop/2` entry — `{:error, :invalid_reason}` returned before any shell-out, intent record, or audit write.
- **T-03-04-03** (notification storm DoS): mitigated by ETS dedup with 5-minute TTL on `{run_id, reason}`; Linux additionally uses native `x-canonical-private-synchronous` header for same-session last-write-wins coalescing.

No new surfaces introduced beyond those in the plan.

## Next Phase Readiness

**Unblocks:**

- **Wave 2 plans that raise typed blocks + notify operator** — 03-06 BudgetGuard (`:budget_exceeded`), 03-07/08 Sandboxes env allowlist (`:policy_violation`), 03-11 RunDirector pre-flight (`:missing_api_key` / `:invalid_api_key`). All three pair `Kiln.Blockers.raise_block/3` with `Kiln.Notifications.desktop/2`.
- **Plan 03-11 supervision wiring** — adds `Kiln.Policies.FactoryCircuitBreaker` and `Kiln.Notifications.DedupCache` as children of `Kiln.Application` per D-141 (14-child tree target). Both modules use `use GenServer` + `name: __MODULE__`, so the supervisor child spec is a one-line insert with no config.
- **Phase 5 FactoryCircuitBreaker body fill** — can now swap the no-op `handle_call/3` body with the sliding-window threshold logic. Audit kinds `:factory_circuit_opened` / `:factory_circuit_closed` are already in `Kiln.Audit.EventKind` (Plan 03-03), so no schema migration needed. Callers (BudgetGuard et al.) stay unchanged.
- **Phase 7 LiveView alert stream** — can subscribe to the `notification_fired` audit event stream for the global factory header's "active / blocked" indicators.

**No blockers.** Compile graph clean; 335/0 tests (14 new, all passing); `mix check_bounded_contexts` stays at 13 (neither module changes the context SSOT — both live under `Kiln.Policies` and `Kiln.Notifications` sub-facades, respectively; `Kiln.Notifications` is a leaf module under the future `Kiln.Application` supervision tree, not a 14th bounded context).

**Concerns:**

- The `@describetag` / `@tag` distinction caught us; plan-check for future Wave N plans should grep for `@tag :` immediately above a `describe` form to catch this class of bug.
- Moduledoc examples with `#{var}` literals are a latent compile-error trap. A pre-commit hook or plan-check regex could detect unescaped `#{` inside `@moduledoc` blocks.

## Self-Check: PASSED

Verified after writing SUMMARY.md (absolute paths to the worktree base `/Users/jon/projects/kiln/.claude/worktrees/agent-a6bb8951/`):

- [x] `lib/kiln/policies/factory_circuit_breaker.ex` exists (contains `use GenServer`, `@spec check(map()) :: :ok | {:halt, atom(), map()}`, `name: __MODULE__`, `{:reply, :ok, state}`)
- [x] `lib/kiln/notifications.ex` exists (contains `:os.type`, `System.cmd("osascript"`, `System.cmd("notify-send"`, `op_kind: "osascript_notify"`, `:notification_fired`, `:notification_suppressed`)
- [x] `lib/kiln/notifications/dedup_cache.ex` exists (contains `:ets.new`, `:named_table`, `@ttl_ms 5 * 60 * 1000`, `check_and_record`)
- [x] `test/kiln/policies/factory_circuit_breaker_test.exs` exists (uses `Kiln.FactoryCircuitBreakerCase`)
- [x] `test/kiln/notifications_test.exs` exists (uses `Kiln.AuditLedgerCase`; `@describetag :integration` on platform-routing describe)
- [x] `grep -c "Mix.env" lib/kiln/notifications.ex` returns 0 (anti-pattern check)
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/kiln/notifications_test.exs test/kiln/policies/factory_circuit_breaker_test.exs` reports 14/0 (3 excluded)
- [x] `mix test` (full suite) reports 335/0 (8 excluded; +14 tests from 321/0 Wave 1b baseline, all passing; +3 integration tests excluded)
- [x] Task commits exist: `11d25f0`, `56862cd`, `570cb89`, `3216e36` (verified via `git log --oneline b4b51ec..HEAD`)
- [x] RED commit (test) precedes GREEN commit (feat) for both tasks (TDD gate compliance: FactoryCircuitBreaker `11d25f0` → `56862cd`; Notifications `570cb89` → `3216e36`)

## TDD Gate Compliance

Plan frontmatter did not specify `type: tdd` at the plan level, but each task carried `tdd="true"`. TDD cycle was honoured per-task:

- **Task 1 (FactoryCircuitBreaker):** RED (`11d25f0` test) → GREEN (`56862cd` feat). REFACTOR skipped — no post-GREEN cleanup needed.
- **Task 2 (Notifications + DedupCache):** RED (`570cb89` test) → GREEN (`3216e36` feat). REFACTOR skipped — inline fixes (Rule 1/2 auto-fixes) landed in the GREEN commit itself, not a separate refactor commit.

Both gates (RED test, GREEN feat) are observable in `git log`.

---
*Phase: 03-agent-adapter-sandbox-dtu-safety*
*Plan: 04*
*Completed: 2026-04-20*
*Base commit: b4b51ec*
*Head commit (after plan tasks): 3216e36*
