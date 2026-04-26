# Phase 9 Research — Dogfood & Release (v0.1.0)

**Question answered:** What must we know to **plan** GIT-04, OBS-02, and LOCAL-03 together with a Kiln-builds-Kiln proof and tag?

## Current repo facts (2026-04-21)

- **CI (`GIT-04` baseline):** `.github/workflows/ci.yml` runs on `push`/`pull_request` to `main`; `mix check`, Dialyzer cache, `KILN_DB_ROLE=kiln_owner mix ecto.migrate && mix kiln.boot_checks`. **Gap:** no `on.push.tags` job for **tag ↔ `mix.exs` version** gate (CONTEXT D-923). README may lack CI badge (ROADMAP SC2).
- **OTel deps:** `mix.exs` lists `opentelemetry`, `opentelemetry_api`, `opentelemetry_exporter` only — **no** `opentelemetry_phoenix`, `opentelemetry_bandit`, `opentelemetry_ecto`, `opentelemetry_oban` yet; **no** `lib/` usage grep hit (OBS-02 gap).
- **Integration:** `test/integration/first_run.sh` documents prerequisites (asdf, docker, jq, curl, lsof) and health JSON contract — must stay aligned with README (D-932).

## OpenTelemetry (Erlang/Elixir)

- **Tracing:** Use **OpenTelemetry SDK 1.x** already in deps; add Hex instrumenters aligned with **Phoenix 1.8 + Bandit**: `opentelemetry_phoenix` with **`adapter: :bandit`**, `opentelemetry_bandit`, `opentelemetry_ecto` (attach to `Kiln.Repo` telemetry), `opentelemetry_oban` — follow current Hex docs for **`OpentelemetryOban.setup()`** / insert hooks so **enqueue → perform** shares trace context.
- **Propagation:** Add **`opentelemetry_process_propagator`** and attach where `Task.async`, raw spawned work, or hand-rolled processes could drop context; verify **Oban** docs for propagation version used in `mix.lock`.
- **Semantic spans (manual):** Use `OpenTelemetry.Tracer.with_span/3` for stable names: `kiln.run.stage`, `kiln.agent.call`, `kiln.docker.op`, `kiln.llm.request` — attributes **low-cardinality**; never prompts, keys, or PII (D-913, SEC-01).
- **Export:** OTLP gRPC/HTTP via env (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`); **docker compose** adds **otel-collector** + **Jaeger** as in CONTEXT D-911 — app stays vendor-neutral.
- **Metrics:** ROADMAP + CONTEXT defer metrics SDK until stable — **trace + log correlation only** for v0.1.0 (D-910).

## Dogfood GitHub automation

- **Auth:** Prefer **GitHub App** installation token or **fine-grained PAT** scoped to `szTheory/kiln` with `contents` + `pull_requests` (D-902); store as **secret reference** / CI secret, not in repo.
- **Idempotency:** All mutating GitHub + git operations pair with **`external_operations`** + Oban unique per project invariants (D-903).
- **Branch/PR naming:** Prefix `kiln/dogfood/...`; labels for idempotency key; **reuse open PR** for same spec hash (D-903).
- **Auto-merge:** Enable when checks green; document required status check names matching `ci.yml` job.
- **Path allowlist:** Block changes under `.github/workflows/` unless spec explicitly allows (D-904).

## Release & legal

- **LICENSE:** Apache-2.0 default per CONTEXT D-922 unless dependency audit forces NOTICE.
- **CHANGELOG:** Keep a Changelog format; `[0.1.0]` section lists REQ coverage (D-920).
- **Tag workflow:** Annotated `v0.1.0` on merge commit after CHANGELOG/LICENSE/README final (D-924); CI verifies tag matches `Mix.Project.config()[:version]` (D-923).

## Pitfalls (release-blocking per ROADMAP)

- **P17:** Trace fragmentation — validate in Jaeger after wiring Oban + Ecto.
- **P2/P8/P21:** Spans and logs must respect redaction — same bar as logger metadata filter.

## Validation Architecture

Phase 9 validation is **multi-layer** (CONTEXT D-930):

| Layer | Command / artifact | When |
|-------|-------------------|------|
| Fast compile | `mix compile --warnings-as-errors` | After each task touching `lib/` |
| Unit/integration | `mix test` (targeted then full) | After OTel + dogfood logic |
| Meta gate | `mix check` | Per plan verification + CI |
| Boot / DB invariants | `KILN_DB_ROLE=kiln_owner mix ecto.migrate && mix kiln.boot_checks` | When migrations or repo touched |
| Integration script | `bash test/integration/first_run.sh` | README / compose / health contract changes (local; not in default `mix check`) |
| Trace shape | Manual: run dogfood against local Jaeger, confirm span tree | Before declaring OBS-02 done |
| Cold clone | Manual once per milestone: second machine, README-only friction log | LOCAL-03 / SC4 |

**Nyquist note:** No single Playwright suite covers OTel; rely on **automated mix tests** for propagation helpers plus **documented manual Jaeger + cold-clone** rows in `09-VALIDATION.md`.

## RESEARCH COMPLETE
