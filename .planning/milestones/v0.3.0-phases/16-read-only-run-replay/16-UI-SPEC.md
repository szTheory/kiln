---
phase: 16
slug: read-only-run-replay
status: approved
preset: kiln-brand
extends: .planning/phases/07-core-run-ui-liveview/07-UI-SPEC.md
created: 2026-04-22
reviewed_at: 2026-04-22T00:00:00Z
---

# Phase 16 — UI Design Contract

> Visual and interaction contract for **REPL-01 — Read-only run replay** (`RunReplayLive` at **`GET /runs/:run_id/replay`**). Inherits **design system, typography, color, spacing, and registry rules** from **Phase 07 UI-SPEC** and `prompts/kiln-brand-book.md`. This document adds **only** replay-surface specifics.

---

## Route & shell

| Property | Value |
|----------|-------|
| Canonical URL | `GET /runs/:run_id/replay?at=<audit_event_uuid>` |
| `at` absent | Load **latest window** (tail of spine); do **not** error. |
| `at` present invalid UUID | Match **`RunDetailLive`**: `put_flash(:error, "Invalid run id")` **or** same flash string as detail for param errors — pick **one** and document in plan (default: **invalid `run_id` path** uses "Invalid run id"; invalid **`at`** uses **inline** empty selection + flash **"Invalid event id"** without leaving replay). |
| Unknown `at` (valid UUID, not in spine) | Inline **warning** strip; reset selection to **nearest** or **latest** (executor choice documented in plan). |
| Intra-replay scrub | **`push_patch`** to adjust **`at`** only. |
| Enter from board/detail | **`push_navigate`** to replay URL (mode change). |

---

## Layout

| Viewport | Behavior |
|----------|----------|
| `lg` and up | **Two columns:** left = **ordered event list** (spine); right = **detail** for selected event (kind, timestamps, ids, payload summary). **Single** primary scroll for the list. |
| Below `lg` | List **above** detail; one column. |

**Read-only:** **No** forms that mutate run state, **no** resume/unblock, **no** compare pickers on this surface (CONTEXT D-06).

---

## Components & CTAs

| Element | Treatment |
|---------|-----------|
| Page root | **`id="run-replay"`** on outermost content wrapper inside `<Layouts.app>`. |
| Run binding | **`data-run-id`** on the same wrapper (binary id string). |
| Event rows | **`id="replay-event-#{event.id}"`** (DOM id stable for tests). |
| Transport | **Prev** / **Next** always; **First** / **Last** optional; **`type="range"`** scrubber commits on **change** end (debounced server updates per CONTEXT D-13). |
| Truncation | When server returns **`truncated: true`**, show **calm** banner: **"Showing first N events — refine filters or export from Audit."** (exact copy in plan). |
| Live edge | **"N new events — jump to latest"** control when buffered (CONTEXT D-20). |
| Deep links | **To Audit:** `~p"/audit?#{%{run_id: run.id} |> URI.encode_query()}"` (or equivalent) with run prefilled. **From detail/board:** control label **"Timeline"** or **"Replay"** (sentence case). |

---

## Motion & density

- **No** cinematic playback; optional **Play** advances **one event per tick** only if shipped.
- **`prefers-reduced-motion`:** disable smooth auto-scroll / auto-advance; **instant** seek.
- Borders over shadows; mono for timestamps and ids (CONTEXT D-16).

---

## Copywriting (replay-specific)

| Situation | Copy |
|-----------|------|
| Page title | **"Run replay"** or **"Timeline — Run {short_id}"** (match board voice). |
| Empty spine | **"No audit events for this run yet."** |
| Terminal snapshot | One line: **"Complete"** + last event time. |
| Live | **"Live"** + last event time (CONTEXT D-21). |

---

## LiveView tests (contract)

- Selectors **`#run-replay`**, **`[data-run-id]`**, **`#replay-event-<uuid>`** (pattern documented in test), **`input[type="range"]#replay-scrubber`** (if scrubber ships in MVP).
- Happy path: navigate with valid run → list renders → **patch** `at` changes selection.

---

## Checker sign-off (inline)

| Dimension | Verdict |
|-----------|---------|
| 1 Copywriting | PASS — operator microcopy; truncation + live edge defined |
| 2 Visuals | PASS — two-column spine + detail hierarchy |
| 3 Color | PASS — inherits 60/30/10; Ember only for primary jump/CTA |
| 4 Typography | PASS — mono for ids/timestamps |
| 5 Spacing | PASS — inherits 4px scale |
| 6 Registry Safety | PASS — `Layouts.app`, `<.icon>` only |

**Approval:** approved 2026-04-22 (bundled with `/gsd-plan-phase 16` to clear UI gate)
