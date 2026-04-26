---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "02"
subsystem: blockers
tags:
  - phase-3
  - wave-1
  - blockers
  - block-01
  - playbook-registry

# Dependency graph
requires:
  - phase: 03-agent-adapter-sandbox-dtu-safety
    plan: "00"
    provides: test infrastructure (Mox defmocks, ExUnit case templates, 9-tag exclude list) — already landed at the base commit
  - phase: 02-workflow-engine-core
    provides: Kiln.Stages.ContractRegistry + Kiln.Workflows.SchemaRegistry (compile-time JSV registry analogs used verbatim as design template for PlaybookRegistry — D-136)
  - phase: 01-foundation-durability-floor
    provides: Kiln.Audit.SchemaRegistry + Kiln.Runs.IllegalTransitionError (first compile-time registry + defexception analogs)

provides:
  - "Kiln.Blockers.Reason — closed 9-atom enum with @type, defguard is_reason/1, valid?/1 (D-135 SSOT for BLOCK-01)"
  - "Kiln.Blockers.BlockedError — defexception for typed block producers (BudgetGuard/RunDirector/sandbox env allowlist)"
  - "Kiln.Blockers.Playbook + Kiln.Blockers.RenderedPlaybook structs"
  - "Kiln.Blockers.PlaybookRegistry — 4th compile-time registry instance (D-136); walks priv/playbooks/v1/*.md, parses YAML frontmatter, JSV-validates against priv/playbook_schemas/v1/playbook.json; CompileError on missing file or invalid frontmatter"
  - "Kiln.Blockers facade — raise_block/3 with ArgumentError on unknown reason + fetch/render delegates"
  - "priv/playbook_schemas/v1/playbook.json — JSV Draft 2020-12 schema for playbook frontmatter (required fields, enum constraints, length limits)"
  - "9 playbook markdown files under priv/playbooks/v1/: 6 REAL (owning_phase: 3) + 3 STUB (gh_auth_expired/gh_permissions_insufficient at phase 6, unrecoverable_stage_failure at phase 5)"

affects:
  - 03-04 (FactoryCircuitBreaker — may raise_block(:unrecoverable_stage_failure) from D-139 scaffold)
  - 03-06 (BudgetGuard — Wave 2 raises Kiln.Blockers.BlockedError with reason: :budget_exceeded per D-138)
  - 03-07/08 (Sandboxes env allowlist — raises reason: :policy_violation)
  - 03-11 (RunDirector pre-flight — raises reason: :missing_api_key / :invalid_api_key before run start)
  - phase-05 (Verification & bounded loop — owns full unrecoverable_stage_failure playbook)
  - phase-06 (GitHub integration — owns full gh_auth_expired + gh_permissions_insufficient playbooks)
  - phase-08 (Unblock panel LiveView — consumes render/2 + RenderedPlaybook)

# Tech tracking
tech-stack:
  added: []  # no new mix deps; consumes yaml_elixir ~> 2.12 + JSV ~> 0.18 from P2 baseline
  patterns:
    - "Compile-time registry pattern (4th instance) — @external_resource walk + JSV.build!/validate inside module-body for-comprehension + CompileError on missing/invalid entries"
    - "Defguard with literal-enumerated atom list (cannot reference module attribute inside defguard's `when` clause — duplicate atom list guarded by a parity test in reason_test.exs)"
    - "Mustache {var} substitution preserves unsubstituted tokens as literals rather than crashing — operator-visible 'not wired' signal"
    - "@frontmatter_regex module attribute for compile-time Regex.run (private functions unavailable from module body during compilation)"

