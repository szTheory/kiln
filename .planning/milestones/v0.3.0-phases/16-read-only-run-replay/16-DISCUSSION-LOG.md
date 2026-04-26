# Phase 16: Read-only run replay - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `16-CONTEXT.md` — this log preserves alternatives considered.

**Date:** 2026-04-22  
**Phase:** 16 — Read-only run replay  
**Areas discussed:** Routing & entry, Timeline spine, Scrub interaction, Live vs frozen  
**Mode:** User requested **all** gray areas + parallel **subagent research** + one-shot cohesive recommendations (no interactive Q/A turns).

---

## 1. Where replay lives (routing & entry)

| Option | Description | Selected |
|--------|-------------|----------|
| A — Dedicated `GET /runs/:run_id/replay` | Run-centric URL, forensic shell, matches Phase 7 URL truth | ✓ |
| B — Tab inside `RunDetailLive` | Reuse mount; risks overcrowding operate vs inspect | |
| C — Primary scrub on `/audit` | Strong for cross-run; weak for “story of run X” | |

**User's choice:** **A** (per synthesized recommendation after research).  
**Notes:** Honeycomb/Sentry/GitHub Actions reinforce **object-permalink** + query refinements; router follows **`/runs/:run_id/…` multi-segment** pattern (with `/runs/compare` still before bare `/runs/:run_id`). Complement with links to `/audit?run_id=…`.

---

## 2. Timeline composition (audit vs union)

| Option | Description | Selected |
|--------|-------------|----------|
| A — Audit-only spine | Single ordering rule, D-12 aligned, lowest surprise | ✓ (spine) |
| B — UNION sort across audit + work units + mutable rows | High double-count / clock collage risk | |
| C — Hybrid | Audit spine + **separate lane** for work units; stages as context | ✓ (full model) |

**User's choice:** **C** — authoritative **`audit_events`** ordering `occurred_at, id`; optional **second pane** for `work_unit_events`; no **`updated_at` as fake history** on mutable rows.  
**Notes:** CI flattening and trace-vs-log separation argue against blind timestamp merge.

---

## 3. Scrub interaction (MVP UX)

| Option | Description | Selected |
|--------|-------------|----------|
| Slider-first continuous | Familiar but risks server spam + reduced-motion issues | |
| Step-only | Great a11y, weak skimming | Partial (always offer prev/next) |
| Hybrid list + transport + optional range | VS Code clarity + light Grafana time window | ✓ |

**User's choice:** **Hybrid** — windowed focusable list, prev/next, range **by event index**, commit-on-release, filters for skimming, discrete “play” only if shipped.  
**Notes:** Log navigation > Netflix; hooks only if scroll-into-view needs them.

---

## 4. Live updating vs frozen snapshot

| Option | Description | Selected |
|--------|-------------|----------|
| Frozen at mount | Simple; surprises on in-flight runs | Partial (terminal runs) |
| Always live | Fresh; breaks scrub without gating | |
| Hybrid follow-edge + buffer off-edge | tail -f lesson | ✓ |

**User's choice:** **Hybrid** — terminal = **no subscribe** + optional refresh; non-terminal = **subscribe + coalesce** + **follow latest** only at live edge, else **“N new events”** jump affordance.  
**Notes:** Addresses both REPL-01 “persisted scrub” and operator expectation for active runs.

---

## Claude's Discretion

Reserved in CONTEXT for query param naming, MVP inclusion of work-unit lane, mini-map stretch, and optional 16.1 drift banner.

## Deferred Ideas

Captured in `16-CONTEXT.md` `<deferred>` (REPL-02, materialized timeline, naive UNION, session-replay gimmicks).
