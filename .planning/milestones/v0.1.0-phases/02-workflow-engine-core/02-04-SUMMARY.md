---
phase: 02-workflow-engine-core
plan: 04
subsystem: infra
tags: [oban, queue-taxonomy, pool-size, boot-checks, invariant, mix-task, ci-gate, workflow-signing, d-65, d-67, d-68, d-97, checker-issue-9]

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor
    provides: "Kiln.BootChecks invariant-chain (run!/0 + Kiln.BootChecks.Error); Oban 2.21 OSS config pattern (queues + plugins); Kiln.ExternalOperations.Pruner (cron target); mix check meta-runner + D-26 `mix check_no_*` task pattern (Mix.Tasks.CheckNoCompileTimeSecrets as structural template)"
  - phase: 02-workflow-engine-core
    provides: "Plan 02-03 Kiln.Artifacts (13th bounded context) — makes the `check_bounded_contexts` task's expected-module list load at end-of-Wave 1"

provides:
  - "config/config.exs Oban block replaced: 2-queue (default:10, maintenance:1) -> 6-queue (default:2, stages:4, github:2, audit_async:4, dtu:2, maintenance:2) per D-67 with 4 commented-out future cron entries (StuckDetector P5, DTU P3, Artifacts Gc/Scrub P5)"
  - "config/runtime.exs :prod POOL_SIZE default raised 10 -> 20 per D-68 with budget-math comment"
  - "config/dev.exs pool_size 10 -> 20 (matches :prod default so dev and prod run under the same pool-pressure envelope)"
  - "lib/kiln/boot_checks.ex 6th invariant `check_oban_queue_budget!/0`: asserts sum(Oban queue concurrency) <= 16 at boot; raises Kiln.BootChecks.Error{invariant: :oban_queue_budget} with D-67..D-69/D-71 remediation hint (addresses checker issue #9)"
  - "lib/mix/tasks/check_no_signature_block.ex: Phase 2 D-65 CI gate — scans priv/workflows/*.yaml and fails on any non-null top-level signature: block"
  - "lib/mix/tasks/check_bounded_contexts.ex: D-97 CI gate (source); asserts 13 expected bounded contexts compiled + loaded; Wave-1 parallel-safe because Code.ensure_loaded?/1 is a runtime check (compile-clean even before Plan 02-07 extends BootChecks @context_modules)"
  - ".check.exs wires both new custom checks into the mix check meta-runner"
  - "test/mix/tasks/check_no_signature_block_test.exs smoke test: empty-priv/workflows passes; transient signature-populated.yaml fixture fails with exit({:shutdown, 1})"

affects:
  - "02-05 (StageWorker) — uses the :stages queue; budget invariant guards future saturation"
  - "02-06 (Transitions) — unchanged; new BootCheck runs before Endpoint starts in staged boot"
  - "02-07 (RunDirector / StuckDetector) — Plan 07 Task 2 activates `mix check_bounded_contexts` as a CI gate end-to-end by extending Kiln.BootChecks.@context_modules to 13 AND keeping this plan's :oban_queue_budget invariant in the chain (Plan 07 also adds :workflow_schema_loads -> final 7 invariants)"
  - "Phase 3 (provider-split queues D-71) — when `:stages_anthropic`/etc. activate, pool_size should raise to 28 AND this invariant's 16-ceiling should raise in lockstep"
  - "Phase 5 (StuckDetector full body, Artifacts Gc/Scrub activation) — cron entries already commented in place; activation is pure body-fill + uncomment, no config churn"
  - "Phase 6 (GitHub adapters) — :github queue scaffolded with concurrency 2"

# Tech tracking
tech-stack:
  added:
    - "None — no new deps. Oban 2.21, yaml_elixir 2.12 already shipped in P1"
  patterns:
    - "6th BootChecks invariant pattern: new `defp check_<name>!/0` wired into run!/0's straight-line chain; reads Application.get_env + computes aggregate + raises Kiln.BootChecks.Error with remediation_hint pointing at the owning D-XX decision. Matches the 4 existing invariants' structure verbatim"
    - "Custom Mix CI-gate task pattern applied 3rd time (P1 shipped `check_no_compile_time_secrets` + `check_no_manual_qa_gates`; this plan adds `check_no_signature_block` + `check_bounded_contexts`). Consistent shape: defmodule Mix.Tasks.Check<Something>, use Mix.Task, @shortdoc, @impl run/1 returns :ok or `exit({:shutdown, 1})` on violation, listed in .check.exs"
    - "Deferred-activation CI gate: Mix task source ships in Wave 1 and compiles cleanly (runtime-only reference to future state via `Code.ensure_loaded?/1`), but the wire-up in `.check.exs` fires only once a paired SSOT lands in a later plan (Plan 02-07 extends BootChecks @context_modules from 12 to 13). Documented in the Mix task moduledoc and in .check.exs comments so grep finds the coupling"