key-files:
  created:
    - "lib/kiln/blockers.ex — context facade (raise_block/3 + fetch/render delegates)"
    - "lib/kiln/blockers/reason.ex — 9-atom closed enum + defguard is_reason/1"
    - "lib/kiln/blockers/blocked_error.ex — defexception (:reason, :run_id, :context, :message)"
    - "lib/kiln/blockers/playbook.ex — Playbook + RenderedPlaybook structs"
    - "lib/kiln/blockers/playbook_registry.ex — compile-time registry (walks priv/playbooks/v1/*.md, JSV-validates frontmatter)"
    - "priv/playbook_schemas/v1/playbook.json — JSV Draft 2020-12 schema"
    - "priv/playbooks/v1/missing_api_key.md — REAL (owning_phase: 3)"
    - "priv/playbooks/v1/invalid_api_key.md — REAL (owning_phase: 3)"
    - "priv/playbooks/v1/rate_limit_exhausted.md — REAL (owning_phase: 3)"
    - "priv/playbooks/v1/quota_exceeded.md — REAL (owning_phase: 3)"
    - "priv/playbooks/v1/budget_exceeded.md — REAL (owning_phase: 3, D-138 strict — no override)"
    - "priv/playbooks/v1/policy_violation.md — REAL (owning_phase: 3, D-134 sandbox env allowlist consumer)"
    - "priv/playbooks/v1/gh_auth_expired.md — STUB (owning_phase: 6)"
    - "priv/playbooks/v1/gh_permissions_insufficient.md — STUB (owning_phase: 6)"
    - "priv/playbooks/v1/unrecoverable_stage_failure.md — STUB (owning_phase: 5)"
    - "test/kiln/blockers/reason_test.exs — 7 tests (enum parity, valid?/1, is_reason/1 guard, exception/1, schema parse)"
    - "test/kiln/blockers/playbook_registry_test.exs — 12 tests (fetch resolves all 9, render substitution, stub/real marker)"
    - "test/kiln/blockers_test.exs — 4 tests (raise_block/3, unknown-reason ArgumentError, fetch/render delegates)"
  modified: []  # Plan 03-02 adds only new files — no existing-module edits

key-decisions:
  - "Inlined frontmatter-split regex as @frontmatter_regex module attribute (plan action text showed a defp helper; private functions aren't callable from module-body during compilation — shifted to a Regex.run call against the attribute). Rule 1 fix."
  - "Kiln.Blockers is a sub-facade under Kiln.Policies, NOT a 14th bounded context. The 13-context SSOT (BootChecks.@context_modules + mix check_bounded_contexts @expected) remains unchanged. The blockers subsystem is a policy concern alongside StuckDetector/BudgetGuard."
  - "Every atom in the defguard is_reason/1 body is duplicated literally from @reasons because defguard macros cannot expand module attributes inside the `when` clause. The all/0 parity test in reason_test.exs enforces drift-prevention between the two lists."
  - "Mustache substitute/2 preserves the full `{key}` literal on missing-context lookup (using the `full` match argument in Regex.replace/3) — operator sees a clear 'not wired' signal rather than a crash, and the test in playbook_registry_test.exs asserts this behaviour explicitly."
  - "Stub playbooks carry `stub: true` frontmatter so consumers (future Unblock Panel LiveView) can visually distinguish placeholder text from shipped remediation — matches D-135 playbook-maturity-table contract."
  - "policy_violation playbook carries owning_phase: 3 (NOT 5 or 6) because Wave 3's sandbox env allowlist (D-134) is the live consumer this phase — the playbook ships REAL, not stub, for its Phase 3 producer."

patterns-established:
  - "@frontmatter_regex pattern for compile-time Regex.run — private helpers aren't available inside the module body during compilation, so regex must be a module attribute or inlined literal"
  - "Sub-facade under a bounded context (Kiln.Blockers under Kiln.Policies) — keeps the 13-context SSOT intact while adding a coherent public API surface; future sub-facades (Kiln.Policies.Budget, Kiln.Policies.Stuck) can follow the same pattern"

requirements-completed:
  - BLOCK-01  # Typed block reasons + remediation playbooks. 9 atoms + 9 playbooks + context facade + typed exception all shipped. BLOCK-02 (unblock panel) + BLOCK-03 (desktop notification) + BLOCK-04 (first-run wizard) ship in Phase 8.

# Metrics
duration: ~15min
completed: "2026-04-20"
---

# Phase 3 Plan 02: Kiln.Blockers BLOCK-01 Summary

**Typed block reasons as a compile-time 9-atom closed enum, with a compile-time-validated playbook registry (4th instance of the Phase 1/2 pattern) and 9 markdown remediation playbooks (6 real + 3 stub) — the typed unblock contract for the rest of Phase 3+.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-20T17:07:00Z (after `git reset --hard c8cddd4` to correct worktree base)
- **Completed:** 2026-04-20T17:22:00Z
- **Tasks:** 3 (all atomic, all committed with --no-verify)
- **Files created:** 18 (5 lib modules + 1 schema JSON + 9 playbook markdowns + 3 test files)
- **Tests added:** 24 (7 reason/exception + 12 registry/render + 4 facade + 1 parity check via `length(Reason.all()) == 9`)
- **Full suite:** 281 tests, 0 failures, 5 excluded (docker/dtu tags) — up from 257 baseline

