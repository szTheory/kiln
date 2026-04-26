---
status: passed
phase: 28-first-run-proof-runtime-closure
verified: 2026-04-24
requirements:
  - UAT-04
---

# Phase 28 verification — First-run proof runtime closure

## Owning proof command

`mix kiln.first_run.prove`

Phase 28 is the closure authority for `UAT-04`. This rerun-backed artifact
owns the final requirement status because it proves the delegated integration
layer now boots under `KILN_DB_ROLE=kiln_app`, reaches `/health`, and then
hands off to the focused LiveView layer.

## Automated

| Check | Result | Proof |
|-------|--------|-------|
| `mix test test/kiln/repo/migrations/oban_runtime_privileges_test.exs` | PASS | proves `kiln_app` can read/update `oban_jobs`, maintain `oban_peers`, and execute the pre-created Oban Met estimate function |
| `mix integration.first_run` | PASS | proves the delegated first-run script now starts `mix phx.server` as `kiln_app` and reaches `/health` with `{"status":"ok","postgres":"up","oban":"up","contexts":13,"version":"0.1.0"}` |
| `mix kiln.first_run.prove` | PASS | proves the repository-owned top-level first-run command completes end to end from repo root |
| `bash script/precommit.sh` | PASS | final project gate required by repo instructions |

Commands (repo root):

```bash
mix test test/kiln/repo/migrations/oban_runtime_privileges_test.exs
mix integration.first_run
mix kiln.first_run.prove
bash script/precommit.sh
```

## Must-haves

| ID | Result |
|----|--------|
| `UAT-04` — one explicit automated proof path with exact command citation | VERIFIED by this artifact and the passing `mix kiln.first_run.prove` rerun |
| delegated integration layer reaches `/health` under the intended runtime role | VERIFIED by `mix integration.first_run` after `test/integration/first_run.sh` forced `KILN_DB_ROLE=kiln_app` for app boot |
| runtime boot no longer dies on `oban_jobs` privilege drift | VERIFIED by the new Oban privilege migrations and focused regression |

## Scope notes

- This artifact closes the repository-level runtime-proof gap only.
- Phase 27 remains the origin of the wrapper command and focused LiveView seam, but its completion claim is historical rather than requirement-owning.
- The proof stays on the existing command stack (`mix kiln.first_run.prove` -> `mix integration.first_run` -> focused LiveView tests); no replacement harness was introduced.

## Human verification

None.
