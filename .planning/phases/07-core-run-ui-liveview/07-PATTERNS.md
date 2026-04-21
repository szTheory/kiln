# Phase 7 — Pattern Map

**Purpose:** Closest analogs in-repo for planners/executors.

---

## LiveView shell

| New file | Analog | Pattern |
|----------|--------|---------|
| `lib/kiln_web/live/run_board_live.ex` | `lib/kiln_web/live/spec_editor_live.ex` | `use KilnWeb, :live_view`; `mount/3`; flash + `push_navigate`; no `flash_group` outside `Layouts` |
| `lib/kiln_web/live/run_detail_live.ex` | `spec_editor_live.ex` | `handle_params/3` for URL-driven state (extend beyond spec editor’s mount-only ID) |
| `lib/kiln_web/live/workflow_live.ex` | `spec_editor_live.ex` | Read-heavy HEEx; monospace regions for YAML |
| `lib/kiln_web/live/cost_live.ex` | `spec_editor_live.ex` | Assign-heavy tables; consider `stream` when row count > 100 |
| `lib/kiln_web/live/audit_live.ex` | `spec_editor_live.ex` | `<.form>` for filters (GET-style `phx-change` to `push_patch`) |

---

## Router

| Target | Analog |
|--------|--------|
| `lib/kiln_web/router.ex` | Existing `live_session :default` block with `SpecEditorLive` |

---

## Realtime

| Concern | Analog |
|---------|--------|
| Post-commit PubSub | `lib/kiln/runs/transitions.ex` — `Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board", {:run_state, run})` |

---

## Domain queries

| Concern | Analog |
|---------|--------|
| Run reads | `lib/kiln/runs.ex` — `list_active/0`, `get!/1` |
| Stage rows | `lib/kiln/stages.ex` — `list_for_run/1` |
| Audit read | `lib/kiln/audit.ex` — `replay/1` |
| Artifacts | `lib/kiln/artifacts.ex` — `get/2`, `stream!/1` |
| Workflow checksum | `lib/kiln/workflows/compiled_graph.ex` |

---

## Layout / components

| Target | Analog |
|--------|--------|
| `KilnWeb.Components.*` | `lib/kiln_web/components/core_components.ex` — function components + Tailwind classes |
| Root chrome | `lib/kiln_web/components/layouts.ex` — `Layouts.app` |

---

## Excerpt: PubSub broadcast (executor must preserve ordering)

From `transitions.ex` (after transaction):

```elixir
Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board", {:run_state, run})
```

Board LiveView **must not** subscribe to per-run high-volume topics (D-728).

---

## PATTERN MAPPING COMPLETE
