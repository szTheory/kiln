# Phase 19: Post-mortems & soft feedback - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `19-CONTEXT.md`.

**Date:** 2026-04-22  
**Phase:** 19 — Post-mortems & soft feedback  
**Areas discussed:** Post-mortem persistence & discovery; generation timing & shape; soft nudge runtime contract; nudge UX & guardrails  
**Mode:** Operator selected **all** gray areas; requested **parallel subagent research** + **one-shot coherent recommendations** (no interactive Q/A turns).

---

## Post-mortem persistence & discovery

| Option | Description | Selected |
|--------|-------------|----------|
| A — Table only (`run_postmortems`) | Typed + JSONB; queryable | Partial (core) |
| B — CAS artifact only | Immutable bytes; weak SQL | ✗ |
| C — Embedded on `runs` | No join; hot row bloat | ✗ |
| D — Hybrid (table + optional CAS) | Postgres authoritative; CAS for export/large | ✓ |

**User's choice:** **Hybrid (D)** with **A-shaped** core — dedicated **`run_postmortems`** row, optional **`artifact_id`**, **`schema_version`**, **`RunDetailLive`** as primary discoverability.

**Notes:** Research drew analogies from **GitHub Actions summaries**, **OTel/Langfuse** (export vs SOT split), and **Fabro-style narrative-only logs** footguns. Footguns documented for CAS-only, fat-`runs`, and unconstrained JSONB.

---

## Post-mortem generation timing & shape

| Option | Description | Selected |
|--------|-------------|----------|
| A — Sync in merge transaction | Immediate; risks merge tx | ✗ (for heavy work) |
| B — Oban after commit | Bounded merge; eventual snapshot | ✓ |
| C — Lazy on first view only | Thundering herd; inconsistent | ✗ as sole persistence |

**User's choice:** **B (primary)** with **pre-snapshot UI** from `stage_runs` + audit tail; **fixed watermark** in snapshot; **idempotent** Oban unique key `post_mortem_materialize:<run_id>`.

**Notes:** Compared to **event-sourcing snapshots**, **analytics ETL lag**, **merge-queue tail behavior**. Emphasized **no double narrative** — single generator owns summary + JSON.

---

## Soft nudge runtime contract

| Option | Description | Selected |
|--------|-------------|----------|
| A — Audit + UI only | No agent consumption | ✗ (insufficient for SEED-001 trust) |
| B — Raw injection into coding prompts | Max surface / redaction pain | ✗ |
| C — Structured planner-only channel | Bounded + advisory | ✓ |

**User's choice:** **C** with **B’s discipline** framed as **fixed template + `OperatorNudge` object** at **next planning boundary**; **telemetry omits body**; **DB SoT + consume cursor** in transaction.

**Notes:** Analogues: **Cursor rules** (bounded prefs), **RLHF** (offline better than same-episode manipulation), **chatty HITL** anti-patterns vs **typed** Kiln blocks.

---

## Nudge UX & guardrails

| Pattern | Description | Selected |
|---------|-------------|----------|
| Run detail inline | Header/status band composer | ✓ |
| Modal / drawer | Transactional feel | Secondary only if needed |
| Floating widget | Global; chatty | ✗ |

**User's choice:** **Inline `RunDetailLive`**, **~140–200 char** cap, **10–30 s cooldown** + hourly cap, **`phx-disable-with`**, timeline markers, **steering microcopy** (not BLOCK playbooks).

**Notes:** Analogues: **PagerDuty notes**, **GitHub single comment**, **not Slack**.

---

## Claude's Discretion

Exact numeric caps, whether **`operator_nudges`** table vs audit-only payload, optional **`:post_mortem_snapshot_stored`** kind, CAS in **19** vs fast-follow.

## Deferred Ideas

See `<deferred>` in `19-CONTEXT.md` (webhooks, threaded chat, routing overrides, cross-run ML).
