---
phase: 15
slug: run-comparison
status: approved
preset: kiln-brand
extends: .planning/phases/07-core-run-ui-liveview/07-UI-SPEC.md
created: 2026-04-22
reviewed_at: 2026-04-22T00:00:00Z
---

# Phase 15 — UI Design Contract

> Visual and interaction contract for **PARA-02 — Run comparison** (`RunCompareLive` at `/runs/compare`). Inherits **design system, typography, color, spacing, and registry rules** from **Phase 07 UI-SPEC** (`07-UI-SPEC.md`) and `prompts/kiln-brand-book.md`. This document adds **only** compare-surface specifics.

---

## Route & shell

| Property | Value |
|----------|-------|
| Canonical URL | `GET /runs/compare?baseline=<uuid>&candidate=<uuid>` |
| Param semantics | **Baseline** = reference run; **Candidate** = subject under inspection (copy, labels, and query keys stay consistent). |
| Invalid UUID | Flash error + `push_navigate` to `~p"/"` (same operator spirit as `RunDetailLive` mount). |
| Missing run (valid UUID) | Stay on compare URL; **inline column error** in the affected side (D-06). |
| Duplicate ids (`baseline == candidate`) | **Allow** with a **full-width warning** strip (`role="status"`) — no silent empty compare. |
| Intra-compare nav | `push_patch` for swap/query tweaks; entering from board/detail uses `push_navigate`. |

---

## Layout

| Viewport | Behavior |
|----------|----------|
| `lg` and up | Sticky **identity band** (short ids, workflow id, run state, spec/workflow fingerprint if shown) + **union stage spine**: one row per **stable `workflow_stage_id`**, two sub-cells (baseline \| candidate) for outcome, duration, retries, cost. **Single** primary scroll container for the spine. |
| Below `lg` | Same union ordering; sub-cells **stack** within each row (no independent dual-pane scroll for the spine). |

**Alignment:** Rows keyed by **`workflow_stage_id`** only — never pair by list index. **Gap rows** when a stage exists on one side only (“Present only in baseline” / “Present only in candidate”) per CONTEXT D-14.

---

## Components & CTAs

| Element | Treatment |
|---------|-----------|
| Page root | `id="run-compare"` on the outermost content wrapper inside `<Layouts.app>`. |
| Side anchors | `data-baseline-id` and `data-candidate-id` on a single wrapper **or** column headers (stable for tests). |
| Stage rows | `data-stage-key` = `workflow_stage_id` string. |
| **Swap** | Secondary control (border + text); **not** Ember-filled — **rewrites** `baseline`/`candidate` query params (D-08). Ember reserved for **primary** “Open diff on baseline” / “Open diff on candidate” if those are the single CTAs per column. |
| Deep links to detail diff | `~p"/runs/#{id}"` with existing `stage` / `pane` vocabulary from Phase 7; **no** second diff engine in compare. |
| Cost summary | Top **summary strip**: totals per run + **delta** when stage keys align; per-stage numbers in union table; **tabular numerals** / mono for USD and token integers (Phase 7 cost rules). |

---

## Motion & density

- **No** continuous row reordering on PubSub ticks — update cells in place.
- Respect **`prefers-reduced-motion`** for any transitions.
- Borders over shadows; Ember **only** for primary per-viewport actions (CONTEXT D-16).

---

## Copywriting (compare-specific)

| Situation | Copy |
|-----------|------|
| Compare page title | “Compare runs” |
| Empty slots (board) | “Choose baseline run” / “Choose candidate run” (sentence case). |
| Picker trigger (detail) | “Compare with…” |
| Same run twice | “Baseline and candidate are the same run — comparison is for link sharing only.” |
| Missing run column | “Run not found” + body: “Check the id or return to the board.” |
| Artifact same digest | “Same digest (SHA-256)” |
| Artifact different | “Different bytes” |
| One-sided artifact | “Present only in baseline” / “Present only in candidate” |

---

## LiveView tests (contract)

- Selectors: **`#run-compare`**, **`[data-baseline-id]`**, **`[data-candidate-id]`**, **`[data-stage-key]`** must exist on happy path.
- Board/detail → compare navigation covered in plan **03** (happy path + invalid UUID + one missing run if implemented).

---

## Checker sign-off (inline)

| Dimension | Verdict |
|-----------|---------|
| 1 Copywriting | PASS — verb+noun; gap/same-run/missing copy defined |
| 2 Visuals | PASS — focal hierarchy: identity band + union spine |
| 3 Color | PASS — inherits 60/30/10; Ember discipline |
| 4 Typography | PASS — inherits two-weight system |
| 5 Spacing | PASS — inherits 4px scale |
| 6 Registry Safety | PASS — `Layouts.app`, `<.icon>`, `<.form>` only |

**Approval:** approved 2026-04-22 (orchestrated with `/gsd-plan-phase 15` after UI gate)