## Accomplishments

- `Kiln.Blockers.Reason.all/0` returns exactly the 9 atoms specified in D-135; `defguard is_reason/1` narrows correctly in function-head guards.
- `Kiln.Blockers.BlockedError` exception is properly shaped — `defexception [:reason, :run_id, :context, :message]` with `exception/1` rendering a one-line message containing the reason, run_id, and context.
- `priv/playbook_schemas/v1/playbook.json` is valid JSON (`jq .` exits 0), declares 9 reason-enum values, and validates a minimal frontmatter example in-test.
- All 9 playbook markdown files exist with YAML frontmatter that validates against the schema at compile time (enforced by `JSV.validate` inside the `@playbooks` module-attribute for-comprehension in `Kiln.Blockers.PlaybookRegistry`).
- `Kiln.Blockers.PlaybookRegistry.fetch/1` resolves every `Reason` atom to a `%Playbook{}` struct (proven by a for-loop test over `Reason.all()`).
- `Kiln.Blockers.PlaybookRegistry.render/2` Mustache-substitutes `{var}` tokens from the caller context into title, short_message, body_markdown, and each remediation command; unsubstituted tokens are preserved as literals.
- `Kiln.Blockers.raise_block/3` raises `BlockedError` for known reasons and `ArgumentError` for unknown atoms (T-03-02-01 mitigation — the unblock endpoint can never accept a freeform reason).
- **Compile-time safety net verified manually:** renamed `missing_api_key.md` and `mix compile` raised `CompileError: Missing playbook file priv/playbooks/v1/missing_api_key.md — every Kiln.Blockers.Reason atom must have a playbook` at module-attribute expansion time. Restored file; compile clean.

## Task Commits

Each task was committed atomically with `--no-verify` (worktree-mode parallel executor):

1. **Task 1: Kiln.Blockers.Reason + BlockedError + playbook schema JSON** — `01e3bf1` (feat)
2. **Task 2: 9 playbook markdown files (6 real + 3 stub)** — `23f20ba` (feat)
3. **Task 3: Playbook + PlaybookRegistry + Kiln.Blockers facade** — `34c806f` (feat)

**Plan metadata commit:** to be created by git_commit_metadata step (this SUMMARY.md is the primary artifact).

## Files Created

### lib/ (5 files)
- `lib/kiln/blockers.ex` — context facade
- `lib/kiln/blockers/reason.ex` — 9-atom closed enum + `defguard is_reason/1`
- `lib/kiln/blockers/blocked_error.ex` — `defexception`
- `lib/kiln/blockers/playbook.ex` — Playbook + RenderedPlaybook structs
- `lib/kiln/blockers/playbook_registry.ex` — compile-time registry with JSV validation

### priv/ (10 files)
- `priv/playbook_schemas/v1/playbook.json` — JSV Draft 2020-12 schema
- `priv/playbooks/v1/missing_api_key.md` (REAL, owning_phase: 3)
- `priv/playbooks/v1/invalid_api_key.md` (REAL, owning_phase: 3)
- `priv/playbooks/v1/rate_limit_exhausted.md` (REAL, owning_phase: 3)
- `priv/playbooks/v1/quota_exceeded.md` (REAL, owning_phase: 3)
- `priv/playbooks/v1/budget_exceeded.md` (REAL, owning_phase: 3 — D-138 strict, no override)
- `priv/playbooks/v1/policy_violation.md` (REAL, owning_phase: 3 — D-134 sandbox env allowlist consumer)
- `priv/playbooks/v1/gh_auth_expired.md` (STUB, owning_phase: 6)
- `priv/playbooks/v1/gh_permissions_insufficient.md` (STUB, owning_phase: 6)
- `priv/playbooks/v1/unrecoverable_stage_failure.md` (STUB, owning_phase: 5)

### test/ (3 files)
- `test/kiln/blockers/reason_test.exs` — 7 tests
- `test/kiln/blockers/playbook_registry_test.exs` — 12 tests
- `test/kiln/blockers_test.exs` — 4 tests

