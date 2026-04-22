# Phase 15: Run comparison - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `15-CONTEXT.md`.

**Date:** 2026-04-22  
**Phase:** 15 — Run comparison (PARA-02)  
**Mode:** User requested **all** gray areas + **parallel subagent research** (one-shot synthesis).

**Areas covered:** Entry & selection · Routes & shareability · Layout & density · Artifact / diff depth

---

## Synthesis note

Four `generalPurpose` research agents produced independent analyses. The **merged recommendation** in `15-CONTEXT.md` resolves:

| Tension | Resolution |
|--------|------------|
| `left`/`right` vs `baseline`/`candidate` query keys | **`baseline` + `candidate`** for semantic clarity (GitHub base/head confusion lesson). |
| `push_patch` vs `push_navigate` when opening compare | **`push_navigate`** from board/detail into compare; **`push_patch`** for intra-compare query tweaks. |
| Missing run: redirect vs partial shell | **Partial shell + inline column error** when UUIDs valid but row missing (handoff links); **malformed UUID** still **redirect home** like `RunDetailLive`. |
| Modal-only compare vs URL | **Modal/drawer for picker only**; **canonical session = GET `/runs/compare?…`**. |

---

## 1. Entry & selection

| Option | Description | Selected |
|--------|-------------|----------|
| Board-only two-slot mode | Fast pick from kanban; risk if URL not updated | Partial — **as selector only** |
| Detail + picker for second | Anchor run; searchable second pick | ✓ **Primary path from detail** |
| Session-only / modal compare | No URL | ✗ |
| Dedicated compare URL from all entries | Refresh-safe, one implementation | ✓ **Canonical** |

**User's choice:** All areas discussed; research consensus adopted — **two-slot board optional**; **detail → picker → navigate**; **URL canonical**.

**Notes:** CI multi-select footgun (lost refresh) argued against assign-only selection.

---

## 2. Routes & shareability

| Option | Description | Selected |
|--------|-------------|----------|
| `/runs/compare?baseline=&candidate=` | Named GET params, bookmarkable | ✓ |
| `/runs/compare/:a/:b` | Shorter URLs; order ambiguity | ✗ for v1 |
| POST/session only | Hides state | ✗ |

**Notes:** Static route **before** `/runs/:run_id` in router. Query logs: UUIDs only — no secrets in URLs.

---

## 3. Layout & density

| Option | Description | Selected |
|--------|-------------|----------|
| Union table on `stage_key` | Two subcells per row; gaps for mismatch | ✓ |
| Index-paired rows | Simple but false equivalences | ✗ |
| Dual independent scroll | Desync footgun | ✗ |
| Cost: strip + per-row | Matches CI compare mental model | ✓ |

**Notes:** Coalesce PubSub; avoid `stream(..., reset: true)` churn; optional collapse when many stages — discretion.

---

## 4. Artifact / diff depth

| Option | Description | Selected |
|--------|-------------|----------|
| Deep-link only | Smallest payload; two clicks | ✓ **Core** |
| Digest matrix | At-a-glance equality | ✓ **v1 column** |
| Inline full diff | Second engine / payload risk | ✗ |
| Hybrid (digest + link ± tiny preview) | Balanced | ✓ **Ship shape** |

**Notes:** Ecto preload read model; no N+1; explicit **non-goals**: merged workspace diff, rename detection, full tree in LV.

---

## Claude's Discretion

Items explicitly left to planner/implementer: PubSub subscribe vs snapshot load; picker debounce; micro-preview on/off in v1; duplicate `baseline==candidate` UX variant; large-stage collapse details.

## Deferred Ideas

See `<deferred>` in `15-CONTEXT.md`.
