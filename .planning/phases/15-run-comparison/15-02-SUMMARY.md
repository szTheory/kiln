---
phase: 15-run-comparison
plan: "02"
subsystem: database
tags: [ecto, read-model, artifacts, union]

requires: []
provides:
  - "Kiln.Runs.Compare.snapshot/2 bounded read model"
  - "Kiln.Runs.compare_snapshot/2 delegate"
  - "RunCompareLive loads snapshot when both UUID params present"
affects: []

tech-stack:
  added: []
  patterns:
    - "Artifact pairing by workflow_stage_id::name logical key; no CAS reads"

key-files:
  created:
    - lib/kiln/runs/compare.ex
    - test/kiln/runs/run_compare_test.exs
  modified:
    - lib/kiln/runs.ex
    - lib/kiln_web/live/run_compare_live.ex

key-decisions:
  - "Union ordering prefers Workflows.graph_for_run/1 on baseline, else candidate, else sorted ids"
  - "Canonical UUID strings for DOM data-* use trimmed query params to match URL literals"

patterns-established:
  - "Equality labels derived from sha256 only (same/different/baseline_only/candidate_only/unknown)"

requirements-completed: [PARA-02]

duration: 45min
completed: 2026-04-22
---

# Phase 15 — Plan 02 Summary

**Bounded compare snapshot loads runs, latest stage attempts per workflow_stage_id, and artifact metadata without blob reads.**

## Self-Check: PASSED

- `mix test test/kiln/runs/run_compare_test.exs --max-failures 1`
- `mix compile --warnings-as-errors`

## Accomplishments

- Implemented `%Kiln.Runs.Compare.Snapshot{}` with union spine and digest rows.
- Added ExUnit coverage for union gaps and digest equality.
