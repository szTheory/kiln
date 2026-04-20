# Phase 4 PubSub topics — work units

Publisher: `Kiln.WorkUnits` (after successful `Repo.transact/2` commits).

## Topics

| Topic pattern | Purpose |
|---------------|---------|
| `work_units` | Global fan-out for dashboards |
| `work_units:<work_unit_id>` | Per-unit subscribers |
| `work_units:run:<run_id>` | Run-scoped subscribers |

Helpers live in `Kiln.WorkUnits.PubSub` (`global_topic/0`, `unit_topic/1`, `run_topic/1`).

## Message shape

All three channels receive the same tuple:

```elixir
{:work_unit, %{id: id, run_id: run_id, event: event_atom}}
```

`event_atom` is one of `:created`, `:claimed`, `:blocked`, `:unblocked`, `:closed`, or `:handoff_complete` (used when a unit finishes handoff with successors).

## Rules

1. Broadcast **only after** the database transaction returns `{:ok, _}`.
2. Keep payloads small and stable; add fields only with a version bump in later phases.