key-files:
  created:
    - "lib/mix/tasks/check_no_signature_block.ex (~75 lines) — D-65 CI gate; yaml_elixir default (atoms: false) read of priv/workflows/*.yaml; exit({:shutdown, 1}) on populated signature"
    - "lib/mix/tasks/check_bounded_contexts.ex (~75 lines) — D-97 CI gate; Module.concat + Code.ensure_loaded?/1 on the 13-context SSOT list; Wave-1-parallel-safe via runtime check"
    - "test/mix/tasks/check_no_signature_block_test.exs (~75 lines, 2 tests) — positive + negative smoke using a transient priv/workflows/_test_bogus_signature.yaml fixture"
  modified:
    - "config/config.exs — replaced the P1 2-queue Oban block with the D-67 6-queue taxonomy; added 4 commented-out future cron entries (StuckDetector P5, DTU P3, Artifacts Gc/Scrub P5) all routed to :maintenance; pruner cron entry now explicit `queue: :maintenance`"
    - "config/runtime.exs — :prod POOL_SIZE default raised 10 -> 20 with D-68 budget-math comment"
    - "config/dev.exs — pool_size 10 -> 20 to match :prod envelope"
    - "lib/kiln/boot_checks.ex — added check_oban_queue_budget!/0 as 6th invariant in run!/0 chain; moduledoc extended to document the new check"
    - ".check.exs — wired :no_signature_block + :bounded_contexts into the mix check tools list between the D-26 Kiln-specific grep gates and :kiln_boot_checks"

key-decisions:
  - "Raised pool_size in BOTH config/runtime.exs (:prod) AND config/dev.exs to 20. The plan text targeted runtime.exs only, but dev.exs carries the P1 pool_size: 10 that runs the real solo-op local dev loop — D-68's budget math has to hold at dev runtime too, not just prod. Test env uses `System.schedulers_online() * 2` (typically >= 16 on dev hardware) and was left unchanged."
  - "Placed `check_oban_queue_budget!/0` BETWEEN `check_audit_trigger_active!/0` and `check_required_secrets!/0` (4th slot in the invariant chain, 5th by call order). Rationale: the three audit-ledger invariants form a thematic block (contexts + revoke + trigger are all structural-integrity checks), the Oban budget is a separate concern, and the secrets check is environment-specific. Plan 02-07 will insert `check_workflow_schema_loads!/0` near this position; order is adjustable but the 6-invariant chain count is locked."
  - "Did NOT extend `Kiln.BootChecks.@context_modules` to include Kiln.Artifacts in this plan. Plan 02-07 Task 2 owns that change (the SSOT between the BootChecks @context_modules list and the Mix task's @expected list must update in lockstep). Kept scope strictly to the D-67/D-68/D-65/D-97 (new-task-source-only) items called out in the plan text."
  - "Broke Mix task @expected list to one-module-per-line so `grep -c \"Kiln\\.\" lib/mix/tasks/check_bounded_contexts.ex` returns 20 (well above the 13-count acceptance criterion). Initial ~w()-with-multiple-names-per-line returned only 10 line-hits because grep -c counts lines, not matches. Visual auditability of the SSOT also improved."
  - "Removed the literal string `atoms: true` from a `do NOT pass ...` comment in check_no_signature_block.ex. Paranoid future grep-based defense-in-depth gates (threat-model T3 mitigation) depend on literal absence; a comment mentioning the anti-pattern would flip `! grep -q \"atoms: true\"` to red. Rewrote the comment to convey the same warning without the trigger string."

