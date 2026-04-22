# Kiln

[![CI](https://github.com/szTheory/kiln/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/kiln/actions/workflows/ci.yml)

Software dark factory written in Elixir/Phoenix LiveView. Given a spec, Kiln ships working software end-to-end with no human intervention — safely, visibly, and durably.

See `.planning/PROJECT.md` for the full vision and constraints.

## Documentation

Operator docs and landing page (Astro + Starlight) are built from **`site/`** and published to **`https://szTheory.github.io/kiln/`** when GitHub Pages is enabled. See **`CONTRIBUTING.md`** for how to edit the site and optional `DOCS=1 mix docs.verify` checks.

## Prerequisites

- **Elixir** `~> 1.19` and **OTP** `~> 28` (see `.tool-versions` for exact pins used in development).
- **Docker** with the Compose v2 plugin (Docker Desktop or Docker Engine + `docker compose`).
- **asdf** (optional) — only if you manage Erlang/Elixir through `.tool-versions`. If you install Elixir another way, ensure `mix` is on your `PATH`; the integration script does **not** run `asdf install` for you.
- **direnv** (optional) — convenient for loading `.env`; you can `set -a; source .env; set +a` instead.

## Quick start (open `/onboarding` first)

**Compose vs host app:** `docker compose` brings up **Postgres** (and optionally **DTU**, **OTel/Jaeger** — see **Traces**). The **Phoenix app runs on your machine** via `mix phx.server` (Elixir/OTP per `.tool-versions`). There is no Kiln `app` service in Compose in v0.1.0; optional all-in-one / devcontainer DX is **Phase 12** in `.planning/ROADMAP.md` (see `.planning/research/LOCAL-DX-AUDIT.md`).

1. **Environment** — `cp .env.sample .env` then load it (`direnv allow` or export vars manually). See **Environment** below for required keys.
2. **Database** — `docker compose up -d db` and wait until Postgres is healthy.
3. **Migrations (owner role)** — `KILN_DB_ROLE=kiln_owner mix setup` (runs `ecto.create`, `ecto.migrate`, seeds, assets). Runtime sessions use the restricted `kiln_app` role by default.
4. **Run the app** — `mix phx.server`.
5. **Open first** — `http://localhost:4000/onboarding` (operator wizard; Phase 8 intake). The root `/` route shows the run board after onboarding completes.

### Digital Twin / sandbox mocks (DTU)

Sandbox stages talk to **DTU** (mock HTTP) on Compose’s internal **`kiln-sandbox`** network (`internal: true` in `compose.yaml` — no egress to the public internet from that bridge). The quick start above only starts **Postgres** so you can reach the UI quickly.

**Before your first sandbox-backed stage**, start DTU and wait until it is healthy:

```bash
docker compose up -d dtu
docker compose ps dtu
```

See service definitions in [`compose.yaml`](compose.yaml) (`db`, `dtu`, `otel-collector`, `jaeger`). Optional **`sandbox-net-anchor`** profile exists for advanced local networking — not required for the default README path.

### Other useful URLs

- `http://localhost:4000/ops/dashboard` — Phoenix LiveDashboard
- `http://localhost:4000/ops/oban` — Oban.Web
- `http://localhost:4000/health` — JSON health probe (Plan 06 contract)

## Operator checklist

Use this as a **cold-clone** sanity pass (order matches the happy path above):

- [ ] **Tooling** — Elixir/OTP per [`.tool-versions`](.tool-versions), Docker with Compose v2, `mix` on `PATH` (see **Prerequisites**).
- [ ] **Secrets file** — `cp .env.sample .env`; fill at least `SECRET_KEY_BASE`, `DATABASE_URL`, `PORT` / `PHX_HOST` as in **Environment** below.
- [ ] **Database** — `docker compose up -d db`; Postgres shows **healthy** in `docker compose ps`.
- [ ] **Port 5432** — If another Postgres or container holds host `5432`, remap in `compose.yaml` + `DATABASE_URL` (see [`test/integration/first_run.sh`](test/integration/first_run.sh) error text).
- [ ] **Migrations** — `KILN_DB_ROLE=kiln_owner mix setup` once (creates DB if needed, migrates, seeds, assets). Day-to-day runs leave `KILN_DB_ROLE` unset (`kiln_app`).
- [ ] **App** — `mix phx.server` without `KILN_SKIP_BOOTCHECKS` (BootChecks must pass).
- [ ] **Onboarding** — Open `/onboarding` first; complete the wizard or resolve typed blockers (API keys, Docker, `gh` when using GitHub automation).
- [ ] **Sandbox work** — Before stages that hit mocks: `docker compose up -d dtu` (subsection above).
- [ ] **Machine smoke (optional)** — `bash test/integration/first_run.sh` or `mix integration.first_run` — DB + migrate + boot + `/health` JSON (does not prove browser onboarding).
- [ ] **Traces (optional)** — See **Traces (local)**; set `OTEL_EXPORTER_OTLP_ENDPOINT` only when collector/Jaeger are up.

**Why Compose does not start Kiln:** shipped layout is **Postgres + DTU (+ optional OTel) in Compose**, **Phoenix on the host** — see [`.planning/research/LOCAL-DX-AUDIT.md`](.planning/research/LOCAL-DX-AUDIT.md). Optional all-in-one / devcontainer DX is **Phase 12** (`.planning/ROADMAP.md`).

**Longer-form operator docs** (architecture, configuration) live in the Starlight site — [Operator docs](https://szTheory.github.io/kiln/docs/) — built from `site/` per **Documentation** above.

## Environment

`config/runtime.exs` reads **all** environment variables (T-02). `.env.sample` lists the keys required for a normal dev boot:

- `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`
- Optional providers: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `OLLAMA_HOST`
- Optional GitHub automation: `GH_TOKEN`, dogfood vars (`KILN_DOGFOOD_*`)
- Optional observability: `OTEL_EXPORTER_OTLP_ENDPOINT` (see **Traces (local)**)
- `KILN_DB_ROLE` — leave unset for day-to-day app runs (`kiln_app`). Set to `kiln_owner` only for migrations / DDL (`KILN_DB_ROLE=kiln_owner mix ecto.migrate`).

## Human-required vs automated

| Step | Human | Automated in CI / scripts |
|------|-------|---------------------------|
| Create `.env` from `.env.sample` | Yes | No |
| `gh auth login` / GitHub App install for private automation | Yes (when using GH features) | No |
| Vendor API keys (`ANTHROPIC_*`, etc.) | Yes | No (CI uses placeholders) |
| `docker compose up -d db` | Yes (local) | No (Actions uses a service container instead of compose) |
| `mix check` on push / PR | N/A | Yes (`.github/workflows/ci.yml`) |
| `mix check` + boot checks | N/A | Yes on `main`; tag pushes run the **tag vs `mix.exs` version** gate |

## Traces (local, OBS-02)

With the stack running:

```bash
docker compose up -d otel-collector jaeger
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
mix phx.server
```

Open Jaeger UI at `http://localhost:16686`. Omit `OTEL_EXPORTER_OTLP_ENDPOINT` to keep the SDK in noop mode.

## Running the test suite

```bash
mix check        # format + compile + test + credo + dialyzer + sobelow + mix_audit + xref + boot checks
mix test --stale # fast inner loop
```

## Integration smoke (`first_run.sh`)

**SSOT command** (DB + migrate + host boot + `/health` JSON — does not hit `/onboarding`; see **Human-required vs automated**):

```bash
bash test/integration/first_run.sh
```

Mix-discoverable alias (same script, no duplicated orchestration):

```bash
mix integration.first_run
```

Header comments in `test/integration/first_run.sh` match this README: **asdf is not invoked** — the script assumes `docker`, `jq`, `curl`, `lsof`, and `mix` are already on `PATH` per the prerequisites above.

## Running migrations

Plan 03 introduces a two-role Postgres model (`kiln_owner` owns DDL, `kiln_app` is the runtime role). Migrations must run as `kiln_owner`:

```bash
KILN_DB_ROLE=kiln_owner mix ecto.migrate
```

See `config/runtime.exs` for the `KILN_DB_ROLE` switch.

## Bypassing boot checks (emergency only)

`Kiln.BootChecks.run!/0` asserts durability-floor invariants at boot. For local debugging only:

```bash
KILN_SKIP_BOOTCHECKS=1 mix phx.server
```

Never use in production.

## License

Licensed under the **Apache License, Version 2.0** — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
