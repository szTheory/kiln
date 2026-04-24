---
phase: 15-run-comparison
status: clean
reviewed: 2026-04-22
depth: standard
---

# Phase 15 — Code review (standard)

## Scope

Files from phase summaries and implementation:

- `lib/kiln_web/router.ex`
- `lib/kiln_web/live/run_compare_live.ex`
- `lib/kiln/runs/compare.ex`
- `lib/kiln/runs.ex`
- `lib/kiln_web/live/run_board_live.ex`
- `lib/kiln_web/live/run_detail_live.ex`
- `test/kiln/runs/run_compare_test.exs`
- `test/kiln_web/live/run_compare_live_test.exs`

## Summary

Run comparison (PARA-02) validates UUID query parameters, loads a bounded snapshot
(stages + artifact metadata only, no CAS reads), and wires board/detail entry
points. No blocking security or correctness issues identified. Navigation uses
`URI.encode_query` over cast UUIDs; invalid baseline triggers a home redirect
before the compare surface renders.

## Findings

### Advisory — template cost

`RunCompareLive` walks `@snapshot.union_stage_ids` and calls
`Enum.find(@snapshot.rows, …)` per row. For large unions this is \(O(n^2)\).
Acceptable for an operator-local UI; consider a `Map` keyed by
`workflow_stage_id` if the union grows large.

### Advisory — compare navigation strings

Board and run detail use `push_navigate(to: "/runs/compare?" <> q)` (and swap
uses `push_patch` with the same pattern). Query strings are built from cast
UUIDs, so this is safe; using verified route helpers everywhere would reduce
drift if paths change.

### Advisory — silent ignore on board compare pick

`RunBoardLive.handle_event("pick_compare_slot", …)` returns `{:noreply, socket}`
on invalid `id` or `slot` with no flash. Operators get no feedback if a client
sends a malformed value.

### Advisory — compare picker cap

`RunDetailLive` “Compare with…” lists `Runs.list_for_board()` minus self, then
`Enum.take(10)`. Runs beyond the cap are invisible without search or paging.

## Security notes

- Compare URLs and `phx-value` payloads flow through `Ecto.UUID.cast/1` or
  equivalent formatting before navigation; no raw user strings reach SQL.
- `Kiln.Runs.Compare` selects artifact columns only; `Artifacts.read!/1` is not
  used on this path (bounded read model as intended).

## Residual risks

- Reliance on `live_redirect` from `handle_params` for invalid UUIDs assumes
  LiveView continues to avoid rendering the template on that error path; if that
  behavior changed, `mount/3` would need default assigns for every key used in
  `render/1`.

## Next steps

- Optional fixes for advisories: `mix test` after changes.
- To auto-apply review-driven fixes: `/gsd-code-review-fix 15`.
