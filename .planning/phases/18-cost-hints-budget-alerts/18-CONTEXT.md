# Phase 18: Cost hints & budget alerts - Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **COST-01** + **COST-02**: (1) **Advisory** cost / model-tier hints so the operator sees spend *posture* and cheaper-tier *possibilities* without Kiln implying it changed caps, the scenario oracle, or adaptive routing; (2) **Budget threshold notifications** at configured percentages of the **frozen per-run** `max_tokens_usd` cap, surfaced in **UI** and via the **existing desktop notification pipeline** where applicable, with **dedup**, **audit**, and **tests using fakes/stubs**.

Out of scope: auto-switching models for savings, billing/SaaS, cross-run ML personalization of hints, changing hard halt semantics of `BudgetGuard`, false-precision single-cent “predictions,” run-board spend columns until reporting semantics are stable.

</domain>

<decisions>
## Implementation Decisions

### Session mode

- **D-1800 — Research & selection:** Operator invoked **all four** discuss gray areas and requested **one-shot auto recommendations** after parallel subagent research (Langfuse/Helicone/AWS/GCP/Datadog/GitHub patterns + Elixir/LiveView idioms). Below locks a **single coherent** v1 that composes with **BudgetGuard**, **Notifications (D-140)**, **Phase 17 advisory copy (D-1719–D-1723)**, and **Phase 7 reconciliation (D-722)**.

### COST-01 — Placement & cadence (D-1801–D-1804)

- **D-1801 — Primary surface (v1):** **`RunDetailLive`** (or equivalent run inspector), **after each stage completes**, render a **small assign-derived panel** keyed by **`stage_run_id`** (facts: `cost_usd`, `requested_model`, `actual_model_used`, cap headroom *at stage boundary*). Treat hints as **retrospective context**, not live steering during an in-flight LLM call.
- **D-1802 — PubSub cadence:** Use existing **`run:#{run_id}`** subscription only to **refresh** that panel when a stage completes — **not** to stream speculative “you could switch now” messages during calls (avoids racing `ModelRegistry` / `BudgetGuard` truth).
- **D-1803 — Deferred surfaces:** **No** run-board “spend posture” column in v1 (false-confidence risk vs board aggregates). **No** ephemeral toasts in v1 unless a later slice adds **strict** per-stage dedupe + cooldown; default stays quiet except run detail.
- **D-1804 — Complement:** **`/costs`** (`CostLive`) remains the **rollup / learning** surface; optional **end-of-run** summary copy may reference the same disclaimer patterns — **does not replace** D-1801 as the COST-01 hint locus.

### COST-01 — Voice & guarantees (D-1805–D-1809)

- **D-1805 — Disclaimer chip (always on synthesized numbers):** Pair any indicative $ or tier text with a **fixed** chip pattern aligned to Phase 17, e.g. **“Advisory — does not change run caps”** and **“Spend follows routed model”** (ties to **D-722**: attribute USD to **`actual_model_used`**; **requested** shown muted + **“Routed”** to Audit — do not invent a second oracle).
- **D-1806 — Vocabulary:** Frame **429/5xx fallback** as **resilience / routing**, never as **“cost savings”** or **“cheaper model chosen for you.”** Avoid language that sounds like automatic downgrade or invoice/SLA claims.
- **D-1807 — Structured block (optional):** Use **suggestion + basis + risk** layout **only** where ambiguity is high (e.g. first-class template pick / pre-run), not on every rollup cell — keep default **chip + one calm sentence**.
- **D-1808 — Precision:** Follow **D-1720 / D-1721**: bands or qualitative tiers; never show bare **0 USD** from `Kiln.Pricing` without explanation; no false-precision cents as predictions.
- **D-1809 — Trust boundary:** Copy must **never** imply training on customer traffic, cross-run personalization, or that hints override **scenario runner** outcomes.

### COST-02 — Threshold configuration (D-1810–D-1814)

