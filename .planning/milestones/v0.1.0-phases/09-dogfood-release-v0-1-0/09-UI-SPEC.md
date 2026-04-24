# Phase 9 — UI Design Contract (Dogfood Surfaces)

**Selected framework:** N/A — Phoenix LiveView 1.1 (existing stack)

**Status:** Ready for planning

## Scope

Phase 9 does **not** introduce a new marketing or product shell. **Dogfood acceptance (ROADMAP SC1)** uses **existing Phase 7/8 operator surfaces**: spec intake / draft promotion flows already routed from `/onboarding` through the factory header. This contract locks **what must remain true visually and in navigation** while automation and telemetry land.

## Screens & Flows

| Surface | Role in Phase 9 | Rules |
|---------|-----------------|-------|
| Spec authoring (draft → promote → run) | Operator writes the **canonical small spec** (CONTEXT D-901) | Reuse established **Inter / IBM Plex Mono** typography, **coal/char/bone** palette from `prompts/kiln-brand-book.md`; no new decorative motifs |
| Onboarding wizard | Cold-clone path (LOCAL-03 / ROADMAP SC4) | **Open first** link remains `/onboarding` before `/`; no surprise redirects vs `08-CONTEXT` |
| Run board / run detail | Proof the loop ran | Existing **RunProgress** + stage labels; dogfood adds **no** new chrome beyond what OTel/logging already need for operator clarity |
| `/ops/*` | Oban + ops | Unchanged boundary vs domain pages (`07-CONTEXT`) |

## Interactions

- **Dogfood template** (exact control label TBD in plan): one explicit control loads **checked-in** `dogfood/*` template bytes into the draft body so UI state matches git (D-901).
- **No freeform “AI chat”** unblock paths; typed blocks only (inherited invariant).

## States

- Loading / empty / error for template fetch: reuse **LiveView** patterns from intake (`stream` or assign-driven, no `phx-update="append"`).
- If GitHub or run enqueue fails: surface **structured error** copy (calm, concrete); never echo tokens.

## Out of Scope

- New dashboard widgets, landing site (Phase 999.1), Playwright/Wallaby unless LiveView tests prove insufficient (`09-CONTEXT` D-930).

---

*Phase 09 — UI contract for dogfood + release only.*
