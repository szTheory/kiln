# Phase 16 — Pattern Map

Analogs for executor **read_first** hints.

| New / touched surface | Role | Closest existing analog | Notes |
|----------------------|------|-------------------------|--------|
| `RunReplayLive` | LiveView + `handle_params` URL driver | `lib/kiln_web/live/run_compare_live.ex`, `lib/kiln_web/live/run_detail_live.ex` | Same `Layouts.app` assigns as `RunDetailLive`; UUID gates |
| Audit spine queries | Read model | `lib/kiln/audit.ex` `replay/1`, `lib/kiln_web/live/audit_live.ex` | Extend, do not fork filter vocabulary |
| Router ordering | Static vs dynamic paths | `lib/kiln_web/router.ex` (`/runs/compare` before `/runs/:run_id`) | Add `/runs/:run_id/replay` before `/runs/:run_id` |
| PubSub tail | In-flight refresh | `lib/kiln_web/live/run_board_live.ex` (`subscribe` to `runs:board`) | Also `Kiln.WorkUnits.PubSub.run_topic/1` |
| LiveView tests | LazyHTML selectors | `test/kiln_web/live/run_compare_live_test.exs` (if present) or `run_detail_live` tests | Stable `id` / `data-*` per UI-SPEC |

## Code excerpts (signatures)

```elixir
# lib/kiln/audit.ex
@spec replay(keyword()) :: [Kiln.Audit.Event.t()]
def replay(opts \\ [])
```

```elixir
# lib/kiln_web/live/audit_live.ex
def handle_params(params, _uri, socket) do
  filters = build_filters(params)
  events = Audit.replay(filters)
  # ...
end
```
