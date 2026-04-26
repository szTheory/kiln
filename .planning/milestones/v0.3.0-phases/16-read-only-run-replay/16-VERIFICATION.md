---
phase: 16-read-only-run-replay
status: passed
verified_at: 2026-04-22
---

# Phase 16 — Verification

## Automated

- `mix format --check-formatted` — PASS (touched Elixir sources)
- `mix compile --warnings-as-errors` — PASS
- `mix test test/kiln_web/live/run_replay_live_test.exs test/kiln/audit_replay_test.exs` — PASS (5 tests)
- Full `mix test` — not re-run to completion in this workspace session (prior parallel run hit `Kiln.Repo` sandbox startup errors); run locally or in CI before merge.

## Must-haves (from plans)

- `live "/runs/:run_id/replay"` before `live "/runs/:run_id", RunDetailLive` — PASS (`router.ex`)
- Invalid path UUID → flash + redirect `/` — PASS (`RunReplayLive` mount + `run_replay_live_test.exs`)
- `#run-replay`, `data-run-id`, stream ids `replay-event-*` — PASS (LiveView + tests)
- `Audit.replay_page/1` keyset `ORDER BY occurred_at ASC, id ASC` + tie-break test — PASS (`audit_replay_test.exs`)
- `Audit.replay/1` callers unchanged — PASS (existing `replay/1` retained)
- PubSub `audit:run:<run_id>` on successful insert with `run_id` — PASS (`audit.ex`)
- `RunReplayLive` uses `replay_page` (tail + forward), scrub via `push_patch`, range `#replay-scrubber`, subscriptions gated for terminal runs, debounced flush — PASS (module + greps)
- No `Audit.append` / `Repo.insert` / `Repo.update` / `Transitions.` in `RunReplayLive` — PASS (`grep -E`)
- Run detail **Timeline** link to `/runs/:id/replay` — PASS (`run_detail_live.ex`)
- Deep link **Open in Audit** with `run_id` query — PASS (`run_replay_live.ex`)

## Self-Check: PASSED
