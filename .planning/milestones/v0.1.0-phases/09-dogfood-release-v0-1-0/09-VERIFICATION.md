---
status: passed
phase: 09-dogfood-release-v0-1-0
verified: "2026-04-22"
---

# Phase 09 — Verification

## Automated

- `mix test` — full suite green (589 runnable tests; `kiln_scenario` still excluded by default).
- `mix test test/kiln/telemetry/otel_smoke_test.exs test/kiln/github/dogfood_test.exs test/kiln_web/live/dogfood_template_test.exs`
- `docker compose config` — valid after `otel-collector` + `jaeger` services.
- `bash script/verify_tag_version.sh 0.1.0 v0.1.0`

## Requirement trace (GIT-04 / OBS-02 / LOCAL-03)

| ID | Evidence |
|----|-----------|
| GIT-04 | `.github/workflows/ci.yml` tag job + `script/verify_tag_version.sh` |
| OBS-02 | `Kiln.Telemetry.Otel`, `Kiln.Telemetry.Spans`, compose OTLP stack |
| LOCAL-03 | README quick start + `first_run.sh` header + `.env.sample` |

## Human follow-ups (documented in plan SUMMARYs)

1. **09-04 Task 3** — set `KILN_DOGFOOD_GITHUB_TOKEN` / `KILN_DOGFOOD_REPOSITORY`; finish REST auto-merge path in `Kiln.GitHub.Dogfood.sync_pr/1` when ready.
2. **09-05 Task 3** — push annotated `v0.1.0` and publish GitHub Release from `CHANGELOG.md`.

## Self-Check: PASSED

All automated gates exercised for this execution pass; release tag remains operator-owned per plan autonomy flags.
