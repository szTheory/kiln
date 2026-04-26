---
status: partial
phase: 26-first-live-template-run
verified: 2026-04-24
requirements:
  - LIVE-01
  - LIVE-02
  - LIVE-03
---

# Phase 26 verification — First live template run

## Automated

| Check | Result | Proof |
|-------|--------|-------|
| `mix test test/kiln_web/live/templates_live_test.exs` | PASS | proves the recommended `hello-kiln` path, backend-preflight recovery routing, and `/templates` -> `/runs/:id` arrival seam |
| `mix test test/kiln_web/live/run_detail_live_test.exs` | PASS | proves `/runs/:id` keeps the stable proof-of-life overview ids and now exposes recent evidence plus transition timing seams |
| `bash script/precommit.sh` | FAIL (out of scope) | repo gate still reports `check_no_signature_block` on `priv/workflows/_test_bogus_signature.yaml`, which was not changed in Phase 26 |

Commands (repo root):

```bash
mix test test/kiln_web/live/templates_live_test.exs
mix test test/kiln_web/live/run_detail_live_test.exs
bash script/precommit.sh
```

## Must-haves (from Phase 26 plans)

| ID | Result |
|----|--------|
| `LIVE-01` — one recommended first live run | VERIFIED by `test/kiln_web/live/templates_live_test.exs` |
| `LIVE-02` — backend preflight and settings recovery routing | VERIFIED by `test/kiln_web/live/templates_live_test.exs` |
| `LIVE-03` — believable post-launch proof on `/runs/:id` | VERIFIED by `test/kiln_web/live/run_detail_live_test.exs` |

## Scope notes

- This artifact is targeted proof for the Phase 26 operator path only.
- It does not claim the explicit repository-level end-to-end proof path from `UAT-04`; that remains Phase 27 scope.
- The repo-level `precommit` command was still run and is recorded above, but its current failure is outside the files changed for this phase.

## Human verification

None.

## Gaps

- Full repository closure remains blocked by the existing `check_no_signature_block` failure on `priv/workflows/_test_bogus_signature.yaml`.