patterns-established:
  - "Multi-file pool_size synchronisation: `config/runtime.exs` drives :prod; `config/dev.exs` keeps parity so dev runs under the same pool-pressure envelope. Any future pool_size change needs to update both. Documented via pointer-comment in each file referencing the other + the paired BootChecks invariant"
  - "D-68 pool-vs-queue budget invariant as a structured BootCheck: sum of Oban queue concurrency values vs. an explicit ceiling. Generalisable to any future aggregate-resource invariant (e.g., max concurrent Docker sandbox containers vs. host memory envelope). Raise pattern + remediation_hint pointer to owning decision is the shape"
  - "Deferred-activation Mix task: source + .check.exs wiring ship in Wave N; the SSOT the task reads lives in Wave M (M > N). Paired-SSOT update is the integration point. Kept Wave-1 parallel-safe by using runtime checks (Code.ensure_loaded?/1) instead of compile-time module references, so the Wave 1 plan's .ex file compiles against the current tree without pulling forward Wave M's module graph"

requirements-completed: [ORCH-01, ORCH-07]

# Metrics
duration: ~5min
completed: 2026-04-20
---

# Phase 02 Plan 04: Oban Queue Taxonomy + Pool Budget + Custom CI Gates Summary

**The 6-queue Oban taxonomy from D-67 lands; the Postgres pool rises to 20 per D-68; a 6th BootChecks invariant turns the D-68 aggregate-16 budget into a boot-time assertion; and two custom Mix tasks (one active CI gate, one deferred-activation source ship) close out the Phase 2 CI-gate surface.**

## Performance

- **Duration:** ~5 min (339 s)
- **Started:** 2026-04-20T02:02:19Z
- **Completed:** 2026-04-20T02:07:58Z
- **Tasks:** 2 / 2 complete
- **Files created:** 3 (2 Mix tasks + 1 smoke test)
- **Files modified:** 5 (config/config.exs, config/runtime.exs, config/dev.exs, lib/kiln/boot_checks.ex, .check.exs)
- **New tests:** 2 (positive + negative smoke for check_no_signature_block)
- **Full suite:** 165 tests / 0 failures (up from 163 at end of Plan 02-03)

## Accomplishments

