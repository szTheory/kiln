# Phase 33: Repeat-run continuity on attached repos - Pattern Map

**Mapped:** 2026-04-24  
**Files analyzed:** 8 implied target files  
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `priv/repo/migrations/*_add_attached_repo_continuity_metadata.exs` | schema | storage | `priv/repo/migrations/20260424120544_create_attached_repos.exs` | exact |
| `lib/kiln/attach/attached_repo.ex` | schema | storage | `lib/kiln/attach/attached_repo.ex` | exact |
| `lib/kiln/attach/continuity.ex` | service/query | request-response | `lib/kiln/attach/intake.ex`, `lib/kiln/attach/delivery.ex` | role-match |
| `lib/kiln/attach.ex` | public boundary | request-response | `lib/kiln/attach.ex` | exact |
| `lib/kiln/specs.ex` | context query | request-response | `lib/kiln/specs.ex` | exact |
| `lib/kiln/runs.ex` | context query/start seam | request-response | `lib/kiln/runs.ex` | exact |
| `lib/kiln_web/live/attach_entry_live.ex` | LiveView | SSR + events | `lib/kiln_web/live/attach_entry_live.ex` | exact |
| `test/kiln_web/live/attach_entry_live_test.exs` | LiveView proof | request-response | `test/kiln_web/live/attach_entry_live_test.exs` | exact |

## Pattern Assignments

### `lib/kiln/attach/continuity.ex` (service/query)

**Primary analog:** `lib/kiln/attach/intake.ex`

Use the existing narrow-boundary shape: validate ids, load authoritative rows, normalize return data once, and keep raw Repo access out of LiveView.

**What to copy**

- Accept durable ids and return tagged tuples only.
- Keep precedence and normalization inside the context boundary.
- Let LiveView consume shaped data instead of assembling joins itself.

**Anti-patterns to avoid**

- Do not put continuity precedence rules in `AttachEntryLive`.
- Do not make the service own unrelated mutable preflight logic.
- Do not hide repo identity in snapshots when explicit foreign keys exist.

### `lib/kiln/attach.ex` (public boundary)

**Primary analog:** existing `lib/kiln/attach.ex`

Phase 33 should extend the public attach boundary with continuity entry points instead of teaching LiveView about `Kiln.Attach.Continuity` directly.

**What to copy**

- Thin pass-through functions to narrower internal modules.
- Small typed public API for recent repos, selected continuity, and usage-metadata updates.

**Anti-patterns to avoid**

- Do not bypass the public attach boundary from `/attach`.
- Do not grow `Attach` into a giant mixed query/command module; keep deeper logic in a dedicated continuity module.

### `lib/kiln/specs.ex` (context query)

**Primary analog:** existing promotion/query helpers in `lib/kiln/specs.ex`

Use Specs to read draft and revision continuity candidates where that ownership already exists.

**What to copy**

- Lock state-aware queries around `spec_drafts` and `spec_revisions`.
- Preserve mutable-vs-immutable lifetime separation.

**Anti-patterns to avoid**

- Do not make `attached_repos` the source of request truth.
- Do not parse request meaning back out of markdown bodies when structured fields already exist.

### `lib/kiln/runs.ex` (context query/start seam)

**Primary analog:** existing attach-aware start helpers in `lib/kiln/runs.ex`

Extend `Runs` with continuity-friendly history queries or helpers, then keep final start authority in the existing run context.

**What to copy**

- Explicit typed helpers over `runs` row identity.
- Continue returning typed blocked/error tuples for start preflight.

**Anti-patterns to avoid**

- Do not let continuity invent a parallel run-start path.
- Do not trust previous run status as launch authority for a new run.

### `lib/kiln_web/live/attach_entry_live.ex` (LiveView)

**Primary analog:** existing ready/blocked/request flow in `AttachEntryLive`

Keep the LiveView as a projection of server-owned continuity state with explicit ids, `handle_params/3`, `push_patch`, and `to_form/2`.

**What to copy**

- Stable DOM ids everywhere continuity needs proof.
- One request form assign driven from backend-owned params.
- Existing ready/blocked/error posture and `Layouts.app` wrapper.

**Anti-patterns to avoid**

- Do not cache continuity in the browser as the source of truth.
- Do not silently prefill across repos.
- Do not collapse the continuity card into transcript-like text dumps.

## Cross-Cutting Rules

- Reuse explicit FK joins for identity; use snapshots only for derived context.
- Prefer narrow joined read models for lists and continuity cards.
- Use preloads only for one selected detail surface.
- Keep recent ordering explicit with continuity metadata rather than `updated_at`.
- Keep Phase 33 focused on continuity; do not absorb Phase 34 guardrails or Phase 35 handoff polish.
