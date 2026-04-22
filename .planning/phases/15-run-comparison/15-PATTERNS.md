# Phase 15 — Pattern map (PATTERNS.md)

**Phase:** 15 — Run comparison  
**Date:** 2026-04-22

---

## Summary

New surface **`RunCompareLive`** follows **`RunDetailLive`** (URL-driven `handle_params`, UUID gate) and **`RunBoardLive`** (kanban streams, PubSub — **optional** subscribe later). Read paths mirror **`Runs.get/1`** + **`Stages.list_for_run/1`** + **`Workflows.latest_stage_runs_for/1`** composition already used on detail.

---

## File → closest analog

| Planned / touched | Analog | Excerpt / pattern |
|-------------------|--------|-------------------|
| `lib/kiln_web/live/run_compare_live.ex` | `lib/kiln_web/live/run_detail_live.ex` | `mount` uses `Ecto.UUID.cast/1`; on error `put_flash(:error, …)` + `push_navigate(to: ~p"/")` |
| `lib/kiln_web/live/run_compare_live.ex` | `lib/kiln_web/live/run_detail_live.ex` | `handle_params/3` parses query; uses `push_patch` for intra-LV navigation |
| `lib/kiln_web/router.ex` | `lib/kiln_web/router.ex` | `live_session :default` block — **order** static paths before `"/runs/:run_id"` |
| `lib/kiln/runs/compare.ex` (name discretionary) | `lib/kiln/runs.ex` | Narrow `from/2` queries; **no** `select` of large blob columns |
| `lib/kiln_web/live/run_board_live.ex` | Same | `Layouts.app` wrapper; `id="run-board"` pattern → `id="run-compare"` |
| Tests | `test/kiln_web/live/*_live_test.exs` | `Phoenix.LiveViewTest` + `LazyHTML` / `has_element?/2` |

---

## Code excerpts (reference)

**Router ordering reminder** — today `"/runs/:run_id"` is declared at line ~34; compare route must **precede** it.

**UUID gate (detail mount):**

```elixir
case Ecto.UUID.cast(run_id) do
  :error ->
    {:ok, socket |> put_flash(:error, "Invalid run id") |> push_navigate(to: ~p"/")}
  {:ok, uuid} -> ...
end
```

**Stage identity** — `Kiln.Stages.StageRun` field **`workflow_stage_id`** (`:string`) is the stable union key (CONTEXT D-13–D-14).

---

## Anti-patterns (do not copy)

- Declaring **`/runs/:run_id`** before **`/runs/compare`** — `compare` would be parsed as UUID attempt and fail oddly.
- Loading artifact **bodies** in compare queries — use **metadata only** + link to detail diff.
