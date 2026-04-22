---
phase: 15-run-comparison
status: passed
verified_at: 2026-04-22
---

# Phase 15 — Verification

## Automated

- `mix format --check-formatted` — PASS
- `mix compile --warnings-as-errors` — PASS
- `mix test` — PASS (607 tests, 23 excluded)

## Must-haves (from plans)

- `/runs/compare` registered before `/runs/:run_id` — PASS (router order)
- Invalid UUID → flash + redirect `/` — PASS (`run_compare_live_test.exs`)
- `#run-compare`, `data-baseline-id`, `data-candidate-id`, `data-stage-key` — PASS (LiveView test + stage fixtures)
- `Kiln.Runs.Compare.snapshot/2` with union + artifact metadata, no `Artifacts.read!/1` — PASS (`grep` + unit tests)
- Swap, board entry, detail picker, deep links — PASS (code review + compile)

## Notes

- `Ecto.UUID.load/1` on raw binaries showed pathological latency in this environment; canonical formatting uses `Base.encode16/2` for 16-byte binaries instead.

## Self-Check: PASSED
