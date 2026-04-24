# Phase 18: Cost hints & budget alerts - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `18-CONTEXT.md`.

**Date:** 2026-04-22  
**Phase:** 18 — Cost hints & budget alerts  
**Mode:** `[--all]` gray areas + operator-requested **one-shot auto recommendations** after parallel research subagents.

**Areas covered:** COST-01 placement & cadence; COST-01 voice & guarantees; COST-02 thresholds & config; COST-02 notifications & dedup.

---

## COST-01 — Placement & cadence

| Option | Description | Selected |
|--------|-------------|----------|
| A — Run detail, post-stage inline note | Assign-derived, keyed by `stage_run_id`; retrospective facts | ✓ |
| B — Ephemeral toast after stage | PubSub + flash; higher noise |  |
| C — Run board column | At-a-glance but false-confidence risk |  |
| D — `/costs` + digest only | Learning surface; low immediacy for hints | (complement only) |

**User's choice:** Auto — **A** primary; **D** complement; **B/C** deferred.  
**Notes:** Subagent synthesis + idiomatic LiveView (assign-driven, stage-boundary refresh). Avoid hints during in-flight LLM to prevent racing `BudgetGuard` / `ModelRegistry`.

---

## COST-01 — Voice & guarantees

| Option | Description | Selected |
|--------|-------------|----------|
| A — Fixed disclaimer chip | “Advisory — does not change run caps”; spend follows routed model | ✓ (primary) |
| B — Structured suggestion + basis + risk | More space; use sparingly | (secondary, high-ambiguity surfaces) |
| C — Tie to Phase 17 manifest fields + D-722 lane | Single vocabulary | ✓ (paired with A) |
| D — Log-only “why” | Defer as depth layer |  |

**User's choice:** Auto — **A + C** default; **B** optional; **D** later.  
**Notes:** Never frame adaptive fallback as cost optimization; no training/personalization implications; guard `Kiln.Pricing` zero/low-signal outputs.

---

## COST-02 — Thresholds & configuration

| Option | Description | Selected |
|--------|-------------|----------|
| A — `Application` config defaults | Deploy-tunable; no migration | ✓ v1 |
| B — DB `operator_settings` | UI-editable; heavier | Defer v2 |
| C — Workflow YAML only | Frozen per run; author burden | v1.5 migration |
| D — Hybrid defaults + YAML override | Long-term | After v1 |

**User's choice:** Auto — **A** for v1 defaults (e.g. 50/80%); **halt** remains 100% `caps_snapshot`; **D** as documented migration path.

---

## COST-02 — Notifications & dedup

| Option | Description | Selected |
|--------|-------------|----------|
| A — Extend `Notifications.desktop/2` + new `Reason` + playbooks | Parity with D-140 hard blocks | ✓ |
| B — PubSub in-app only | No desktop parity | (complement) |
| C — Audit-only | Durable but no ping | ✓ (pair with A) |
| D — Telemetry → desktop | Fork/spam risk | ✗ |

**User's choice:** Auto — **A + C + B (complement)**; distinct **Reason** per band so `{run_id, reason}` dedup does not collapse 50% vs 80%; **edge-triggered** crossing + audit before desktop; never reuse `:budget_exceeded` for soft alerts.

---

## Claude's Discretion

Exact Reason atom names; optional `alerts_policy_snapshot` on `runs` in v1 vs doc deferral; optional `Task.Supervisor` for notify offload if profiled.

## Deferred Ideas

- Run-board spend column; toast-first UX; telemetry-driven desktop as primary path.
