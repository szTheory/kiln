---
phase: 18
slug: cost-hints-budget-alerts
status: approved
shadcn_initialized: false
preset: none
created: 2026-04-22
reviewed_at: 2026-04-22
---

# Phase 18 — UI Design Contract

> Visual and interaction contract for **COST-01** + **COST-02**: retrospective cost posture on **Run detail**, soft budget threshold **banners** + desktop notifications, advisory copy aligned with Phase 17. HEEx + Tailwind v4 + existing layout tokens; **Kiln brand book** (`prompts/kiln-brand-book.md`) overrides generic defaults.

**Sources:** `18-CONTEXT.md` (D-1801–D-1825), `.planning/REQUIREMENTS.md` (COST-01, COST-02), `17-CONTEXT.md` / `17-UI-SPEC.md` (advisory bands D-1719–D-1723), `07-CONTEXT.md` (D-722 attribution).

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Phoenix LiveView) |
| Preset | not applicable |
| Component library | `KilnWeb.CoreComponents` + existing daisyUI tokens in `assets/css/app.css` |
| Icon library | `<.icon name="hero-…" />` only (`AGENTS.md`) |
| Font | **Inter** body; **IBM Plex Mono** for USD amounts, model ids, cap figures |

**Layout shell:** `RunDetailLive` already uses `<Layouts.app flash={@flash} …>` — new elements are **secondary panels** inside the run inspector, not a new route.

---

## Layout & visual hierarchy

| Surface | Focal point | Secondary |
|---------|-------------|-----------|
| Run detail — COST-01 panel | **Stage-scoped facts** after a stage completes: `cost_usd`, `requested_model`, `actual_model_used`, cap headroom | Disclaimer **chips** (always visible with any $ or tier text) per D-1805 |
| Run detail — COST-02 banner | **Single** inline alert row (daisyUI `alert alert-warning` or neutral `alert-info` per severity band) when a soft threshold fires | Dismiss control (tertiary, `aria-label` **Dismiss budget notice**) does not clear audit truth — UI-only hide for session |
| `/costs` (`CostLive`) | Unchanged primary rollup | Optional **one** end-of-run sentence referencing same disclaimer patterns (D-1804) — must not duplicate run-detail panel as primary locus |

**Accessibility:** Soft alerts are **informational**, not `role="alert"` for blocking halts — use `role="status"` or `aria-live="polite"`. Every icon-only control has `aria-label`. No primary CTA in advisory surfaces.

---

## Spacing Scale

Reuse Phase 17 table (xs–2xl). **Exception:** advisory panel uses **md** padding inside bordered panel; banner uses **sm** vertical padding flush to run header row.

---

## Typography

Reuse Phase 17 roles. **Mono** for: `cap_usd`, `spent_usd`, `actual_model_used`, `requested_model` when shown as identifiers.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Panel surface | `#1B1D21` (Char) / border `#262B31` (Iron) | COST-01 assign panel |
| Advisory accent | `#C7BFB5` (Ash) text on Char — **not** Ember | Hints are never “success” green or “error” red unless reusing semantic **warning** for 80% band only |
| Ember `#E07A3F` | Reserved for **primary actions** elsewhere — **do not** paint the whole hint panel Ember |

**Semantic:** 50% band → neutral / info token; 80% band → `alert-warning`; hard cap / halt remains existing **blocked** styling (out of scope for soft alerts).

---

## Copywriting Contract

Locked phrases (verbatim where shown):

| Element | Copy |
|---------|------|
| Disclaimer chip (any synthesized $) | **Advisory — does not change run caps** |
| Secondary chip | **Spend follows routed model** |
| 429/5xx framing (if shown) | **Resilience routing** — never “cost savings” or “cheaper model chosen for you” |
| Soft 50% desktop + banner title | **Budget notice: half of run cap reached** (body: run continues; observe spend) |
| Soft 80% | **Budget notice: most of run cap used** |
| Playbook body | Must include explicit **“The run continues.”** per D-1816 |

**Precision:** Use bands or **Indicative** language per D-1720/D-1721; if `cost_usd` is 0, show **explanation** not bare **0 USD**.

---

## Interaction

- **COST-01:** Panel updates when **stage completes** — driven by **`run:#{run_id}`** and/or `audit:run:#{run_id}` messages (implementation plan picks one; spec: user sees refresh **without** full page reload).
- **COST-02:** Banner appears on threshold **crossing** message; dismiss hides until **navigation away** or optional TTL (planner-owned; default hide for mount only).
- **No** run-board spend column in v1 (D-1803).

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Third-party component marketplaces | none | No new registries |

---

## Motion

None required — optional 150ms opacity on banner appear; respect `prefers-reduced-motion`.

---

## Sign-off

- [x] Brand hierarchy respected (data panel, not modal CTA)
- [x] COST-01 + COST-02 surfaces assigned
- [x] Copy contracts aligned with Phase 17 advisory discipline

**Approved:** 2026-04-22 (planning orchestrator — amend via discuss if operator disagrees)
