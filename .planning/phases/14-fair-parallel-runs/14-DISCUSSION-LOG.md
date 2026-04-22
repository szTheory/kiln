# Phase 14: Fair parallel runs - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `14-CONTEXT.md`.

**Date:** 2026-04-22  
**Phase:** 14 — Fair parallel runs  
**Areas discussed:** Fairness model & enforcement layer; Bottleneck hierarchy; Telemetry contract; Verification strategy  
**Mode:** User selected **all** areas; research performed via parallel subagents; lead agent synthesized one coherent recommendation set (user requested single-shot guidance).

---

## Fairness model & enforcement layer

| Option | Description | Selected |
|--------|-------------|----------|
| Strict round-robin (equal-share) | Stable tie-break; no-starvation among eligible runs at published grain | ✓ (v1) |
| Weighted fair-share | Aligns with future tiers/credits | Deferred |
| FIFO only | Simple but head-of-line risk | ✗ as sole policy |
| Split: admission + Oban | Run-level ordering + durable executor isolation | ✓ |
| RunDirector-only or Oban-only | Wrong layer for full problem | ✗ |

**User's choice:** Adopt **D-01–D-07** in `14-CONTEXT.md` (RR + stable tie-break; split enforcement; no selective receive; ORCH-06/07 override).  
**Notes:** Celery prefetch / Sidekiq priority footguns cited; k8s “schedule vs run” split used as analogy.

---

## Bottleneck / layered caps

| Option | Description | Selected |
|--------|-------------|----------|
| Single global “factory throttle” | Simple narrative | ✗ as only knob |
| Layered: DB/Oban envelope + run fairness + isolation queues | Matches real multi-service limits | ✓ |

**User's choice:** **D-08–D-10** — stability envelope + per-run stage fairness + existing queue isolation; instrument to prove bottleneck.  
**Notes:** Avoid fairness at wrong layer; avoid double-counting semaphores vs Oban vs Finch.

---

## Telemetry contract

| Option | Description | Selected |
|--------|-------------|----------|
| Blended “wait” only | Ambiguous | ✗ |
| Run dwell `queued` + separate Oban `queue_time` + DB pool | Clear semantics | ✓ |
| run_id as Prometheus label | | ✗ |

**User's choice:** **D-11–D-13** — `[:kiln, :run, :scheduling, :queued, :stop]` as primary CI signal; Oban/Ecto as secondary; naming disambiguation in docs.

---

## Verification strategy

| Option | Description | Selected |
|--------|-------------|----------|
| N-repeat stress as primary CI | Flaky / expensive | ✗ |
| Deterministic N-run + telemetry assertions | Fast, meaningful | ✓ |
| Property tests on full stack | Heavy | Deferred |

**User's choice:** **D-14–D-16** — one golden integration module, `Sandbox.allow`, no `Process.sleep`, assert dwell via `:telemetry`.

---

## Claude's Discretion

Exact module placement for scheduler vs `Transitions`; optional `:start` event vs DB-only dwell; minor `list_active` interaction with rehydration ordering.

## Deferred Ideas

See `<deferred>` in `14-CONTEXT.md` (WFQ, fairness indices, cross-node charts).