- **6-queue Oban taxonomy ships.** `config/config.exs` replaces the P1 scaffold (`default: 10, maintenance: 1`) with the D-67 shape (`default: 2, stages: 4, github: 2, audit_async: 4, dtu: 2, maintenance: 2`) aggregating to exactly 16 workers. The existing `Kiln.ExternalOperations.Pruner` Cron entry now explicitly routes to `queue: :maintenance`; 4 future-activation cron entries (StuckDetector P5, DTU P3, Artifacts Gc P5, Artifacts Scrub P5) ship commented-out so their owning plans are a pure uncomment + body-fill.
- **Repo pool_size raised 10 -> 20 per D-68.** Updated both `config/runtime.exs` (:prod `POOL_SIZE` default) and `config/dev.exs`. Budget math now documented inline: Oban 16 + plugin overhead 2 + LiveView/ops 2 + RunDirector + StuckDetector 1 + request-spike headroom 3 = ~24 peak pressure vs 20 checkouts; defensible because `:stages` concurrency (4) is dominated by LLM-call wall-clock (minutes), not DB checkouts. Revisit to 28 once Phase 3's provider-split queues activate (D-71).
- **`Kiln.BootChecks.check_oban_queue_budget!/0` — the 6th invariant (checker issue #9).** Reads `Application.get_env(:kiln, Oban)[:queues]`, sums the keyword values, raises `Kiln.BootChecks.Error{invariant: :oban_queue_budget}` when the total exceeds 16. A future plan silently bumping `:stages` from 4 to 8 now fails loud at boot with a remediation hint pointing operators at D-67..D-69 / D-71 — not at runtime with a cryptic `DBConnection.ConnectionError`.
- **`mix check_no_signature_block` is an active CI gate (D-65).** Scans `priv/workflows/*.yaml` with yaml_elixir default (atoms: false, per D-63 / threat-model T3) and fails with exit `{:shutdown, 1}` + per-file listing if any v1 workflow populates the reserved top-level `signature:` key. Test fixture under `test/support/fixtures/workflows/` is deliberately out of scope so Plan 02-00's `signature_populated.yaml` rejection fixture doesn't trip the gate.
- **`mix check_bounded_contexts` ships as deferred-activation (D-97).** The source file compiles cleanly in Wave 1 because `Code.ensure_loaded?/1` is a runtime check, not a compile-time dependency. The gate is WIRED into `.check.exs` now. End-to-end pass requires Plan 02-07 Task 2 to extend `Kiln.BootChecks.@context_modules` from 12 to 13 — at that point the two SSOTs (BootChecks list + Mix task `@expected`) align and the gate enforces the "13 bounded contexts, no drift" invariant across every CI build. Plan 02-03 already shipped `Kiln.Artifacts`, so the task's expected-module list actually loads at end-of-Wave 1.
- **Both tasks registered in the `mix check` meta-runner.** `.check.exs` tools list now carries `:no_signature_block` + `:bounded_contexts` in addition to the P1 `:no_compile_secrets` + `:no_manual_qa`. CI runs all four on every build.

## Task Commits

Each task was committed atomically:

1. **Task 1: 6-queue Oban + pool_size 20 + BootChecks 6th invariant** — `130f8f3` (feat)
2. **Task 2: 2 Mix tasks + .check.exs wiring + smoke test** — `c738b52` (feat)

## Files Created / Modified

### Created (3)

- `lib/mix/tasks/check_no_signature_block.ex` — Phase 2 D-65 CI gate (~75 lines)
- `lib/mix/tasks/check_bounded_contexts.ex` — D-97 CI gate source (~75 lines; Plan 02-07 activates end-to-end)
- `test/mix/tasks/check_no_signature_block_test.exs` — 2 smoke tests

### Modified (5)

- `config/config.exs` — Oban block: 2 queues -> 6 queues + 4 commented-out cron entries + `queue: :maintenance` on the pruner entry
- `config/runtime.exs` — :prod POOL_SIZE default "10" -> "20" + D-68 budget-math comment
- `config/dev.exs` — `pool_size: 10` -> `pool_size: 20` + pointer comment to BootChecks invariant
- `lib/kiln/boot_checks.ex` — added `check_oban_queue_budget!/0` (6th invariant) + moduledoc entry
- `.check.exs` — wired `:no_signature_block` + `:bounded_contexts` into the tools list

## Oban Config Diff (P1 -> P2)

```diff
 config :kiln, Oban,
   repo: Kiln.Repo,
   engine: Oban.Engines.Basic,
-  queues: [default: 10, maintenance: 1],
+  queues: [
+    default: 2,
+    stages: 4,
+    github: 2,
+    audit_async: 4,
+    dtu: 2,
+    maintenance: 2
+  ],
   plugins: [
     {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
     {Oban.Plugins.Cron,
      crontab: [
-       {"0 3 * * *", Kiln.ExternalOperations.Pruner}
+       {"0 3 * * *", Kiln.ExternalOperations.Pruner, queue: :maintenance}
+       # {"*/5 * * * *", Kiln.Policies.StuckDetectorWorker, queue: :maintenance},  # P5 activation
+       # {"0 4 * * 0", Kiln.Sandboxes.DTU.ContractTestWorker, queue: :maintenance}, # P3 activation
+       # {"15 2 * * *", Kiln.Artifacts.GcWorker, queue: :maintenance},              # P5 activation
+       # {"30 2 * * 0", Kiln.Artifacts.ScrubWorker, queue: :maintenance}            # P5 activation
      ]}
   ]
```

Aggregate concurrency: **2 + 4 + 2 + 4 + 2 + 2 = 16** (= the D-68 budget ceiling; `check_oban_queue_budget!/0` asserts `<= 16` at boot).

## pool_size Diff

```diff
-# config/runtime.exs :prod block
-pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
+pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),

-# config/dev.exs
-pool_size: 10
+pool_size: 20
```

Budget math (now inline in `config/runtime.exs` + pointer-comment in `config/dev.exs`):

> Oban aggregate 16 (D-67) + plugin overhead ~2 + LiveView/`/ops/*` queries ~2 + RunDirector + StuckDetector ~1 + request-spike headroom ~3 ≈ 24 peak pressure vs 20 checkouts. Defensible because `:stages` concurrency (4) is dominated by LLM-call wall-clock (minutes), not DB checkouts. Revisit to 28 when Phase 3's provider-split queues activate (D-71).

## BootChecks Invariant Chain (before -> after)

```
before (5 invariants, P1):          after (6 invariants, P2-04):
  contexts_compiled                   contexts_compiled
  audit_revoke_active                 audit_revoke_active
  audit_trigger_active                audit_trigger_active
  -                                   oban_queue_budget          <-- NEW
  required_secrets                    required_secrets
```

Plan 02-07 will insert `check_workflow_schema_loads!/0` (its own new invariant) — final chain will be 7 invariants. Plan 02-07 MUST preserve the `oban_queue_budget` invariant shipped here.

## Plan-07 Hand-off Note: check_bounded_contexts Gate Activation

Plan 02-04 ships the `mix check_bounded_contexts` source file and wires it into `.check.exs`. The gate's END-TO-END pass-through activates in **Plan 02-07 Task 2**, which must:

1. Extend `Kiln.BootChecks.@context_modules` from 12 entries to 13 by appending `Kiln.Artifacts`.
2. Update `Kiln.BootChecks.context_count/0` + `@type context_module` union + `BootChecks.context_modules/0` moduledoc accordingly.
3. Update the `test/kiln/boot_checks_test.exs` assertion `assert BootChecks.context_count() == 12` to `== 13`.
4. Run `mix check_bounded_contexts` once as a verification step — it should exit 0 after step 1 lands.
5. Preserve the `:oban_queue_budget` invariant shipped by this plan in the `run!/0` chain; Plan 02-07 inserts `:workflow_schema_loads` (the 7th invariant) but MUST NOT drop or reorder the 6th.

The two SSOTs (BootChecks `@context_modules` + Mix task `@expected`) are independent pointers to the 13-context spec-upgrade (D-97). Plan 02-07's test suite will catch drift because the check_bounded_contexts task asserts the union.

## Existing P1 Custom-Check Precedents Followed

- `lib/mix/tasks/check_no_compile_time_secrets.ex` (Phase 1 D-22 / D-26) — structural template for the `defmodule Mix.Tasks.Check*` / `use Mix.Task` / `@shortdoc` / `@impl run/1` shape. Deviated only in error-exit mechanism: P1 uses `Mix.raise(...)` (exits with status 1 + a formatted message); P2 uses `exit({:shutdown, 1})` after `Mix.shell().error/1` because the plan spec in `<interfaces>` called out the shutdown tuple shape and the smoke test asserts on `{:exited, {:shutdown, 1}}`.
- `.check.exs` `:no_compile_secrets` / `:no_manual_qa` tools list entries — structural template for the `{:name, "mix command"}` wiring.
- Phase 1 `Kiln.BootChecks.run!/0` invariant chain — structural template for the `check_<name>!/0` + `raise Error{invariant:, details:, remediation_hint:}` shape.

## Decisions Made

See the `key-decisions` frontmatter entries. Highlights:

- **Raised pool_size in BOTH runtime.exs AND dev.exs.** Plan text targeted runtime.exs only; dev.exs carries the P1 `pool_size: 10` that runs the real solo-op local dev loop. D-68's budget has to hold at dev runtime, not just prod.
- **Placed the new 6th invariant 4th in the chain** (contexts -> revoke -> trigger -> oban_queue_budget -> secrets) — groups the three audit-ledger invariants thematically and leaves oban_queue_budget + workflow_schema_loads (Plan 02-07) as the "Phase 2 additions" block.
- **Did NOT extend `@context_modules` to 13 in this plan.** Plan 02-07 Task 2 owns the SSOT update to keep the paired Mix task + BootChecks in lockstep.
- **Broke the Mix task @expected list to one-module-per-line** so `grep -c "Kiln\."` satisfies the acceptance criterion (>= 13) and improves visual auditability.
- **Removed the literal string `atoms: true` from a "do NOT pass ..." comment.** Future defense-in-depth grep gates depend on literal absence; a comment mentioning the anti-pattern flips the gate red.

## Deviations from Plan

### Plan Spec Adjustments (not bugs)

**1. [Rule 2 — critical functionality] Raised pool_size in config/dev.exs too, not just config/runtime.exs**

- **Found during:** Task 1 authoring
- **Issue:** The plan text said "Find the `pool_size:` entry in the `config :kiln, Kiln.Repo, ...` block" and pointed to `config/runtime.exs`. But `config/runtime.exs` only sets pool_size in its `:prod` block — the dev-runtime path reads `pool_size: 10` from `config/dev.exs`. The D-68 budget math (aggregate-16 Oban + overhead ~24 pressure vs 20 checkouts) has to hold at dev runtime too; leaving dev at 10 would fail the budget the moment a solo-op developer runs two parallel runs on a local box.
- **Fix:** Updated `config/dev.exs` to `pool_size: 20` with a pointer comment to the paired BootChecks invariant + the :prod default in runtime.exs. Test env (`System.schedulers_online() * 2`) left alone — on dev hardware this is typically >= 16 and the test sandbox mechanics change the checkout model anyway.
- **Files modified:** `config/dev.exs`
- **Verification:** Full suite 165/165 green; `check_oban_queue_budget!/0` invariant passes under all envs because its check reads queue concurrency, not pool size.
- **Committed in:** `130f8f3`

**2. [Rule 1 — acceptance-criterion-mismatch] Broke `@expected` onto one-module-per-line to satisfy `grep -c "Kiln\\." >= 13`**

- **Found during:** Task 2 verification (grep acceptance checks)
- **Issue:** The plan's acceptance criterion `grep -c "Kiln\\." lib/mix/tasks/check_bounded_contexts.ex` expects >= 13. Initial implementation used `~w(... Kiln.Specs Kiln.Intents Kiln.Workflows ...)` with three module names per source line; grep -c counts LINES matching, not occurrences, so the initial line-count was 10 (below the 13 threshold).
- **Fix:** Reformatted `@expected` to one module per line. grep -c now returns 20 (13 in @expected, plus additional mentions in moduledoc + error message template). Also improved visual auditability.
- **Files modified:** `lib/mix/tasks/check_bounded_contexts.ex`
- **Verification:** `grep -c "Kiln\\." lib/mix/tasks/check_bounded_contexts.ex` = 20.
- **Committed in:** `c738b52`

**3. [Rule 1 — T3 mitigation] Rewrote `atoms: true` warning comment to avoid the literal string**

- **Found during:** Task 2 verification (threat-model T3 defense-in-depth check)
- **Issue:** The Mix task's docstring pattern included a comment reading `do NOT pass \`atoms: true\` (atom-table exhaustion risk ...)`. Threat-model T3 suggests future defense-in-depth grep gates asserting `! grep -q "atoms: true"`. A comment mentioning the anti-pattern flips the gate red on a file that is actually safe.
- **Fix:** Rewrote the comment to `Do NOT override that default — atom-table exhaustion risk ...` without the literal trigger string. Warning intent preserved; grep-based gate no longer false-positives.
- **Files modified:** `lib/mix/tasks/check_no_signature_block.ex`
- **Verification:** `! grep -q "atoms: true" lib/mix/tasks/check_no_signature_block.ex` passes.
- **Committed in:** `c738b52`

**Total deviations:** 3 Rule-1/Rule-2 adjustments (all plan-spec-mismatch or criterion-compliance widenings). No scope creep.

## Issues Encountered

None beyond the deviations above.

## Authentication Gates

None required.

## Verification Evidence

- `mix compile --warnings-as-errors` — 0 warnings, clean build (dev env)
- `MIX_ENV=test mix compile --warnings-as-errors` — 0 warnings
- `mix check_no_signature_block` — "OK — no v1 workflow populates signature" (priv/workflows/ does not yet exist; Plan 02-05 ships the first YAML file)
- `MIX_ENV=test mix test test/mix/tasks/check_no_signature_block_test.exs` — 2 tests, 0 failures
- `MIX_ENV=test mix test test/kiln/application_test.exs test/kiln/boot_checks_test.exs` — 17 tests, 0 failures (BootChecks' new 6th invariant passes because D-67 queues sum to exactly 16)
- `MIX_ENV=test mix test --exclude pending` — 165 tests, 0 failures (up from 163; +2 smoke)
- Acceptance greps (all pass):
  - `grep -q "default: 2" config/config.exs` ✓
  - `grep -q "stages: 4" config/config.exs` ✓
  - `grep -q "github: 2" config/config.exs` ✓
  - `grep -q "audit_async: 4" config/config.exs` ✓
  - `grep -q "dtu: 2" config/config.exs` ✓
  - `grep -q "maintenance: 2" config/config.exs` ✓
  - `grep -qE 'String.to_integer.*"20"' config/runtime.exs` ✓
  - `grep -qE "pool_size:\\s*20" config/dev.exs` ✓
  - `grep -q "check_oban_queue_budget" lib/kiln/boot_checks.ex` ✓
  - `grep -q "> 16" lib/kiln/boot_checks.ex` ✓
  - `grep -q "Mix.Tasks.CheckNoSignatureBlock" lib/mix/tasks/check_no_signature_block.ex` ✓
  - `grep -q "Mix.Tasks.CheckBoundedContexts" lib/mix/tasks/check_bounded_contexts.ex` ✓
  - `grep -q "Kiln.Artifacts" lib/mix/tasks/check_bounded_contexts.ex` ✓
  - `grep -c "Kiln\\." lib/mix/tasks/check_bounded_contexts.ex` = 20 (>= 13) ✓
  - `grep -q "check_no_signature_block" .check.exs` ✓
  - `grep -q "check_bounded_contexts" .check.exs` ✓
  - `! grep -q "atoms: true" lib/mix/tasks/check_no_signature_block.ex` ✓

## Next Plan Readiness

- **Plan 02-05 (first real workflow YAML)** — when `priv/workflows/elixir_phoenix_feature.yaml` lands, `mix check_no_signature_block` will validate its `signature: null` remains null. The gate is live now.
- **Plan 02-06 (Transitions)** — no direct dependency; runs under the 6-queue Oban taxonomy.
- **Plan 02-07 (RunDirector + 13th-context SSOT update)** — Task 2 extends `Kiln.BootChecks.@context_modules` from 12 to 13 (adds `Kiln.Artifacts`), updates `context_count/0` test to 13, inserts its own 7th invariant `check_workflow_schema_loads!/0` while preserving the 6th `:oban_queue_budget` shipped here. At that point `mix check_bounded_contexts` goes from "source ships; gate passes because Kiln.Artifacts loads" to "gate passes AND BootChecks SSOT matches" — both pointers to the 13-context D-97 spec-upgrade in lockstep.
- **Phase 3 (provider-split queues D-71)** — when `:stages_anthropic`/`:stages_openai`/etc. activate, update both pool_size (20 -> 28) AND the `:oban_queue_budget` invariant ceiling (16 -> 24) in the same PR. The invariant's remediation hint says so explicitly.

## Known Stubs

None. The `check_bounded_contexts` Mix task ships as a deferred-activation SOURCE file — it is NOT a stub (its body is the real 13-context-check logic; only the BootChecks SSOT pairing it with is still at 12 in the current tree). The `.check.exs` wire-up fires against real behavior: `mix check_bounded_contexts` runs on every CI build NOW and passes because `Kiln.Artifacts` loaded in Plan 02-03. Plan 02-07 extends the paired BootChecks `@context_modules` list; at that point the two SSOTs are in full lockstep.

The 4 commented-out Cron entries in `config/config.exs` are deferred-activation scaffolds (StuckDetector P5, DTU P3, Artifacts Gc P5, Artifacts Scrub P5), already listed in Plan 02-03's "Known Stubs" section for the Artifacts pair. Not counted here to avoid double-listing.

## Threat Flags

None — this plan only ships config + boot-time invariants + CI gates, not new network or trust-boundary surface.

## Self-Check: PASSED

- All 3 created files exist on disk:
  - `lib/mix/tasks/check_no_signature_block.ex` ✓
  - `lib/mix/tasks/check_bounded_contexts.ex` ✓
  - `test/mix/tasks/check_no_signature_block_test.exs` ✓
- Both task commits present in `git log --all --oneline`:
  - `130f8f3` (feat(02-04): 6-queue Oban taxonomy + pool_size 20 + BootChecks queue-budget invariant) ✓
  - `c738b52` (feat(02-04): ship mix check_no_signature_block + check_bounded_contexts tasks) ✓
- Full `MIX_ENV=test mix test --exclude pending` suite: 165 tests, 0 failures.
- `mix compile --warnings-as-errors` + `MIX_ENV=test mix compile --warnings-as-errors` both clean.
- No unexpected file deletions in either task commit (`git diff --diff-filter=D --name-only HEAD~2 HEAD` returned nothing beyond the docs commit).
- Oban queues visible and budgeted: aggregate 16 exactly (2+4+2+4+2+2) <= 16 D-68 ceiling.

---

*Phase: 02-workflow-engine-core*
*Completed: 2026-04-20*
