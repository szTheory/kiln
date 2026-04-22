# Phase 18 — Technical Research

**Phase:** 18 — Cost hints & budget alerts  
**Question:** What do we need to know to PLAN this phase well?

---

## Stack & integration points

- **Spend truth:** `Kiln.Agents.BudgetGuard` already reads `runs.caps_snapshot["max_tokens_usd"]` and sums `stage_runs.cost_usd` for states `:succeeded` and `:failed` (`sum_stage_spend/1`). Soft thresholds **must** reuse the same inputs (D-1811).
- **Hard halt:** `maybe_notify(:budget_exceeded, …)` + `BlockedError` — unchanged; soft alerts need **separate** `Reason` values (D-1816).
- **Notifications:** `Kiln.Notifications.desktop/2` validates reasons via `Kiln.Blockers.Reason.valid?/1`, uses `DedupCache` key `{run_id, reason}`, two-phase `osascript_notify`, audit `notification_fired` / `notification_suppressed`.
- **Typed reasons today:** `Kiln.Blockers.Reason` exports **9** atoms; tests lock `length(Reason.all()) == 9`. `PlaybookRegistry` derives playbooks from `Reason.all/0`. `RunDetailLive` maps audit strings to atoms via `Reason.all()` — new atoms must **not** collide with block transition strings used for `:blocked` runs.
- **PubSub:** `Kiln.Runs.Transitions` broadcasts `{:run_state, run}` on `run:#{run.id}`. `Kiln.Audit` broadcasts `{:audit_event, event}` on `audit:run:#{rid}`. `RunDetailLive` currently **does not** subscribe — Phase 18 adds subscription per D-1802/D-1820.
- **Audit taxonomy:** `Kiln.Audit.EventKind` is a closed list + CHECK constraint via migration — adding `:budget_threshold_crossed` (name from CONTEXT) requires **append-only** `EventKind` entry, **new** `priv/audit_schemas/v1/budget_threshold_crossed.json`, and a migration altering the CHECK constraint (same pattern as prior phase kind additions).

---

## Design decision: extending `Blockers.Reason` vs split enum

**CONTEXT (D-1816)** requires distinct notification reasons per band, reusing `Blockers.render/2` and desktop pipeline.

**Constraint:** `Kiln.Blockers.raise_block/3` accepts any `Reason.valid?/1` atom. Soft-alert atoms must **never** be used with `raise_block`.

**Recommendation:** Extend `@reasons` with two atoms (e.g. `:budget_threshold_50`, `:budget_threshold_80` — exact names in implementation plan). Add `Reason.blocking?/1` (or equivalent) returning `false` for these; **`raise_block`** asserts `blocking?(reason)` and raises `ArgumentError` if false. Update `@type`, `defguard is_reason`, `reason_test.exs` expected list, and ship **`priv/playbooks/v1/<reason>.md`** stubs with `owning_phase: 18` frontmatter. Document in `Reason` moduledoc that the list is **notify-capable superset**, not all blocking.

---

## Hook point for threshold evaluation

- **Ideal:** Immediately after persisted `stage_runs.cost_usd` (and terminal stage state) in the **real agent completion** path (same DB transaction or next function boundary as `Audit.append` for stage completion, if any).
- **Current repo state:** `StageWorker` stub sets `:succeeded` without monetary fields — evaluator must tolerate **zero spend** (no false crossings).
- **Anthropic adapter** uses idempotency keys `run:…:llm_complete:…` — executor should locate where `StageRun` is updated with token/cost fields when that path lands, and call **`Kiln.BudgetAlerts`** (new module) from there; until then, optional **no-op** call after stub success is acceptable if tests prove idempotency.

---

## Edge detection (D-1813)

- **Do not** rely on DedupCache alone for correctness — TTL could reset while spend stays above threshold.
- **Recommended:** Append **`budget_threshold_crossed`** audit on each **upward crossing** of `spent/cap` past configured pct; evaluator reads **last fired** thresholds from audit replay (bounded query by `run_id` + `event_kind`) **or** denormalized map on `runs` (optional v1 per CONTEXT “alerts_policy_snapshot” discretion). Research prefers **audit-first** to avoid extra columns in v1.

---

## COST-01 hint content

- Pull **facts** from selected/latest `StageRun` for the inspector: `cost_usd`, `requested_model`, `actual_model_used`, `Decimal` cap minus summed spend.
- **Read-only** consult `Kiln.ModelRegistry` / `Kiln.Pricing` for tier context — no live “switch now” claims (D-1823).
- **Pricing.display** patterns from Phase 17 — avoid bare zero.

---

## Testing strategy (see VALIDATION.md)

- **Unit:** pure `BudgetAlerts` math — `Decimal.compare/2`, pct boundaries, oscillation (spend goes 49% → 51% → 49% → 51% fires twice if design says so — CONTEXT says at most once per **upward** crossing).
- **Integration:** `Notifications.desktop/2` with **Mox** or stubbed `System.cmd` boundary per existing notification tests; audit rows asserted by `event_kind`.
- **LiveView:** `Phoenix.LiveViewTest` — panel HTML contains disclaimer chip strings; banner on injected `handle_info`.

---

## Validation Architecture

| Dimension | Strategy |
|-----------|----------|
| **D1 — Correctness** | Unit tests for pct ladder + crossing idempotency; audit asserts `budget_threshold_crossed` payload shape |
| **D2 — Integration** | Tests exercise `BudgetAlerts.check_after_spend_update/1` (name TBD) with Sandbox / Repo |
| **D3 — Regression** | `mix test` scoped files + `mix compile --warnings-as-errors`; extend `reason_test` for new atoms |
| **D4 — Security** | No user-controlled strings into shell — reuse `inspect/1` wrapping in Notifications; playbook tokens allow-listed |
| **D5 — UX** | LiveView tests for chips + `aria-live` region |
| **D6 — Performance** | Threshold path O(1) queries — index `audit_events(run_id, event_kind)` if replay becomes hot (defer unless profiler says) |
| **D7 — Ops** | Config thresholds in `config/*.exs` — document keys |
| **D8 — Observability** | Optional `:telemetry` event on evaluation (D-1822) — **not** wired to desktop |

---

## RESEARCH COMPLETE
