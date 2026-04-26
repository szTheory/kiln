# Kiln

[![CI](https://github.com/szTheory/kiln/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/kiln/actions/workflows/ci.yml)

Software dark factory written in Elixir/Phoenix LiveView. Given a spec, Kiln ships working software end-to-end with no human intervention — safely, visibly, and durably.

See `.planning/PROJECT.md` for the full vision and constraints.

## First hour

**Requires: Docker with Compose v2.** No Elixir install needed.

```bash
docker compose up
```

Open **http://localhost:4000** — you'll land on the onboarding flow. Before your first live run visit `/settings` to connect providers and GitHub auth.

First start takes 2–3 min to fetch and compile deps; subsequent starts are fast (deps are cached in a named volume).

> **Host Elixir path (faster inner loop):** if you have Elixir/OTP installed (`asdf install` from `.tool-versions`), you can skip Docker for the app and run `bash script/dev_up.sh` instead — Postgres still runs in Docker, Phoenix runs on your machine.

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

## Quick start (use `/settings` before your first live run)

**Fastest path (one command):** from the repo root, run **`bash script/dev_up.sh`** (or **`just dev`** if you use [`just`](https://github.com/casey/just)) — starts Compose **Postgres**, runs **`mix setup`**, then **`mix phx.server`** in the foreground (Ctrl+C stops the server). Uses `.env` (creates from `.env.sample` if missing). Same host-port rules as below if `5432` is taken (`KILN_DB_HOST_PORT` + matching `DATABASE_URL`).

**Compose vs host app:** `docker compose` brings up **Postgres** (and optionally **DTU**, **OTel/Jaeger** — see **Traces**). The **Phoenix app runs on your machine** via `mix phx.server` (Elixir/OTP per `.tool-versions`). There is no Kiln `app` service in Compose. For **v0.2.0**, Phase 12 ships an **optional checked-in `justfile`** that names the same primitives as this quick start — host Phoenix plus Compose for the data plane only (see **Optional: Just recipes** below and `.planning/research/LOCAL-DX-AUDIT.md`). **Phase 21** adds an **optional** [`.devcontainer/`](.devcontainer/) path (same Compose data plane; BEAM may run inside the container) — see **Optional: Dev Container** below. No Compose-hosted Kiln `app` service is required for either path.

1. **Environment** — `cp .env.sample .env` then load it (`direnv allow` or export vars manually). See **Environment** below for required keys.
2. **Database** — `docker compose up -d db` and wait until Postgres is healthy.
3. **Migrations (owner role)** — `KILN_DB_ROLE=kiln_owner mix setup` (runs `ecto.create`, `ecto.migrate`, seeds, assets). Runtime sessions use the restricted `kiln_app` role by default.
4. **Run the app** — `mix phx.server`.
5. **Open the app** — `http://localhost:4000/onboarding` for the demo-first orientation, then `http://localhost:4000/settings` before your first real live run. `/settings` is the authoritative readiness checklist and remediation surface for local live mode.

### Digital Twin / sandbox mocks (DTU)

Sandbox stages talk to **DTU** (mock HTTP) on Compose’s internal **`kiln-sandbox`** network (`internal: true` in `compose.yaml` — no egress to the public internet from that bridge). The quick start above only starts **Postgres** so you can reach the UI quickly.

**Before your first sandbox-backed stage**, start DTU and wait until it is healthy:

```bash
docker compose up -d dtu
docker compose ps dtu
```

See service definitions in [`compose.yaml`](compose.yaml) (`db`, `dtu`, `otel-collector`, `jaeger`). Optional **`sandbox-net-anchor`** profile exists for advanced local networking — not required for the default README path.

### Merge authority (CI)

Pull requests targeting **`main`** need green **[GitHub Actions](https://github.com/szTheory/kiln/actions/workflows/ci.yml)**. Full tier table, boot checks, integration smoke, and optional local commands: [`.planning/PROJECT.md#merge-authority`](.planning/PROJECT.md#merge-authority). Local `mix check` may read **PARTIAL** vs CI when Postgres, Docker, Dialyzer PLTs, or env differ — see [`.planning/phases/12-local-docker-dx/12-01-SUMMARY.md`](.planning/phases/12-local-docker-dx/12-01-SUMMARY.md).

### Other useful URLs

- `http://localhost:4000/ops/dashboard` — Phoenix LiveDashboard
- `http://localhost:4000/ops/oban` — Oban.Web
- `http://localhost:4000/health` — JSON health probe (Plan 06 contract)

## Operator checklist

Use this as a **cold-clone** sanity pass (order matches the happy path above):

- [ ] **Tooling** — Elixir/OTP per [`.tool-versions`](.tool-versions), Docker with Compose v2, `mix` on `PATH` (see **Prerequisites**).
- [ ] **Secrets file** — `cp .env.sample .env`; fill at least `SECRET_KEY_BASE`, `DATABASE_URL`, `PORT` / `PHX_HOST` as in **Environment** below.
- [ ] **Database** — `docker compose up -d db`; Postgres shows **healthy** in `docker compose ps`.
- [ ] **Port 5432** — If another Postgres or container holds host `5432`, set **`KILN_DB_HOST_PORT`** (e.g. `5434`) in `.env` and point **`DATABASE_URL`** at the same host port; see **`.env.sample`** (see [`test/integration/first_run.sh`](test/integration/first_run.sh) error text).
- [ ] **Migrations** — `KILN_DB_ROLE=kiln_owner mix setup` once (creates DB if needed, migrates, seeds, assets). Day-to-day runs leave `KILN_DB_ROLE` unset (`kiln_app`).
- [ ] **App** — `mix phx.server` without `KILN_SKIP_BOOTCHECKS` (BootChecks must pass).
- [ ] **Orientation** — Open `/onboarding` first if you want the demo-first tour and scenario framing.
- [ ] **Live readiness** — Open `/settings` before any real local live attempt; this is the canonical checklist for provider refs, `gh auth`, and Docker readiness.
- [ ] **Sandbox work** — Before stages that hit mocks: `docker compose up -d dtu` (subsection above).
- [ ] **Machine smoke (optional)** — `bash test/integration/first_run.sh` or `mix integration.first_run` — DB + migrate + boot + `/health` JSON (does not prove browser onboarding).
- [ ] **Traces (optional)** — See **Traces (local)**; set `OTEL_EXPORTER_OTLP_ENDPOINT` only when collector/Jaeger are up.

**Why Compose does not start Kiln:** shipped layout is **Postgres + DTU (+ optional OTel) in Compose**, **Phoenix on the host** — see [`.planning/research/LOCAL-DX-AUDIT.md`](.planning/research/LOCAL-DX-AUDIT.md). Optional **`just`** orchestration lives in the repo root **`justfile`** (same contracts as this checklist).

**Longer-form operator docs** (architecture, configuration) live in the Starlight site — [Operator docs](https://szTheory.github.io/kiln/docs/) — built from `site/` per **Documentation** above.

## Optional: Dev Container (minimal host installs)

Use this when you want a **reproducible Linux toolchain** inside Docker and are fine with **bind-mount + volume** tradeoffs (often slower file sync than host Phoenix — prefer **Docker Desktop VirtioFS** or the fastest file-sharing mode your engine offers; if live reload misbehaves, run **`mix phx.server` on the host** instead).

**Prerequisites:** Docker Desktop or Colima with the Compose v2 plugin, the **Dev Containers** extension (VS Code / compatible editors), and the same **`.env`** contract as the host path (`cp .env.sample .env`).

**Same logical sequence as the quick start** (only **where BEAM runs** changes):

1. On the **host**, bring up the data plane: `docker compose up -d db` (add `dtu` before any sandbox-backed stage: `docker compose up -d dtu`).
2. **Open the repo in the dev container** (see [`.devcontainer/`](.devcontainer/) — image pin matches `.tool-versions`).
3. Inside the container: `KILN_DB_ROLE=kiln_owner mix setup` (Postgres must be reachable; on macOS Docker Desktop the default `DATABASE_URL` in the devcontainer uses **`host.docker.internal`** as the DB host). **Colima / Podman:** set `DOCKER_HOST` to your engine’s socket (see your engine docs); keep **`kiln-sandbox` + `dtu` on the same daemon** Kiln targets or you will see “network not found” / unreachable DTU.
4. **`KILN_DEV_BIND_ALL=1`** is preset in the devcontainer so Bandit listens on **`0.0.0.0`** and **`http://localhost:4000`** from the host reaches the app.
5. Run **`mix phx.server`**, then open **`http://localhost:4000/onboarding`** (same as host).

**DooD (Docker outside of Docker):** the **orchestrator** may talk to the **host** Docker daemon (`DOCKER_HOST` or a socket visible only to the devcontainer) so `System.cmd("docker", …)` and DTU-backed sandboxes keep using **`kiln-sandbox`** on that daemon. **Never** mount the Docker socket (or inject `DOCKER_HOST`) into **Kiln-spawned stage/sandbox** containers — sandboxes stay isolated per `CLAUDE.md`.

## Optional: Just recipes (local orchestration)

If you use [**just**](https://github.com/casey/just#installation) (`brew install just` on macOS), the checked-in **`justfile`** wraps the same **Compose + setup** primitives as the numbered quick start above. **`just dev`** runs **`script/dev_up.sh`** (Postgres + **`mix setup`** + **`mix phx.server`** in one foreground process). Other recipes still assume **Phoenix on the host** unless you use **`just dev`**.

| Command | What it runs |
|---------|----------------|
| `just dev` | **`script/dev_up.sh`** — Postgres + **`mix setup`** + **`mix phx.server`** (foreground) |
| `just db-up` | `docker compose up -d db` |
| `just dtu-up` | `docker compose up -d dtu` |
| `just otel-up` | `docker compose up -d otel-collector jaeger` (see **Traces (local)**) |
| `just setup` | `KILN_DB_ROLE=kiln_owner mix setup` |
| `just smoke` | `bash test/integration/first_run.sh` (same SSOT as **Integration smoke**) |
| `just dev-deps` | `db-up`, then prints a one-line reminder to start **`mix phx.server`** in another shell |
| `just planning-gates` | `script/planning_gates.sh` — CI-parity **`mix check`** only (defaults match `.github/workflows/ci.yml`; Postgres must be reachable) |
| `just shift-left` | `script/shift_left_verify.sh` — **`mix check`**, **`test/integration/first_run.sh`**, then **`mix kiln.e2e`** (full local mirror of CI acceptance) |
| `just precommit` | `script/precommit.sh` — same env defaults as CI when `.env` is missing; then **`mix precommit`** (`templates.verify` + `mix check`) |
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
| `bash test/integration/first_run.sh` / `mix integration.first_run` | N/A | Yes (`integration-smoke` job) |
| `mix kiln.e2e` / `mix shift_left.verify` UI path | N/A | Yes (`e2e` job; local `shift-left` mirrors CI) |

## Traces (local, OBS-02)

With the stack running:

```bash
docker compose up -d otel-collector jaeger
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
mix phx.server
```

Open Jaeger UI at `http://localhost:16686`. Omit `OTEL_EXPORTER_OTLP_ENDPOINT` to keep the SDK in noop mode.

## Remote access (Phase 36)

Kiln's remote profile keeps the dashboard private over Tailscale and leaves the default local compose path unchanged.

1. Create a Tailscale auth key in the admin console.
2. Put it in `.env` as `TS_AUTHKEY` (see `.env.sample`).
3. Start your host Phoenix app as usual (`mix phx.server`).
4. Start the tunnel sidecar:

```bash
docker compose --profile remote up -d tailscale
```

By default the sidecar serves `http://host.docker.internal:4000` on your tailnet MagicDNS name. If you run Kiln on a different local port, set `TAILSCALE_TUNNEL_TARGET` in `.env` before starting the remote profile.

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

## Integration & e2e

Three layers of UI verification ship in CI on every PR. For UI flows covered here, this stack is the acceptance oracle; routine human UAT is not part of phase closure:

1. **`mix check`** — includes `test/kiln_web/live/route_smoke_test.exs` (every LiveView route boots + no retired Phase-reskin tokens in rendered HTML) and `mix kiln.ui.lint` (static grep gate on `lib/kiln_web/**` and `assets/css/app.css`).
2. **`bash test/integration/first_run.sh`** — Compose DB + host Phoenix + `/health` contract.
3. **`mix kiln.e2e`** — Playwright: all 14 LiveView routes x light/dark x mobile/desktop + axe-core a11y. Runs locally against the same boot script CI uses.

Local one-liners:

```bash
mix shift_left.verify   # steps 1 + 2 + 3
just shift-left         # same, Just recipe
just e2e                # just the Playwright step (boots Phoenix for you)
just e2e-ui             # Playwright watch UI
```

Env escape hatches: `SHIFT_LEFT_SKIP_INTEGRATION=1` (step 1 only), `SHIFT_LEFT_SKIP_E2E=1` (steps 1+2).

Use `$gsd-verify-work` only for typed exceptions the automation cannot cover yet: first-time auth, credentials, budget approvals, third-party blockers, or other explicitly documented human-only checks.

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