- **D-1810 — v1 storage:** **Application config** (e.g. `config/*.exs` / `runtime.exs`) for default **soft** threshold **percentages** (illustrative default **50% and 80%** of the run’s frozen **`max_tokens_usd`** from `runs.caps_snapshot`). **Hard halt** stays **100%** against the same snapshot — unchanged `BudgetGuard` contract.
- **D-1811 — Freeze semantics (least surprise):** **Evaluate** soft thresholds against **`caps_snapshot` + cumulative `stage_runs.cost_usd`** (same mental model as `BudgetGuard`). **Do not** change halt % mid-run; config changes affect **future** evaluations only in a documented way (prefer: thresholds read at **run enqueue** into an optional **`alerts_policy_snapshot`** field on `runs` if you need immutability; if omitted v1, document that **only notification sensitivity** may follow config reload and cap is still frozen).
- **D-1812 — Migration path:** **v1.5** — optional workflow YAML keys merged into **`caps_snapshot`** at enqueue (e.g. `budget_notify_at_pct`) with precedence **YAML > config**. **v2** — DB operator settings hydrated at enqueue into the same snapshot for UI editing without redeploy.
- **D-1813 — State for crossings:** Persist **edge detection** via **append-only audit** (see D-1818) and/or idempotent producer logic so **50% / 80%** each fire **at most once per upward crossing** per run (handle spend oscillation — do not rely on DedupCache alone).
- **D-1814 — Tests:** Threshold logic unit-testable **without** DB for pure math; integration tests with **stubbed** notification / external op paths per REQUIREMENTS.

### COST-02 — Notifications, audit & UI (D-1815–D-1822)

- **D-1815 — Desktop path:** Reuse **`Kiln.Notifications.desktop/2`** (D-140): **`ExternalOperations`** `osascript_notify`, **`DedupCache`**, **`notification_fired` / `notification_suppressed`** audit, **`Blockers.render/2`** for body copy.
- **D-1816 — Reasons vs blocks:** Add **distinct `Kiln.Blockers.Reason` atoms per band** (e.g. `:budget_threshold_50`, `:budget_threshold_80` — exact names TBD in plan) with **playbooks** that state clearly **“run continues”** and remediation is **observe / adjust future runs / caps in workflow** — **never** reuse **`:budget_exceeded`** for soft alerts.
- **D-1817 — Dedup:** Keep `{run_id, reason}` shape by using **one atom per band**; do **not** let 50% suppress 80% or vice versa. Dedup is a **UX storm guard**; **edge-triggered crossing** (D-1813) is the correctness layer.
- **D-1818 — Audit truth:** Emit **`budget_threshold_crossed`** (or equivalently named) **`Audit.Event`** with payload: `pct`, `cap_usd`, `spent_usd`, `threshold_name` — **append-only** narrative for replay/compare; complements desktop.
- **D-1819 — Hot path:** Invoke desktop notification **only on threshold cross** after audit append (O(1) per crossing), not per `BudgetGuard.check!` invocation — avoid synchronous `System.cmd` storms.
- **D-1820 — In-app path:** **`RunDetailLive`** (and optionally **`RunBoardLive`**) subscribe to **`run:#{id}`** / audit fanout to show a **non-blocking banner** or inline row when a crossing occurs — same facts as desktop, **no** second source of truth.
- **D-1821 — Guard when notifications absent:** Mirror **`BudgetGuard`’s** `maybe_notify` **ensure_loaded / ETS** checks so minimal test apps do not crash.
- **D-1822 — Telemetry:** Optional **`:telemetry.execute`** for threshold evaluation — **do not** fork a second desktop pipeline from raw telemetry handlers; if used, emit metrics and call the **same** small notifier module.

### Cross-cutting (D-1823–D-1825)

- **D-1823 — Coherence with adaptive routing:** Hints reference **registry / pricing facts at stage boundary**, not a live “switch now” claim; document that **ModelRegistry** may change between hint render and next pre-flight.
- **D-1824 — Brand:** Borders-over-shadows, calm operator voice per **`prompts/kiln-brand-book.md`**; hints are **data panels**, not modals or primary CTAs.
- **D-1825 — Verification:** LiveView tests for **panel presence / dismissal states**; unit tests for **crossing logic**; notification tests follow existing **intent + audit** patterns with **Mox / stubs** for shell-out boundaries.