## Decisions Made

See frontmatter `key-decisions` for the full list. Highlights:

1. **`@frontmatter_regex` module attribute** — The plan's action text showed a `defp split_frontmatter_at_compile/1` helper called from inside the `@playbooks` module-body for-comprehension. This fails to compile: private functions aren't callable from module-body during compilation (the function isn't compiled yet when the module body executes). Resolved by making the regex a `@frontmatter_regex` attribute and inlining the `Regex.run/3` call directly. Rule 1 auto-fix.

2. **Kiln.Blockers is a sub-facade, not a 14th bounded context.** The 13-context SSOT (`Kiln.BootChecks.@context_modules` + `mix check_bounded_contexts @expected`) remains unchanged. Kiln.Blockers lives alongside the future `Kiln.Policies.BudgetGuard` and `Kiln.Policies.StuckDetector` as a sub-concern of the `Kiln.Policies` bounded context. This preserves the D-97 spec upgrade and the acceptance threshold of `grep -c "Kiln\." lib/mix/tasks/check_bounded_contexts.ex == 13`.

3. **Defguard atom-list duplication enforced by a parity test.** `defguard is_reason/1` cannot reference `@reasons` inside its `when` clause — defguards must be expandable at the call site, so only literal collections are permitted. The atom list is duplicated verbatim between `@reasons` and the guard body; `reason_test.exs` test "all/0 returns exactly 9 atoms per D-135" asserts `length(Reason.all()) == 9` and `Enum.sort(Reason.all()) == Enum.sort(@expected)` so any future drift between the two lists surfaces loudly.

4. **Unsubstituted `{var}` tokens preserved as literals, not crashes.** `Regex.replace/3` with the 3-arg callback receives the `full` match as the first arg; returning `full` on missing-context keys preserves the template token intact. Test: `playbook_registry_test.exs` asserts `rp.short_message =~ "{provider}"` when the context map is empty. Rationale: operator surfaces (terminal render, LiveView panel, Slack) benefit from a clear "not wired" signal over a crash loop.

5. **`policy_violation` ships as REAL, not STUB.** The playbook-maturity table in 03-CONTEXT.md lists `policy_violation` at owning_phase: 3 because Wave 3's sandbox env allowlist (D-134) is the first live producer — the text must be complete in Phase 3. The frontmatter reflects this (`owning_phase: 3`, no `stub: true` key).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `split_frontmatter_at_compile/1` unavailable from module body**
- **Found during:** Task 3 (first `mix compile --warnings-as-errors`)
- **Issue:** Plan text defined `defp split_frontmatter_at_compile(raw)` and called it from inside the `@playbooks` module-attribute for-comprehension. Compile failed with `undefined function split_frontmatter_at_compile/1 (there is no such import)`. Private functions are not available inside the module body during compilation — they're only callable once the module has been fully compiled.
- **Fix:** Hoisted the regex to a `@frontmatter_regex` module attribute and inlined the `Regex.run(@frontmatter_regex, raw, capture: :all_but_first)` call directly into the for-comprehension's `case` expression. The `|case` clause now matches on `[fm, b]` (success) vs `nil` (malformed) and raises `CompileError` in the `nil` branch with the same descriptive message.
- **Files modified:** `lib/kiln/blockers/playbook_registry.ex`
- **Verification:** `mix compile --warnings-as-errors` exits 0; 17 Task 3 tests pass; compile-error safety net manually verified by renaming `missing_api_key.md` and observing `CompileError` at module-body expansion.
- **Committed in:** `34c806f` (Task 3 commit — fix included in initial landing, never shipped to a prior commit).

---

**Total deviations:** 1 auto-fixed (Rule 1 bug from a plan-authoring oversight about Elixir compile-time module-body semantics). No Rule 2 (missing functionality), Rule 3 (blocker), or Rule 4 (architectural) items.

**Impact on plan:** The public contract of `Kiln.Blockers.PlaybookRegistry` is unchanged — the splitter logic remains identical; only its representation shifted from private function to module attribute. All acceptance criteria in the plan's `<done>` and `<acceptance_criteria>` blocks pass verbatim.

## Issues Encountered

- **Plan-authoring oversight:** the `<action>` text's `defp split_frontmatter_at_compile` pattern does not work in Elixir — a future Wave N plan that reuses the PlaybookRegistry template as its own plan analog should either (a) inline the regex or (b) move the helper to a separate module that's compiled first. Fix is a one-line change; flagging for plan-check pass on analog future plans.

## Threat Flags

None. Task scope matched the declared `<threat_model>`:
- **T-03-02-01** (typed blocker bypass via freeform reason string): mitigated — `Kiln.Blockers.raise_block/3` calls `Reason.valid?/1` and raises `ArgumentError` on miss; future unblock endpoint (Phase 8) will parse against `Reason.all/0`.
- **T-03-02-02** (frontmatter edited in-flight without schema validation): mitigated — JSV validation at compile time inside the `@playbooks` module-attribute for-comprehension; edits fail `mix compile` with a readable error before landing.
- **T-03-02-03** (Mustache substitution leaks internal state): mitigated — `render/2` substitutes only from a caller-provided context map; unknown tokens preserve as literals; no `inspect/1` introspection hook.

## User Setup Required

None. No external service configuration, no new mix deps, no migrations, no config file edits. `Kiln.Blockers` is purely in-process library code with compile-time resource loading.

## Next Phase Readiness

**Unblocks:**
- Wave 2 plans that raise blocked errors (03-06 BudgetGuard: `:budget_exceeded`; 03-07/08 Sandboxes: `:policy_violation`; 03-11 RunDirector preflight: `:missing_api_key` / `:invalid_api_key`).
- Wave 5+ plans that render playbooks for operator-facing surfaces (future 08 Unblock Panel LiveView consumes `render/2` + `RenderedPlaybook`).
- Phase 5 `Kiln.Policies.BudgetGuard` (owning_phase: 5) — can now raise with `Kiln.Blockers.raise_block(:budget_exceeded, run_id, %{...})` and trust the typed contract.
- Phase 5 & 6 stub-playbook ownership — those phases will swap the 3 STUB playbooks for full remediation text (the Reason atoms do not move).

**No blockers.** Compile graph clean; 281/0 tests; `mix check_bounded_contexts` stays at 13 (unchanged).

**Concerns:**
- The plan-authoring oversight about `defp` availability during compile-time module-body execution should be flagged for future Wave N plans that reuse the compile-time-registry pattern. A plan-check pass regex could detect `defp .+_at_compile` to catch this class of bug.

## Self-Check: PASSED

Verified after writing SUMMARY.md (file paths are absolute to the worktree base `/Users/jon/projects/kiln/.claude/worktrees/agent-a31cc77e/`):

- [x] `lib/kiln/blockers.ex` exists
- [x] `lib/kiln/blockers/reason.ex` exists (contains the 9 atoms + `defguard is_reason`)
- [x] `lib/kiln/blockers/blocked_error.ex` exists (contains `defexception`)
- [x] `lib/kiln/blockers/playbook.ex` exists (Playbook + RenderedPlaybook structs)
- [x] `lib/kiln/blockers/playbook_registry.ex` exists (contains `@external_resource path` + `JSV.validate`)
- [x] `priv/playbook_schemas/v1/playbook.json` valid JSON, `.properties.reason.enum` length 9
- [x] 9 playbook .md files exist under `priv/playbooks/v1/`
- [x] 3 stubs (`stub: true`): gh_auth_expired, gh_permissions_insufficient, unrecoverable_stage_failure
- [x] 6 reals (`owning_phase: 3`): missing_api_key, invalid_api_key, rate_limit_exhausted, quota_exceeded, budget_exceeded, policy_violation
- [x] 1 `owning_phase: 5`: unrecoverable_stage_failure
- [x] 2 `owning_phase: 6`: gh_auth_expired, gh_permissions_insufficient
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/kiln/blockers/ test/kiln/blockers_test.exs` reports 24 tests, 0 failures
- [x] Full suite: 281 tests, 0 failures, 5 excluded (no regressions from 257 baseline)
- [x] Task commits exist: `01e3bf1`, `23f20ba`, `34c806f` (verified via `git log --oneline c8cddd4..HEAD`)
- [x] Compile-time CompileError safety net manually verified (renamed a playbook; compile failed with readable error; restored)

---
*Phase: 03-agent-adapter-sandbox-dtu-safety*
*Plan: 02*
*Completed: 2026-04-20*
*Base commit: c8cddd4*
*Head commit (after plan): 34c806f*
