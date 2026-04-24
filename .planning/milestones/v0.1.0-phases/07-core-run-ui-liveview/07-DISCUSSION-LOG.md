# Phase 7: Core Run UI (LiveView) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `07-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-21
**Phase:** 07 — Core Run UI (LiveView)
**Areas discussed:** Routes & home, Run detail deep linking, Diff viewer defaults, Workflow snapshot history, Cost dashboard landing & trust, Real-time run board affordance
**Mode:** User selected **all** areas and requested parallel **research subagents** + one-shot cohesive recommendations (no interactive per-question turns).

---

## Routes & information architecture

| Option | Description | Selected |
|--------|-------------|----------|
| A | All factory UI under `/ops/*` | |
| B | Product at root (`/`, `/runs`, …); `/ops` = LiveDashboard + Oban only | ✓ |
| C | Namespace `/factory/...` | |
| D | Hybrid (e.g. runs at root, other screens under `/ops`) | |

**User's choice:** Option B (research consensus + Kiln vision alignment).
**Notes:** Compared Sidekiq/Grafana (adjacent introspection) vs Argo CD/GitHub Actions (resource-centric URLs). Avoid `/ops` semantic overload with Postgres-backed “factory floor.”

---

## Run detail deep linking

| Option | Description | Selected |
|--------|-------------|----------|
| Path nested | `/runs/:id/stages/:stage_id` | |
| Query-driven | `/runs/:id?stage=&pane=` | ✓ |
| Fragment-only | `#stage` as SSOT | ✗ (footgun: server never sees hash) |
| Assign-only | No URL update | ✗ |

**User's choice:** Query-driven canonical URL + `handle_params` + `push_patch`.
**Notes:** Hybrid path+query noted as Phase 7+ upgrade if audit exports want hierarchy.

---

## Diff viewer defaults

| Option | Description | Selected |
|--------|-------------|----------|
| Default unified | Inline first; split toggle | ✓ |
| Default split | Side-by-side first | |
| Wrap-first | `pre-wrap` default | ✗ |

**User's choice:** Unified + pretty first; raw + optional wrap as toggles; horizontal scroll default; localStorage + optional URL mirror.
**Notes:** GitHub/GitLab bias; security review favors non-wrapping raw; huge-line DOM caps mandatory.

---

## Workflow snapshot history

| Option | Description | Selected |
|--------|-------------|----------|
| Hash-only list | Checksums without bodies | |
| Postgres immutable snapshots | INSERT per successful load + checksum + yaml version | ✓ |
| Filesystem read-through | mtime / path only | ✗ |

**User's choice:** Snapshots table (or equivalent) + UI label **“Snapshots”**; align with `CompiledGraph` checksum + YAML `version` already on `Run`.

---

## Cost dashboard landing

| Option | Description | Selected |
|--------|-------------|----------|
| Entity-first only | Skip time strip | |
| Time-first strip + tabs | Today/week actuals + pivot tabs | ✓ |
| Blend projection into actuals | Single headline number | ✗ |

**User's choice:** Time-first summary; **Run** as default pivot tab; projection separated with basis microcopy; `actual_model_used` billing column; reconciliation footer.

---

## Real-time run board affordance

| Option | Description | Selected |
|--------|-------------|----------|
| Silent + neutral per-card highlight | Streams + Char/Iron/Ash ~250ms cue, reduced-motion safe | ✓ |
| Toasts / column Ember pulse | High salience | ✗ |

**User's choice:** Linear-quiet baseline + **neutral** per-card border/background pulse; **no Ember** for refresh; debounce anti-strobe.

---

## Claude's Discretion

- Numeric tuning (debounce, projection N, retention).
- Diff engine layout implementation.
- Optional `/runs` ↔ `/` alias behavior.

## Deferred Ideas

- Phase 8 global chrome and cost **intel** vs core **costs** route split.
- Nested stage path URLs if audit/marketing demands.