### Claude's Discretion

- Exact **Reason** atom names and playbook filenames; whether **`alerts_policy_snapshot`** on `runs` ships in v1 or doc-only deferral.
- Whether soft notifications use **`Task.Supervisor`** offload after dedupe (only if profiling shows desktop latency on crossing path).
- Hint panel visual density (definition list vs one-line).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **COST-01**, **COST-02** (§ C)
- `.planning/ROADMAP.md` — Phase 18 goal and success criteria
- `.planning/PROJECT.md` — Bounded autonomy, caps, scenario oracle, brand

### Prior phase contracts

- `.planning/phases/17-template-library-onboarding-specs/17-CONTEXT.md` — **D-1719–D-1723** (advisory bands, disclaimers, pricing guardrails)
- `.planning/phases/07-core-run-ui-liveview/07-CONTEXT.md` — **D-722** (`actual_model_used`, Routed, Audit)
- `.planning/phases/08-operator-ux-intake-ops-unblock-onboarding/08-CONTEXT.md` — Typed blocks, unblock copy discipline (compose; do not conflate soft alerts with BLOCK halts)

### Implementation touchpoints

- `lib/kiln/agents/budget_guard.ex` — Cap read, spend sum, hard breach, `maybe_notify(:budget_exceeded, …)`
- `lib/kiln/notifications.ex` — Desktop pipeline, dedup, intents, audit
- `lib/kiln/blockers/reason.ex` — Valid reasons; extend with **new advisory notify reasons** per D-1816
- `lib/kiln/blockers.ex` — `render/2` playbooks for new reasons
- `lib/kiln_web/live/run_detail_live.ex` — Primary COST-01 surface (D-1801)
- `lib/kiln_web/live/cost_live.ex` — Rollup complement (D-1804)
- `lib/kiln/cost_rollups.ex` / `lib/kiln/stages/stage_run.ex` — Spend facts
- `lib/kiln/model_registry.ex` — Tier / fallback context (read-only for hints)
- `prompts/kiln-brand-book.md` — Voice and visual hierarchy

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`BudgetGuard`** — Authoritative pre-flight spend + cap math; soft thresholds should reuse **the same inputs** (`caps_snapshot`, sum of `stage_runs.cost_usd`) for consistency.
- **`Kiln.Notifications.desktop/2`** — Dedup, playbooks, `osascript_notify` intent, audit — extend with **new reasons** rather than a parallel notifier.
- **`RunDetailLive` + PubSub `run:#{id}`** — Natural refresh channel after stage completion.
- **`CostLive` (`/costs`)** — Historical rollups for operator education.

### Established patterns

- **Append-only audit** for operator-visible facts; **typed reasons** for desktop bodies.
- **Decimal** money throughout; no floats for USD comparisons.

### Integration points

- **Stage completion boundary** (where `cost_usd` is known) → hint panel + threshold evaluator.
- **`Blockers.Reason` + playbook markdown** — same registry pipeline as blockers; name new reasons so playbooks stay compile-safe.

</code_context>

<specifics>
## Specific Ideas

- Prior art synthesis: **Langfuse/Helicone** → cost as **trace dimension**, not nag frequency; **AWS/GCP budgets** → **stateful threshold crossings** with clear evaluation semantics; **IDE hints** → borrow **tone** (suggestive, non-blocking), not density.
- Default threshold ladder **50 / 80 %** is illustrative; config keys and defaults are planner-owned.

</specifics>

<deferred>
## Deferred Ideas

- Run-board **spend posture** column once aggregates are trustworthy.
- Ephemeral **toasts** with strict throttle (v1.1).
- **Telemetry-primary** desktop dispatch (anti-pattern for v1).

### Reviewed Todos (not folded)

- None — `todo.match-phase` returned no matches.

</deferred>

---

*Phase: 18-cost-hints-budget-alerts*  
*Context gathered: 2026-04-22*
