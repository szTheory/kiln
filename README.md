# Kiln

[![CI](https://github.com/szTheory/kiln/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/kiln/actions/workflows/ci.yml)

Software dark factory written in Elixir/Phoenix LiveView. Given a spec, Kiln ships working software end-to-end with no human intervention — safely, visibly, and durably.

See `.planning/PROJECT.md` for the full vision and constraints.

## Fair scheduling

Kiln’s **parallelism grain** for factory work is **per active run** at the
`Kiln.Runs.RunDirector` scan: runs are ordered with **round-robin** among the
current active set, with a stable tie-break on **`inserted_at`** then
**`run_id`** (lexicographic on the UUID string). A **`fair_cursor`** in the
director remembers the last successfully spawned run so the next scan starts
after it — this is **admission order**, not a global multi-node scheduler.

**Telemetry — run queued dwell**

When a run **successfully** leaves `:queued`, the app emits a single Telemetry
measurement on **`[:kiln, :run, :scheduling, :queued, :stop]`** (the
**`run_queued`** dwell signal) with
**`duration`** in **integer milliseconds** of wall-clock time since
**`inserted_at`** (v1 uses `inserted_at` as the queued-start proxy). Metadata is
whitelisted (`run_id`, `next_state`, `correlation_id`). Do **not** attach
**`run_id`** as a Prometheus / `Telemetry.Metrics` tag in `KilnWeb.Telemetry`
— that would explode cardinality; keep this signal **event-first** for
operators and tests.

**Three different “waits” (D-16)**

- **Run queued dwell** — time the row spends in `:queued` before a successful
  transition out (signal above).
- **Oban queue time** — time a job waits between insert and execution (Oban’s
  own telemetry / job timestamps).
- **Ecto pool queue time** — time a caller waits to **checkout** a DB
  connection from the pool (repo query telemetry).

Weighted fair-share and **cross-node** scheduling charts are **out of scope**
for v1 (deferred to later milestones).

## Documentation

Operator docs and landing page (Astro + Starlight) are built from **`site/`** and published to **`https://szTheory.github.io/kiln/`** when GitHub Pages is enabled. See **`CONTRIBUTING.md`** for how to edit the site and optional `DOCS=1 mix docs.verify` checks.

## Prerequisites

- **Elixir** `~> 1.19` and **OTP** `~> 28` (see `.tool-versions` for exact pins used in development).
- **Docker** with the Compose v2 plugin (Docker Desktop or Docker Engine + `docker compose`).
- **asdf** (optional) — only if you manage Erlang/Elixir through `.tool-versions`. If you install Elixir another way, ensure `mix` is on your `PATH`; the integration script does **not** run `asdf install` for you.
- **direnv** (optional) — convenient for loading `.env`; you can `set -a; source .env; set +a` instead.

## Quick start (open `/onboarding` first)

**Compose vs host app:** `docker compose` brings up **Postgres** (and optionally **DTU**, **OTel/Jaeger** — see **Traces**). The **Phoenix app runs on your machine** via `mix phx.server` (Elixir/OTP per `.tool-versions`). There is no Kiln `app` service in Compose. For **v0.2.0**, Phase 12 ships an **optional checked-in `justfile`** that names the same primitives as this quick start — host Phoenix plus Compose for the data plane only (see **Optional: Just recipes** below and `.planning/research/LOCAL-DX-AUDIT.md`). No Compose-hosted Kiln app and no `.devcontainer/` as the shipped strategy.

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

**Why Compose does not start Kiln:** shipped layout is **Postgres + DTU (+ optional OTel) in Compose**, **Phoenix on the host** — see [`.planning/research/LOCAL-DX-AUDIT.md`](.planning/research/LOCAL-DX-AUDIT.md). Optional **`just`** orchestration lives in the repo root **`justfile`** (same contracts as this checklist).

**Longer-form operator docs** (architecture, configuration) live in the Starlight site — [Operator docs](https://szTheory.github.io/kiln/docs/) — built from `site/` per **Documentation** above.

## Optional: Just recipes (local orchestration)

If you use [**just**](https://github.com/casey/just#installation) (`brew install just` on macOS), the checked-in **`justfile`** wraps the same **Compose + `KILN_DB_ROLE=kiln_owner mix setup` + `test/integration/first_run.sh`** flow as the numbered quick start above. **Phoenix stays on the host** — run **`mix phx.server`** yourself; `just` does **not** replace it.

| Command | What it runs |
|---------|----------------|
| `just db-up` | `docker compose up -d db` |
| `just dtu-up` | `docker compose up -d dtu` |
| `just otel-up` | `docker compose up -d otel-collector jaeger` (see **Traces (local)**) |
| `just setup` | `KILN_DB_ROLE=kiln_owner mix setup` |
| `just smoke` | `bash test/integration/first_run.sh` (same SSOT as **Integration smoke**) |
| `just dev-deps` | `db-up`, then prints a one-line reminder to start **`mix phx.server`** in another shell |
| `just planning-gates` | `script/planning_gates.sh` — CI-parity **`mix check`** only (defaults match `.github/workflows/ci.yml`; Postgres must be reachable) |
| `just shift-left` | `script/shift_left_verify.sh` — **`mix check`** then **`test/integration/first_run.sh`** (Docker + `/health`; full shift-left in one shot) |
| `just before-plan-phase 12` | Runs **`shift-left`**, then prints **`/gsd-plan-phase 12 --gaps`** for GSD gap closure |

## Environment

`config/runtime.exs` reads **all** environment variables (T-02). `.env.sample` lists the keys required for a normal dev boot:

- `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`
- Optional providers: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `OLLAMA_HOST`
- Optional GitHub automation: `GH_TOKEN`, dogfood vars (`KILN_DOGFOOD_*`)
- Optional observability: `OTEL_EXPORTER_OTLP_ENDPOINT` (see **Traces (local)**)
- `KILN_DB_ROLE` — leave unset for day-to-day app runs (`kiln_app`). Set to `kiln_owner` only for migrations / DDL (`KILN_DB_ROLE=kiln_owner mix ecto.migrate`).

### Dogfood / Phase 11 (GB slice)

- **Workspace:** export `KILN_DOGFOOD_WORKSPACE=/absolute/path/to/your/clone` before running shell scenarios whose `cwd` targets the external Rust repo (not required while scenarios still use `mix` against this tree).
- **Workflow on disk:** `priv/workflows/rust_gb_dogfood_v1.yaml` — id **`rust_gb_dogfood_v1`** (load via `Kiln.Workflows.load/1`; the `/workflows` LiveView lists workflows discovered from disk when that path is wired in your deploy).
- **Spec:** `priv/dogfood/gb_vertical_slice_spec.md` — three `kiln-scenario` entries with **argv-only** `mix` steps today; swap `argv` to **`cargo test --workspace --locked`** (and `cwd` under `KILN_DOGFOOD_WORKSPACE`) once the throwaway repo exists so CI matches the operator clone (**D-1105**).

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
