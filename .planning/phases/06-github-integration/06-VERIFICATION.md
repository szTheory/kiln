---
status: passed
phase: "06-github-integration"
verified: "2026-04-21"
---

# Phase 6 Verification

## Automated

- `mix test` — PASS (556 tests, 40 excluded)
- `mix check_bounded_contexts` — PASS

## Must-haves (GIT-01..03, ORCH-07)

| Item | Evidence |
|------|----------|
| `Kiln.Git` shell boundary + CAS payload | `lib/kiln/git.ex`, `test/kiln/git_test.exs` |
| `gh` PR create + checks summarisation | `lib/kiln/github/cli.ex`, `lib/kiln/github/checks.ex`, fixtures |
| Oban workers `git_push` / `gh_pr_create` / `gh_check_observe` | `lib/kiln/github/*_worker.ex`, tests |
| `github_delivery_snapshot` + Promoter transitions | migration, `lib/kiln/github/promoter.ex`, tests |
| Idempotent replay (ORCH-07) | `test/integration/github_delivery_test.exs` |

## Notes

- Human GitHub / `gh auth` flows are not exercised in CI (hermetic doubles only).
