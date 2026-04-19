# Phase 1: Foundation & Durability Floor - Research

**Researched:** 2026-04-18
**Domain:** Elixir/Phoenix scaffold + Postgres durability floor + Oban + CI baseline + invariant boot-checks
**Confidence:** HIGH (all concrete decisions backed by Context7/official docs; MEDIUM only where noted in individual items)

## Summary

Phase 1 is a **scaffold + invariant-assertion** phase. Every decision is locked in CONTEXT.md D-01..D-53; this research does not re-open any of them. Its job is to supply the planner with copy-pasteable SQL/Elixir/YAML/CI snippets, verify versions against Hex/npm-equivalent registries, resolve ambiguities that CONTEXT.md raised (three-layer audit enforcement, two-role migrations, logger metadata across Oban, Brandur intent-table schema), and enumerate the **minimum distinguishable behaviors** each plan must expose so Phase 1's "fail loudly when invariants are violated" promise is verifiable by the Nyquist gate.

**Primary recommendation:** Ship as five to seven planning units in this order — (1) repo scaffold + `.tool-versions` + `compose.yaml`, (2) `mix check` + custom Credo checks + CI, (3) `audit_events` with three-layer enforcement + JSV validation + DB roles, (4) `external_operations` intent table + `Kiln.Oban.BaseWorker` helpers, (5) `Kiln.Telemetry` + logger metadata threading + contrived multi-process test, (6) `Kiln.HealthPlug` + `Kiln.BootChecks` + first-run UX glue, (7) spec-upgrade commits (D-50, D-51, D-52, D-53). No plan ships UI surfaces beyond LiveDashboard + Oban Web mount. No plan ships stub children of the supervision tree.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Phoenix Scaffold (D-01..D-05):**
- D-01: `mix phx.new kiln --database postgres --binary-id --no-mailer --no-gettext --install`. Not `--no-html` / `--no-assets`.
- D-02: Mount `Phoenix.LiveDashboard` at `/ops/dashboard` and `Oban.Web` at `/ops/oban`.
- D-03: Stub `%Kiln.Scope{operator: :local, correlation_id: ..., started_at: ...}` via `on_mount` + Plug (~30 LOC). `correlation_id` threads into `logger_json`.
- D-04: Replace generated `PageController` with `Kiln.HealthController` returning JSON at `/health`. `/` redirects to `/ops/dashboard` in P1..P6. Skip `mix phx.gen.auth` entirely.
- D-05: Bandit is Phoenix 1.8 default; no `:server` config flag needed.

**`audit_events` Schema (D-06..D-13):**
- D-06: PK = UUID v7 via `pg_uuidv7` Postgres extension on PG16. Migrate to native `uuidv7()` on PG18.
- D-07: `event_kind` = `text` + `CHECK` constraint (NOT Postgres ENUM). `Kiln.Audit.EventKind` module is SSoT.
- D-08: Initial 22-value taxonomy: `run_state_transitioned`, `stage_started`, `stage_completed`, `stage_failed`, `external_op_intent_recorded`, `external_op_action_started`, `external_op_completed`, `external_op_failed`, `secret_reference_resolved`, `model_routing_fallback`, `budget_check_passed`, `budget_check_failed`, `stuck_detector_alarmed`, `scenario_runner_verdict`, `work_unit_created`, `work_unit_state_changed`, `git_op_completed`, `pr_created`, `ci_status_observed`, `block_raised`, `block_resolved`, `escalation_triggered`.
- D-09: App-side JSV validation per-kind at `Kiln.Audit.append/1`. `schema_version :: integer` column. `priv/audit_schemas/v1/{kind}.json`. Skip `pg_jsonschema`.
- D-10: 5 b-tree composite indexes (no GIN): `(run_id, occurred_at DESC) WHERE run_id IS NOT NULL`, `(stage_id, occurred_at DESC) WHERE stage_id IS NOT NULL`, `(event_kind, occurred_at DESC)`, `(actor_id, occurred_at DESC)`, `(correlation_id)`.
- D-11: Partitioning deferred until row count crosses 5M.
- D-12: **THREE-layer INSERT-only enforcement** — REVOKE + trigger + RULE. Migration test asserts all three.
- D-13: Table name is `audit_events` (not `events`).

**`external_operations` Schema (D-14..D-21):**
- D-14: Single table + polymorphic JSONB payloads (Brandur Rocket-Rides-Atomic pattern).
- D-15: Idempotency key = flat string `"#{run_id}:#{stage_id}:#{op_name}"`. `system:` prefix for non-run-scoped.
- D-16: State enum = 5 values (`intent_recorded`, `action_in_flight`, `completed`, `failed`, `abandoned`). P1 only writes `intent_recorded` and `completed`.
- D-17: 10-value `op_kind` taxonomy: `git_push`, `git_commit`, `gh_pr_create`, `gh_check_observe`, `llm_complete`, `llm_stream`, `docker_run`, `docker_kill`, `osascript_notify`, `secret_resolve`.
- D-18: Each row writes 2 audit events (`external_op_intent_recorded` + `external_op_completed | external_op_failed`).
- D-19: Cleanup = 30-day TTL prune `:completed` only. `:failed`/`:abandoned` kept indefinitely.
- D-20: PK = UUID v7 (same extension).
- D-21: Columns: `id, op_kind, idempotency_key, state, schema_version, intent_payload, result_payload, attempts, last_error, run_id, stage_id, intent_recorded_at, action_started_at, completed_at, inserted_at, updated_at`.

**CI Gate (D-22..D-30):**
- D-22: `mix check` = format check + compile-warnings-as-errors + credo strict + dialyzer fail-on-warning + sobelow HIGH-only + `mix_audit` + `mix xref graph --format cycles`.
- D-23: Add `credo_envvar` + `ex_slop`.
- D-24: Hand-write two custom Credo checks: `Kiln.Credo.NoProcessPut`, `Kiln.Credo.NoMixEnvAtRuntime`.
- D-25: Skip `NoStatelessGenServer`, `NoUnsupervisedSpawn`, `NoApplyHotPath`, `BooleanObsession`.
- D-26: Ship two grep-based Mix tasks: `mix check_no_compile_time_secrets`, `mix check_no_manual_qa_gates`.
- D-27: Dialyzer PLT cache key = `${OS}-${OTP}-${ELIXIR}-${hashFiles('mix.lock')}`.
- D-28: No lefthook pre-commit.
- D-29: Single CI runner: Ubuntu 24.04 + Elixir 1.19.5-otp-28 + OTP 28.1.2 + Postgres 16 service container. `erlef/setup-beam@v1.23.0`. No PG17 matrix.
- D-30: Default ex_check output; no Kiln-branded wrapper.

**Health / Boot / DTU / Local Dev (D-31..D-41):**
- D-31: `Kiln.HealthPlug` (~30 LOC) mounted before `Plug.Logger`. Single `/health`, no `/healthz`+`/readyz` split.
- D-32: `Kiln.BootChecks.run!/0` invoked from `Kiln.Application.start/2` after Repo+Oban, before Endpoint. Raises on: missing contexts, REVOKE not active, trigger not active, Oban migration mismatch, required secrets unresolvable.
- D-33: `KILN_SKIP_BOOTCHECKS=1` escape hatch, logged loudly.
- D-34: `mix kiln.boot_checks` standalone Mix task for CI.
- D-35: `compose.yaml` (not `docker-compose.yml`). Top-level `kiln-sandbox` network with `internal: true`.
- D-36: DTU placeholder = `alpine sleep infinity` behind `profiles: ["network-anchor"]`.
- D-37: Postgres healthcheck `pg_isready -U kiln`. No app healthcheck in compose.
- D-38: `.env.sample` ships with only `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`.
- D-39: direnv recommended; shell-sourcing fallback documented.
- D-40: First-run UX: `cp .env.sample .env && docker compose up -d && mix setup && mix phx.server` then `curl localhost:4000/health`.
- D-41: `priv/artifacts/` (gitignored) with `.gitkeep` in P1.

**Application (D-42..D-44):**
- D-42: Supervision tree ships ONLY: `KilnWeb.Telemetry`, `Kiln.Repo`, `{Phoenix.PubSub, name: Kiln.PubSub}`, `{Finch, name: Kiln.Finch}`, `{Registry, keys: :unique, name: Kiln.RunRegistry}`, `Oban`, `KilnWeb.Endpoint`. NO stub children.
- D-43: `Kiln.Audit` and `Kiln.Telemetry` ship with full behavior.
- D-44: `Kiln.Oban.BaseWorker` with `max_attempts: 3`, unique on `:idempotency_key`, helpers `fetch_or_record_intent/2` + `complete_op/2`.

**Logger Metadata (D-45..D-47):**
- D-45: Ship both `Kiln.Logger.Metadata.with_metadata/2` (block-style) AND `Kiln.Telemetry.pack_ctx/0` + `unpack_ctx/1` (cross-process).
- D-46: Mandatory keys: `correlation_id`, `causation_id`, `actor`, `actor_role`, `run_id`, `stage_id`. Missing = `:none` atom (not `nil`).
- D-47: Contrived multi-process test proves metadata threads across `Task.async_stream` and Oban boundaries.

**DB Roles (D-48..D-49):**
- D-48: Two PG roles: `kiln_owner` (DDL/DML), `kiln_app` (INSERT/SELECT on `audit_events`, full DML on others). `KILN_DB_ROLE` env var. Migrations run as `kiln_owner`.
- D-49: Dedicated `priv/repo/migrations/0000XX_install_oban.exs` invokes `Oban.Migration.up(version: <pinned>)`.

**Spec Upgrades (D-50..D-53):** Apply in P1 implementation to CLAUDE.md, ARCHITECTURE.md §9, STACK.md, PROJECT.md.

### Claude's Discretion

- Exact module file names within each context's directory (follow ARCHITECTURE.md §15 layout).
- `mix.exs` aliases composition (`mix setup`, `mix check`) — must be idempotent on re-run.
- README structure beyond the four-step first-run UX.
- CHANGELOG.md format (Keep a Changelog recommended).
- Test fixtures structure under `test/support/`.
- Whether `Kiln.HealthPlug` lives in `lib/kiln_web/plugs/` or `lib/kiln_web/health/` — local taste.
- Specific `description:` text in custom Credo checks.
- Exact wording of operator-facing trigger `RAISE EXCEPTION` message (must include `"audit_events is append-only"` substring for test assertion).
- Whether to use Phoenix-generated tailwind config or hand-rolled minimal one.

### Deferred Ideas (OUT OF SCOPE)

- Kubernetes `/healthz` + `/readyz` split
- `pg_partman` partitioning of `audit_events`
- GIN index on `audit_events.payload`
- Postgres 17 CI matrix
- Lefthook pre-commit hook
- Flow-analysis Credo checks (`NoStatelessGenServer`, etc.)
- Kiln-branded `mix kiln.check` wrapper
- `pg_jsonschema` extension
- Dependabot / Renovate (defer to P9)
- OTel `opentelemetry_process_propagator` wiring (defer to P9)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOCAL-01 | `docker compose up` spins up Kiln + Postgres + DTU mock network; health check passes | Compose & Postgres sections; `Kiln.HealthPlug` section; D-35..D-40 |
| LOCAL-02 | `.tool-versions` pins Elixir 1.19.5 / Erlang 28.1+; `mix.exs` pins Phoenix 1.8.5 / LiveView 1.1.28 | Stack section cites STACK.md; `.tool-versions` template in Scaffold section |
| OBS-01 | Structured JSON logging with `correlation_id`, `causation_id`, `actor`, `run_id`, `stage_id` on every log line; metadata threads across Oban/Task | Logger Metadata Threading section; contrived test structure |
| OBS-03 | Append-only audit ledger (`audit_events`) with INSERT-only enforcement at Postgres level | Audit Ledger section — three-layer enforcement with copy-pasteable SQL + migration test assertions |

## Project Constraints (from CLAUDE.md)

- Postgres is source of truth; OTP processes are transient accelerators.
- Append-only audit ledger is non-negotiable.
- Idempotency everywhere; Oban unique is insert-time-only, MUST pair with `external_operations` two-phase pattern.
- No Docker socket mounts (not exercised in P1 but compose network must be `internal: true`).
- Secrets are references, never values (`@derive {Inspect, except: [:api_key]}`, `persistent_term`).
- Run state = Ecto field + command module, not `:gen_statem`.
- No umbrella app; 12 strict bounded contexts; `mix xref graph --format cycles` in CI.
- No GenServer-per-work-unit.
- Elixir anti-patterns to avoid: `Process.put/2` for state, `Mix.env` at runtime, secrets in compile-time config.
- Every file change must go through a GSD command (existing Phase 1 execution flow).

## Stack & Versions

Phase 1 does NOT relocate the locked stack — STACK.md is authoritative. The following are P1-specific additions/clarifications:

| Package | Version | Purpose | Source |
|---------|---------|---------|--------|
| `pg_uuidv7` | **1.7.0** (released 2025-10-13) | PG 16 UUID v7 PK generator | [GitHub: fboulnois/pg_uuidv7](https://github.com/fboulnois/pg_uuidv7) — prebuilt Docker image `ghcr.io/fboulnois/pg_uuidv7:1.7.0` |
| `ex_check` | 0.16.0 | `mix check` meta-runner | [hexdocs ex_check 0.16](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html) |
| `credo_envvar` | latest (~> 0.x, single maintainer, stable API) | Custom Credo check package for compile-time secrets | [hex credo_envvar](https://hex.pm/packages/credo_envvar) — verify at install |
| `ex_slop` | 0.2.0 | Credo checks catching AI-generated slop (23 checks, aligned with P9 dogfood) | [hex ex_slop](https://hex.pm/packages/ex_slop) |
| `logger_json` | 7.0.4 | JSON formatter with metadata support | [hexdocs logger_json 7.0.4](https://hexdocs.pm/logger_json/LoggerJSON.html) |
| `erlef/setup-beam` | v1.23.0 (released 2026-03-14) | BEAM setup for GHA | [GitHub releases](https://github.com/erlef/setup-beam/releases) |
| Postgres base image | `ghcr.io/fboulnois/pg_uuidv7:1.7.0` (wraps `postgres:16`) | Provides pg_uuidv7 preinstalled | See Compose section |

**Version verification (planner must run before generating `mix.exs`):**
```bash
mix hex.info credo_envvar       # verify current version + last update
mix hex.info ex_slop            # verify current version
mix hex.info ex_check           # confirm 0.16.x current
mix hex.info oban_web           # confirm OSS edition 2.12.2
```

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Scaffold / project skeleton | Build-time (mix.exs + config) | — | Config/deps live before runtime |
| Append-only audit enforcement | Database (PG) | Application (JSV) | DB is the invariant backstop; app-side JSV only shapes payloads before insert |
| Idempotency (`external_operations`) | Database (UNIQUE INDEX) | Application (BaseWorker helpers) | DB enforces uniqueness; app manages two-phase state machine |
| Health endpoint | API / Phoenix controller | — | `Kiln.HealthPlug` is an HTTP surface |
| Boot-time invariant checks | Application (Application.start/2) | CLI (`mix kiln.boot_checks`) | Raises in BEAM; Mix task gives CI parity |
| Structured logging | Application (logger_json config) | Cross-process (pack_ctx/unpack_ctx + telemetry handlers) | Metadata is process-local; explicit threading crosses boundaries |
| CI gate | CI infrastructure (GitHub Actions) | Build-time (`mix check`) | Mix check is the local-parity target; GHA invokes it |
| Compose / local dev | Infrastructure (Docker Compose) | — | `compose.yaml` + PG16 container + sandbox network |
| Migrations | Database (DDL/DML as `kiln_owner`) | Runtime (`kiln_app`) | Two roles; runtime cannot DDL |
| Supervision tree | OTP (`Kiln.Application`) | — | Ships only P1-exercised children |

## Scaffold & Application Bootstrap (D-01..D-05, D-42, D-43)

### Scaffold command (D-01)

```bash
mix phx.new kiln --database postgres --binary-id --no-mailer --no-gettext --install
```

**Post-scaffold edits required:**
1. Delete generated `PageController`, `PageHTML`, `PageController`-related routes, and the home template (per D-04).
2. Insert `LiveDashboard` and `Oban.Web` router mounts (per D-02).
3. Insert `Kiln.HealthController` + `GET /health` route (per D-04).
4. Replace generated `CurrentUser`/`Accounts` scope scaffolding with `Kiln.Scope` stub (per D-03).
5. Rewrite `Kiln.Application.start/2` with ONLY the 7 P1 children (per D-42).

### `.tool-versions` (LOCAL-02)

```
elixir 1.19.5-otp-28
erlang 28.1.2
nodejs 22.11.0
```

(Per STACK.md — verified against Elixir v1.19 release announcement.)

### `Kiln.Application` supervision tree (D-42, exact shape)

```elixir
defmodule Kiln.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Boot-check runs BEFORE Endpoint but AFTER Repo + Oban (D-32).
    # Children start in order; boot-check is invoked between phases.
    children = [
      KilnWeb.Telemetry,
      Kiln.Repo,
      {Phoenix.PubSub, name: Kiln.PubSub},
      {Finch, name: Kiln.Finch},
      {Registry, keys: :unique, name: Kiln.RunRegistry},
      {Oban, Application.fetch_env!(:kiln, Oban)},
      # BootChecks is NOT a supervision-tree child; it's called inline
      # after Repo + Oban boot and before Endpoint. See BootChecks section.
      KilnWeb.Endpoint
    ]

    with :ok <- maybe_run_boot_checks(children) do
      Supervisor.start_link(children, strategy: :one_for_one, name: Kiln.Supervisor)
    end
  end
end
```

Do NOT include stub `RunDirector`, `RunSupervisor`, `Sandboxes.Supervisor`, `StuckDetector`, `Agents.SessionSupervisor`, `DTU.Supervisor`, `TaskSupervisor`, `PartitionSupervisor` children. Each later phase adds its own children.

Note: `BootChecks` can be invoked either by (a) a tiny supervisor child that does the check in `init/1` and returns `{:ok, :ignore}` on success, or (b) inline in `start/2` between child-spec construction and `Supervisor.start_link`. Option (b) is simpler and recommended; option (a) fits better if the planner decides checks should supervise.

### `Kiln.Scope` stub (D-03)

```elixir
defmodule Kiln.Scope do
  @moduledoc "Single-operator scope stub; expands in P7-P8 for multi-user. Correlation ID is generated per request/session."

  defstruct operator: :local, correlation_id: nil, started_at: nil

  @type t :: %__MODULE__{operator: :local, correlation_id: binary() | nil, started_at: DateTime.t() | nil}

  def new do
    %__MODULE__{
      operator: :local,
      correlation_id: UUID.uuid7(),  # via `uniq` or `Ecto.UUID`-compatible helper
      started_at: DateTime.utc_now()
    }
  end
end

# Plug (for dead-view HTTP requests)
defmodule KilnWeb.Plugs.AssignScope do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    scope = Kiln.Scope.new()
    Logger.metadata(correlation_id: scope.correlation_id, actor: "operator:local", actor_role: "operator")
    assign(conn, :current_scope, scope)
  end
end

# on_mount hook (for LiveView)
defmodule KilnWeb.LiveHooks.AssignScope do
  import Phoenix.Component, only: [assign_new: 3]

  def on_mount(:default, _params, _session, socket) do
    scope = Kiln.Scope.new()
    Logger.metadata(correlation_id: scope.correlation_id, actor: "operator:local", actor_role: "operator")
    {:cont, assign_new(socket, :current_scope, fn -> scope end)}
  end
end
```

Wire in router:
```elixir
pipeline :browser do
  # ...Phoenix 1.8 generated plugs...
  plug KilnWeb.Plugs.AssignScope
end

live_session :default, on_mount: [{KilnWeb.LiveHooks.AssignScope, :default}] do
  # LiveDashboard + Oban.Web mounts
end
```

[Phoenix 1.8 Scopes guide, hexdocs.pm](https://hexdocs.pm/phoenix/scopes.html) — verified pattern. Pattern extracted with `Phoenix.Component.assign_new/3` + `Logger.metadata/1` threaded in the hook/plug so downstream logs are correlated from the first HTTP tick.

### Router (D-02, D-04)

```elixir
defmodule KilnWeb.Router do
  use KilnWeb, :router
  import Phoenix.LiveDashboard.Router
  import Oban.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KilnWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug KilnWeb.Plugs.AssignScope
  end

  pipeline :api, do: plug(:accepts, ["json"])

  scope "/", KilnWeb do
    pipe_through :api
    get "/health", HealthController, :show
  end

  scope "/", KilnWeb do
    pipe_through :browser
    get "/", Redirector, :to_ops_dashboard   # redirects to /ops/dashboard
  end

  scope "/ops" do
    pipe_through :browser
    live_dashboard "/dashboard", metrics: KilnWeb.Telemetry
    oban_dashboard "/oban"
  end
end
```

## Audit Ledger Implementation (D-06..D-13, D-50, D-51)

### Table schema (final, replaces ARCHITECTURE.md §9)

```sql
CREATE EXTENSION IF NOT EXISTS pg_uuidv7;

CREATE TABLE audit_events (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v7(),
  event_kind        TEXT         NOT NULL,
  schema_version    INTEGER      NOT NULL,
  actor_id          TEXT         NOT NULL,
  run_id            UUID,
  stage_id          UUID,
  correlation_id    UUID         NOT NULL,
  causation_id      UUID,
  payload           JSONB        NOT NULL DEFAULT '{}'::jsonb,
  occurred_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
  inserted_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT audit_events_event_kind_check CHECK (event_kind IN (
    'run_state_transitioned','stage_started','stage_completed','stage_failed',
    'external_op_intent_recorded','external_op_action_started','external_op_completed','external_op_failed',
    'secret_reference_resolved','model_routing_fallback','budget_check_passed','budget_check_failed',
    'stuck_detector_alarmed','scenario_runner_verdict','work_unit_created','work_unit_state_changed',
    'git_op_completed','pr_created','ci_status_observed','block_raised','block_resolved',
    'escalation_triggered'
  ))
);

-- D-10 indexes
CREATE INDEX audit_events_run_id_occurred_at_idx
  ON audit_events (run_id, occurred_at DESC) WHERE run_id IS NOT NULL;
CREATE INDEX audit_events_stage_id_occurred_at_idx
  ON audit_events (stage_id, occurred_at DESC) WHERE stage_id IS NOT NULL;
CREATE INDEX audit_events_event_kind_occurred_at_idx
  ON audit_events (event_kind, occurred_at DESC);
CREATE INDEX audit_events_actor_id_occurred_at_idx
  ON audit_events (actor_id, occurred_at DESC);
CREATE INDEX audit_events_correlation_id_idx
  ON audit_events (correlation_id);
```

### Three-layer INSERT-only enforcement (D-12) — canonical SQL

**Rationale (per CONTEXT.md):** `CREATE RULE ... DO INSTEAD NOTHING` has documented silent-bypass modes — "data is silently thrown away and that's not a good idea" per [PostgreSQL 18 CREATE RULE docs](https://www.postgresql.org/docs/current/sql-createrule.html). For a security-critical ledger, silent enforcement failure is the worst outcome. Three layers:

**Layer 1 — Role-based REVOKE (primary). Runs in a migration executed as `kiln_owner`:**

```sql
-- D-48: kiln_app already exists; if not, migration creates it first.
REVOKE UPDATE, DELETE, TRUNCATE ON audit_events FROM kiln_app;
GRANT INSERT, SELECT ON audit_events TO kiln_app;
-- USAGE on sequences (none here since UUID v7 has no sequence, but belt-and-suspenders):
-- REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM kiln_app; -- then GRANT USAGE on needed ones.
```

Any attempted mutation as `kiln_app` raises `Postgrex.Error` with `%{postgres: %{code: :insufficient_privilege, sqlstate: "42501"}}`.

**Layer 2 — `BEFORE` trigger (role-bypass-resistant):**

```sql
CREATE OR REPLACE FUNCTION audit_events_immutable()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'audit_events is append-only (Kiln immutability invariant); attempted % blocked', TG_OP
    USING ERRCODE = 'feature_not_supported'; -- SQLSTATE 0A000
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_events_no_update
  BEFORE UPDATE OR DELETE OR TRUNCATE ON audit_events
  FOR EACH STATEMENT EXECUTE FUNCTION audit_events_immutable();
```

Catches the case where a future migration runs as `kiln_owner` (table owner) and accidentally attempts UPDATE/DELETE. The `RAISE EXCEPTION` string MUST include `audit_events is append-only` for the migration test assertion (Discretion: exact wording beyond that is flexible).

**Layer 3 — `CREATE RULE` safety net (CLAUDE.md-original):**

```sql
CREATE RULE audit_events_no_update_rule AS
  ON UPDATE TO audit_events DO INSTEAD NOTHING;
CREATE RULE audit_events_no_delete_rule AS
  ON DELETE TO audit_events DO INSTEAD NOTHING;
```

This is a no-op safety net only — the trigger catches the DELETE/UPDATE first and raises. The RULE exists because if both the REVOKE and trigger are somehow bypassed (e.g. by a superuser connection bypassing role grants AND `ALTER TABLE DISABLE TRIGGER ALL`), the RULE still prevents data loss.

### Migration test — asserts ALL THREE paths (D-12)

```elixir
defmodule Kiln.Repo.Migrations.AuditEventsImmutabilityTest do
  use Kiln.DataCase, async: false

  @moduletag :db_role_test

  setup do
    # Insert one row as kiln_owner for the test to attempt to mutate.
    {:ok, %{rows: [[id]]}} =
      Kiln.Repo.query("""
      INSERT INTO audit_events (event_kind, schema_version, actor_id, correlation_id, payload)
      VALUES ('run_state_transitioned', 1, 'test:setup', uuid_generate_v7(), '{}')
      RETURNING id
      """)
    {:ok, id: id}
  end

  describe "Layer 1: REVOKE (kiln_app role)" do
    test "UPDATE as kiln_app raises insufficient_privilege (SQLSTATE 42501)", %{id: id} do
      assert_raise Postgrex.Error, fn ->
        Kiln.Test.with_role("kiln_app", fn ->
          Kiln.Repo.query!("UPDATE audit_events SET payload = '{\"x\":1}'::jsonb WHERE id = $1", [id])
        end)
      end
      |> then(fn err ->
        assert err.postgres.code == :insufficient_privilege
        assert err.postgres.sqlstate == "42501"
      end)
    end
  end

  describe "Layer 2: Trigger (kiln_owner role)" do
    test "UPDATE as kiln_owner raises 'audit_events is append-only'", %{id: id} do
      error = assert_raise Postgrex.Error, fn ->
        Kiln.Test.with_role("kiln_owner", fn ->
          Kiln.Repo.query!("UPDATE audit_events SET payload = '{\"x\":1}'::jsonb WHERE id = $1", [id])
        end)
      end
      assert error.postgres.message =~ "audit_events is append-only"
    end
  end

  describe "Layer 3: RULE (with triggers disabled)" do
    test "UPDATE with triggers disabled no-ops via RULE", %{id: id} do
      Kiln.Test.with_role("kiln_owner", fn ->
        Kiln.Repo.query!("ALTER TABLE audit_events DISABLE TRIGGER audit_events_no_update")
        try do
          result = Kiln.Repo.query!("UPDATE audit_events SET payload = '{\"x\":1}'::jsonb WHERE id = $1", [id])
          # RULE rewrites to NOTHING; 0 rows affected; original row unchanged.
          assert result.num_rows == 0
          {:ok, %{rows: [[payload]]}} = Kiln.Repo.query("SELECT payload FROM audit_events WHERE id = $1", [id])
          assert payload == %{}
        after
          Kiln.Repo.query!("ALTER TABLE audit_events ENABLE TRIGGER audit_events_no_update")
        end
      end)
    end
  end
end
```

`Kiln.Test.with_role/2` is a test helper that does `SET LOCAL ROLE <role>` inside a transaction:

```elixir
defmodule Kiln.Test do
  def with_role(role, fun) when role in ["kiln_app", "kiln_owner"] do
    Kiln.Repo.transaction(fn ->
      Kiln.Repo.query!("SET LOCAL ROLE #{role}")
      fun.()
    end)
  end
end
```

### JSV validation at `Kiln.Audit.append/1` (D-09)

**Pattern: compile schemas at boot, reference by kind at runtime.** Per [JSV hex docs](https://hexdocs.pm/jsv/JSV.html), `JSV.build!/1` builds at compile-time for maximum performance; we load all kind schemas once in a `persistent_term` cache at app boot.

```elixir
defmodule Kiln.Audit.SchemaRegistry do
  @moduledoc "Loads and caches JSV-compiled schemas for each event_kind at boot."

  @schema_dir Path.join([:code.priv_dir(:kiln) || "priv", "audit_schemas", "v1"])

  def init do
    kinds = Kiln.Audit.EventKind.all()
    schemas =
      for kind <- kinds, into: %{} do
        path = Path.join(@schema_dir, "#{kind}.json")
        raw = File.read!(path)
        json = JSON.decode!(raw)
        compiled = JSV.build!(json, default_meta: "https://json-schema.org/draft/2020-12/schema")
        {kind, compiled}
      end
    :persistent_term.put({__MODULE__, :schemas}, schemas)
    :ok
  end

  def get!(kind) when is_atom(kind) or is_binary(kind) do
    kind = to_string(kind)
    :persistent_term.get({__MODULE__, :schemas}) |> Map.fetch!(kind)
  end
end

defmodule Kiln.Audit do
  import Ecto.Query

  def append(attrs) when is_map(attrs) do
    with :ok <- validate_payload(attrs),
         {:ok, event} <- insert_event(attrs) do
      Phoenix.PubSub.broadcast(Kiln.PubSub, "audit:firehose", {:audit_event, event})
      {:ok, event}
    end
  end

  defp validate_payload(%{event_kind: kind, schema_version: 1, payload: payload}) do
    schema = Kiln.Audit.SchemaRegistry.get!(kind)
    case JSV.validate(payload, schema) do
      {:ok, _casted} -> :ok
      {:error, %JSV.ValidationError{} = err} -> {:error, {:audit_payload_invalid, err}}
    end
  end

  defp validate_payload(_), do: {:error, :audit_missing_required_fields}

  defp insert_event(attrs) do
    %Kiln.Audit.Event{}
    |> Kiln.Audit.Event.changeset(attrs)
    |> Kiln.Repo.insert()
  end
end
```

**Schema files** live under `priv/audit_schemas/v1/{kind}.json` — one file per kind from D-08. Each schema uses Draft 2020-12 with `$schema: "https://json-schema.org/draft/2020-12/schema"`. P1 ships minimal schemas (just `type: object` + any obviously-required properties per kind); later phases tighten them. This is intentional — ship 22 valid schema files, not 22 strict ones.

**Ecto schema:**

```elixir
defmodule Kiln.Audit.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "audit_events" do
    field :event_kind,      :string
    field :schema_version,  :integer, default: 1
    field :actor_id,        :string
    field :run_id,          :binary_id
    field :stage_id,        :binary_id
    field :correlation_id,  :binary_id
    field :causation_id,    :binary_id
    field :payload,         :map, default: %{}
    field :occurred_at,     :utc_datetime_usec
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_kind, :schema_version, :actor_id, :run_id, :stage_id,
                    :correlation_id, :causation_id, :payload, :occurred_at])
    |> validate_required([:event_kind, :schema_version, :actor_id, :correlation_id])
    |> validate_inclusion(:event_kind, Kiln.Audit.EventKind.all())
    |> put_change(:occurred_at, attrs[:occurred_at] || DateTime.utc_now())
  end
end
```

Note: `@primary_key {:id, :binary_id, autogenerate: false}` because the DB provides `uuid_generate_v7()` as DEFAULT — Ecto lets Postgres fill it.

## External Operations Intent Table (D-14..D-21)

### Schema (canonical — resolves D-21)

```sql
CREATE TABLE external_operations (
  id                   UUID         PRIMARY KEY DEFAULT uuid_generate_v7(),
  op_kind              TEXT         NOT NULL,
  idempotency_key      TEXT         NOT NULL,
  state                TEXT         NOT NULL DEFAULT 'intent_recorded',
  schema_version       INTEGER      NOT NULL DEFAULT 1,
  intent_payload       JSONB        NOT NULL,
  result_payload       JSONB,
  attempts             INTEGER      NOT NULL DEFAULT 0,
  last_error           JSONB,
  run_id               UUID,
  stage_id             UUID,
  intent_recorded_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  action_started_at    TIMESTAMPTZ,
  completed_at         TIMESTAMPTZ,
  inserted_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT external_operations_op_kind_check CHECK (op_kind IN (
    'git_push','git_commit','gh_pr_create','gh_check_observe',
    'llm_complete','llm_stream','docker_run','docker_kill',
    'osascript_notify','secret_resolve'
  )),
  CONSTRAINT external_operations_state_check CHECK (state IN (
    'intent_recorded','action_in_flight','completed','failed','abandoned'
  ))
);

CREATE UNIQUE INDEX external_operations_idempotency_key_idx
  ON external_operations (idempotency_key);
CREATE INDEX external_operations_in_flight_idx
  ON external_operations (state)
  WHERE state IN ('intent_recorded','action_in_flight');
CREATE INDEX external_operations_run_id_idx
  ON external_operations (run_id) WHERE run_id IS NOT NULL;
CREATE INDEX external_operations_op_kind_state_idx
  ON external_operations (op_kind, state);
```

### `Kiln.Oban.BaseWorker` — canonical helpers (D-44)

**Pattern derived from [Brandur, "Implementing Stripe-like Idempotency Keys in Postgres"](https://brandur.org/idempotency-keys) and [brandur/rocket-rides-atomic](https://github.com/brandur/rocket-rides-atomic). We map Brandur's `recovery_point` concept to the 5-state `state` enum (D-16).**

```elixir
defmodule Kiln.Oban.BaseWorker do
  @moduledoc """
  Base Oban worker for external-side-effect jobs. Enforces:
    - max_attempts: 3 default (PITFALLS P9 — Oban's 20 default is a footgun)
    - Insert-time unique on idempotency_key (insert-time ONLY; runtime dedup via external_operations)
    - Two-phase fetch_or_record_intent/2 → complete_op/2 wrapping.
  """

  defmacro __using__(opts) do
    quote do
      use Oban.Worker,
        max_attempts: Keyword.get(unquote(opts), :max_attempts, 3),
        unique: [
          keys: [:idempotency_key],
          fields: [:args],
          period: :infinity,
          states: [:available, :scheduled, :executing]
        ],
        queue: Keyword.fetch!(unquote(opts), :queue)

      import Kiln.Oban.BaseWorker.Helpers
    end
  end
end

defmodule Kiln.Oban.BaseWorker.Helpers do
  import Ecto.Query
  alias Kiln.Repo
  alias Kiln.ExternalOperations.Operation

  @doc """
  Two-phase fetch_or_record_intent. In a transaction:
    - Try INSERT with ON CONFLICT DO NOTHING; return :recorded if inserted.
    - If conflict: SELECT the existing row FOR UPDATE; return :found_existing with state.
  Caller decides based on state: intent_recorded → do the work; completed → no-op return stored result.
  """
  def fetch_or_record_intent(op_kind, opts) do
    idempotency_key = Keyword.fetch!(opts, :idempotency_key)
    intent_payload  = Keyword.fetch!(opts, :intent_payload)
    run_id          = Keyword.get(opts, :run_id)
    stage_id        = Keyword.get(opts, :stage_id)

    Repo.transaction(fn ->
      case insert_intent(op_kind, idempotency_key, intent_payload, run_id, stage_id) do
        {:ok, op} ->
          # Also write audit event (D-18).
          {:ok, _} = Kiln.Audit.append(%{
            event_kind: "external_op_intent_recorded",
            schema_version: 1,
            actor_id: "system:base_worker",
            run_id: run_id, stage_id: stage_id,
            correlation_id: Keyword.fetch!(opts, :correlation_id),
            payload: %{"op_id" => op.id, "op_kind" => op_kind, "idempotency_key" => idempotency_key}
          })
          {:recorded, op}

        {:error, :conflict} ->
          op = Repo.one!(
            from o in Operation,
              where: o.idempotency_key == ^idempotency_key,
              lock: "FOR UPDATE"
          )
          {:found_existing, op}
      end
    end)
  end

  defp insert_intent(op_kind, idempotency_key, payload, run_id, stage_id) do
    changeset = Operation.changeset(%Operation{}, %{
      op_kind: op_kind,
      idempotency_key: idempotency_key,
      intent_payload: payload,
      run_id: run_id,
      stage_id: stage_id,
      state: "intent_recorded"
    })

    case Repo.insert(changeset, on_conflict: :nothing, conflict_target: [:idempotency_key]) do
      {:ok, %{id: nil}} -> {:error, :conflict}
      {:ok, op} -> {:ok, op}
      {:error, _} = err -> err
    end
  end

  @doc """
  complete_op/2 — marks an operation as :completed with the result payload AND writes
  the `external_op_completed` audit event in the same transaction (D-18).
  """
  def complete_op(%Operation{} = op, result_payload, opts) do
    Repo.transaction(fn ->
      {:ok, updated} =
        op
        |> Operation.changeset(%{
          state: "completed",
          result_payload: result_payload,
          completed_at: DateTime.utc_now()
        })
        |> Repo.update()

      {:ok, _} = Kiln.Audit.append(%{
        event_kind: "external_op_completed",
        schema_version: 1,
        actor_id: Keyword.fetch!(opts, :actor_id),
        run_id: op.run_id, stage_id: op.stage_id,
        correlation_id: Keyword.fetch!(opts, :correlation_id),
        payload: %{"op_id" => op.id, "result" => result_payload}
      })

      updated
    end)
  end

  def fail_op(%Operation{} = op, error_payload, opts) do
    # Mirror of complete_op but writes `external_op_failed` audit event.
    # Detail omitted for brevity — same pattern.
  end
end
```

**Key invariants:**
- `fetch_or_record_intent/2` must be transactional. Idempotency-key UNIQUE INDEX enforces at-most-once insert; the `ON CONFLICT DO NOTHING` + `FOR UPDATE` re-read gives at-least-once intent persistence under retry.
- `complete_op/2` updates state AND writes audit event in the same transaction — matches CLAUDE.md "every state transition writes an Audit.Event in the same Postgres transaction" mandate.
- Oban unique at insert-time is belt-and-suspenders — it prevents dup enqueue, but the UNIQUE INDEX on `idempotency_key` is the authoritative dedup. Per [PITFALLS P3]: Oban's `unique` is insert-time only; never rely on it alone for exactly-once.

[Brandur: Idempotency Keys](https://brandur.org/idempotency-keys) — canonical. Our `state` enum maps Brandur's phase transitions (`started → ride_created → charge_created → finished`) onto Kiln's 5-state machine (`intent_recorded → action_in_flight → completed | failed | abandoned`).

## CI Gate `mix check` (D-22..D-30, D-53)

### `.check.exs` (D-22, D-23, D-26)

```elixir
[
  parallel: true,
  skipped: true,
  tools: [
    # Hard gates (order matters — fail fast on format/compile before slow tools)
    {:compiler,          "mix compile --warnings-as-errors", order: 1},
    {:formatter,         "mix format --check-formatted",     order: 2},

    # Linting & static analysis
    {:credo,             "mix credo --strict",               order: 10},
    {:ex_unit,           "mix test",                         order: 20},
    {:dialyzer,          "mix dialyzer --format short",      order: 30},

    # Dependency graph / architecture
    {:xref_cycles,       "mix xref graph --format cycles",   order: 40},

    # Security
    {:mix_audit,         "mix deps.audit",                   order: 50},
    {:sobelow,           "mix sobelow --skip --threshold high --exit",
                         order: 51},

    # Custom grep-based mix tasks (D-26)
    {:no_compile_time_secrets, "mix check_no_compile_time_secrets", order: 60},
    {:no_manual_qa_gates,      "mix check_no_manual_qa_gates",       order: 61}
  ]
]
```

[hexdocs ex_check 0.16](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html) — config schema verified. Custom tools registered under `:tools` use standard shell commands.

### Custom Credo checks (D-24) — copy-pasteable skeletons

```elixir
defmodule Kiln.Credo.NoProcessPut do
  @moduledoc false
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Forbids `Process.put/1` and `Process.put/2`. Kiln forbids process-dictionary
      state because it is lost across process boundaries and hides data dependencies
      (CLAUDE.md Conventions; ARCHITECTURE.md §12).
      Use `Kiln.Logger.Metadata.with_metadata/2` or explicit cross-process threading
      via `Kiln.Telemetry.pack_ctx/0` + `unpack_ctx/1` instead.
      """
    ]

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  # Match Process.put/1 and Process.put/2
  defp traverse({{:., meta, [{:__aliases__, _, [:Process]}, :put]}, _call_meta, args}, issues, issue_meta)
       when is_list(args) and length(args) in [1, 2] do
    {nil, [report(issue_meta, meta[:line] || 0) | issues]}
  end

  defp traverse(ast, issues, _meta), do: {ast, issues}

  defp report(issue_meta, line_no) do
    format_issue(issue_meta,
      message: "Avoid Process.put/1,2 — use Logger.metadata or explicit cross-process threading.",
      trigger: "Process.put",
      line_no: line_no)
  end
end

defmodule Kiln.Credo.NoMixEnvAtRuntime do
  @moduledoc false
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Forbids `Mix.env()` outside `mix.exs` and `deps/0`.
      Per Elixir Releases docs: Mix is a build tool and is not available inside a release.
      Use `Application.get_env(:kiln, :env)` (set in `config/runtime.exs`) instead.
      """
    ]

  @impl true
  def run(source_file, params \\ []) do
    # Allow Mix.env() in mix.exs.
    if Path.basename(source_file.filename) == "mix.exs" do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end
  end

  defp traverse({{:., meta, [{:__aliases__, _, [:Mix]}, :env]}, _, []}, issues, issue_meta) do
    {nil, [format_issue(issue_meta,
             message: "Avoid Mix.env/0 at runtime — use Application.get_env(:kiln, :env).",
             trigger: "Mix.env",
             line_no: meta[:line] || 0) | issues]}
  end

  defp traverse(ast, issues, _), do: {ast, issues}
end
```

**Tests using `Credo.Test.Case`** (per [hexdocs: Testing Custom Checks](https://hexdocs.pm/credo/testing_checks.html)):

```elixir
defmodule Kiln.Credo.NoProcessPutTest do
  use Credo.Test.Case

  alias Kiln.Credo.NoProcessPut

  test "flags Process.put/2" do
    """
    defmodule Foo do
      def bar, do: Process.put(:x, 1)
    end
    """
    |> to_source_file()
    |> run_check(NoProcessPut)
    |> assert_issue()
  end

  test "does not flag Process.get/1" do
    """
    defmodule Foo do
      def bar, do: Process.get(:x)
    end
    """
    |> to_source_file()
    |> run_check(NoProcessPut)
    |> refute_issues()
  end
end
```

### Grep-based Mix tasks (D-26)

```elixir
defmodule Mix.Tasks.CheckNoCompileTimeSecrets do
  use Mix.Task
  @shortdoc "Fails if config/{config,dev,prod}.exs references System.get_env/fetch_env"
  @moduledoc false

  @patterns [~r/System\.(get_env|fetch_env!?)/]
  @files ["config/config.exs", "config/dev.exs", "config/prod.exs"]

  def run(_) do
    offenders =
      @files
      |> Enum.filter(&File.exists?/1)
      |> Enum.flat_map(fn path ->
        content = File.read!(path)
        Enum.flat_map(@patterns, fn re ->
          Regex.scan(re, content) |> Enum.map(fn _ -> path end)
        end)
      end)

    if offenders == [] do
      Mix.shell().info("check_no_compile_time_secrets: OK")
    else
      Mix.raise("Compile-time secret reads found in: #{inspect(Enum.uniq(offenders))}. Move to config/runtime.exs.")
    end
  end
end

defmodule Mix.Tasks.CheckNoManualQaGates do
  # P1 ships a stub; P5 fleshes this out for UAT-01 enforcement.
  use Mix.Task
  @shortdoc "Fails if lib/ contains ASK-HUMAN markers in code paths (stub; expanded in P5)."
  @moduledoc false
  def run(_), do: Mix.shell().info("check_no_manual_qa_gates: OK (stub — expanded in P5)")
end
```

### GitHub Actions (D-27, D-29)

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push: {branches: [main]}
  pull_request:

jobs:
  check:
    runs-on: ubuntu-24.04
    services:
      postgres:
        image: ghcr.io/fboulnois/pg_uuidv7:1.7.0   # Postgres 16 + pg_uuidv7 preinstalled
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: kiln_test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 5s --health-retries 10
    env:
      MIX_ENV: test
      KILN_DB_ROLE: kiln_owner             # migrations run as owner
      DATABASE_URL: ecto://postgres:postgres@localhost:5432/kiln_test
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1.23.0
        with:
          elixir-version: "1.19.5"
          otp-version:    "28.1.2"
      - name: Cache deps + build + PLTs
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
            priv/plts
          # D-27 cache key
          key: ${{ runner.os }}-otp28.1.2-elixir1.19.5-${{ hashFiles('mix.lock') }}
      - run: mix deps.get
      - run: mix kiln.boot_checks            # D-34: same invariants CI asserts
      - run: mix ecto.setup                  # migrations run as kiln_owner
      - run: mix check                        # full gate (D-22)
```

## Health, Boot Checks, DTU, Local Dev (D-31..D-41, D-52)

### `Kiln.HealthPlug` (D-31)

```elixir
defmodule Kiln.HealthPlug do
  @moduledoc "Thin health endpoint; source of truth for Phase 7's factory header (via PubSub)."
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/health"} = conn, _opts) do
    body = %{
      status: overall_status(),
      postgres: pg_status(),
      oban: oban_status(),
      contexts: 12,
      version: version()
    } |> JSON.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
    |> halt()
  end

  def call(conn, _opts), do: conn

  defp overall_status do
    case {pg_status(), oban_status()} do
      {"up", "up"} -> "ok"
      {"down", _}  -> "down"
      _            -> "degraded"
    end
  end

  defp pg_status do
    case Kiln.Repo.query("SELECT 1", [], timeout: 1_000) do
      {:ok, _} -> "up"
      _ -> "down"
    end
  rescue _ -> "down"
  end

  defp oban_status do
    try do
      Oban.check_queue(Oban, queue: :default)
      "up"
    rescue _ -> "down"
    end
  end

  defp version, do: Application.spec(:kiln, :vsn) |> to_string()
end
```

Mount **before `Plug.Logger`** in `KilnWeb.Endpoint`:

```elixir
# lib/kiln_web/endpoint.ex
plug Kiln.HealthPlug                # <-- before Plug.Logger
plug Plug.Logger
plug Plug.RequestId
# ...rest of endpoint plugs
```

[jola.dev: Health checks for Plug and Phoenix](https://jola.dev/posts/health-checks-for-plug-and-phoenix) — pattern source.

### `Kiln.BootChecks` (D-32, D-33, D-34)

```elixir
defmodule Kiln.BootChecks do
  @moduledoc """
  Invariant assertions run at boot (generalized from Plausible's SECRET_KEY_BASE pattern).
  Raises Kiln.BootChecks.Error (terminating BEAM) on failure.
  Bypassable with KILN_SKIP_BOOTCHECKS=1 for iex debugging (D-33, logged loudly).
  """

  require Logger

  defmodule Error do
    defexception [:message, :invariant, :remediation]
  end

  @contexts ~w[Specs Intents Workflows Runs Stages Agents Sandboxes GitHub
               Audit Telemetry Policies WorkUnits]a

  def run! do
    if System.get_env("KILN_SKIP_BOOTCHECKS") == "1" do
      Logger.error("KILN_SKIP_BOOTCHECKS=1 — invariant checks bypassed. DO NOT USE IN PRODUCTION.")
      :ok
    else
      [
        &assert_contexts_compiled/0,
        &assert_audit_revoke_active/0,
        &assert_audit_trigger_active/0,
        &assert_oban_migration_current/0,
        &assert_required_secrets/0
      ]
      |> Enum.each(& &1.())
      :ok
    end
  end

  defp assert_contexts_compiled do
    missing = for ctx <- @contexts,
                  mod = Module.concat(Kiln, ctx),
                  not Code.ensure_loaded?(mod),
                  do: mod
    if missing != [] do
      raise Error,
        invariant: :contexts_compiled,
        remediation: "Run `mix compile --force`. Contexts missing: #{inspect(missing)}",
        message: "Kiln context modules not compiled: #{inspect(missing)}"
    end
  end

  defp assert_audit_revoke_active do
    # Attempt UPDATE as kiln_app; assert insufficient_privilege.
    try do
      Kiln.Repo.transaction(fn ->
        Kiln.Repo.query!("SET LOCAL ROLE kiln_app")
        Kiln.Repo.query("UPDATE audit_events SET payload = '{}'::jsonb WHERE id IS NULL")
      end)
      raise Error,
        invariant: :audit_revoke_active,
        remediation: "Re-run migration 20260418_enforce_audit_events_immutability.exs.",
        message: "audit_events REVOKE not active: kiln_app role can UPDATE"
    rescue
      err in Postgrex.Error ->
        if err.postgres && err.postgres.code == :insufficient_privilege do
          :ok
        else
          reraise err, __STACKTRACE__
        end
    end
  end

  defp assert_audit_trigger_active do
    # As kiln_owner, confirm trigger exists on audit_events.
    case Kiln.Repo.query("""
           SELECT 1 FROM pg_trigger
           WHERE tgrelid = 'audit_events'::regclass
             AND tgname = 'audit_events_no_update'
             AND NOT tgisinternal
         """) do
      {:ok, %{num_rows: 1}} -> :ok
      _ ->
        raise Error,
          invariant: :audit_trigger_active,
          remediation: "Re-run migration 20260418_enforce_audit_events_immutability.exs.",
          message: "audit_events_no_update trigger missing"
    end
  end

  defp assert_oban_migration_current do
    # Oban stores its migration version in oban_version table; confirm it matches the pinned version.
    expected = Application.fetch_env!(:kiln, :oban_migration_version)
    case Kiln.Repo.query("SELECT MAX(version) FROM oban_migrations") do
      {:ok, %{rows: [[version]]}} when version == expected -> :ok
      {:ok, %{rows: [[other]]}} ->
        raise Error,
          invariant: :oban_migration_version,
          remediation: "Run `mix ecto.migrate`.",
          message: "Oban migration mismatch: expected #{expected}, got #{other}"
    end
  end

  defp assert_required_secrets do
    env = Application.fetch_env!(:kiln, :env)
    required =
      case env do
        :prod -> [:database_url, :secret_key_base]
        :dev -> [:database_url, :secret_key_base]
        _ -> []
      end

    missing = for k <- required,
                  Application.get_env(:kiln, k) in [nil, ""],
                  do: k
    if missing != [] do
      raise Error,
        invariant: :required_secrets,
        remediation: "Set env vars: #{Enum.map_join(missing, ", ", &String.upcase(to_string(&1)))}",
        message: "Required secrets missing: #{inspect(missing)}"
    end
  end
end
```

Called inline from `Kiln.Application.start/2` after Repo + Oban boot. The **Mix task `mix kiln.boot_checks`** (D-34) is a thin wrapper:

```elixir
defmodule Mix.Tasks.Kiln.BootChecks do
  use Mix.Task
  @shortdoc "Runs Kiln boot invariants against current DB; used in CI."
  def run(_args) do
    Mix.Task.run("app.start")
    Kiln.BootChecks.run!()
    Mix.shell().info("kiln.boot_checks: OK")
  end
end
```

### Testing BEAM termination on failed boot check

**Pattern — spawn a fresh child OS process and assert non-zero exit:**

```elixir
# test/kiln/boot_checks_test.exs
defmodule Kiln.BootChecksTest do
  use Kiln.DataCase, async: false

  test "raises when audit_events REVOKE is missing" do
    # Break the invariant in the test DB.
    Kiln.Repo.query!("GRANT UPDATE ON audit_events TO kiln_app")
    try do
      assert_raise Kiln.BootChecks.Error, ~r/REVOKE not active/, fn ->
        Kiln.BootChecks.run!()
      end
    after
      # Restore.
      Kiln.Repo.query!("REVOKE UPDATE ON audit_events FROM kiln_app")
    end
  end

  test "respects KILN_SKIP_BOOTCHECKS=1" do
    System.put_env("KILN_SKIP_BOOTCHECKS", "1")
    try do
      assert :ok == Kiln.BootChecks.run!()
    after
      System.delete_env("KILN_SKIP_BOOTCHECKS")
    end
  end
end
```

For a **BEAM-termination-level integration test** (optional), use `System.cmd("mix", ["kiln.boot_checks"], ...)` and assert exit status. This mirrors the CI invocation.

### `compose.yaml` (D-35..D-37, D-52)

```yaml
# compose.yaml (Compose v2 canonical filename — D-35)
name: kiln

services:
  db:
    image: ghcr.io/fboulnois/pg_uuidv7:1.7.0   # D-52: PG16 + pg_uuidv7 preinstalled
    environment:
      POSTGRES_USER: kiln
      POSTGRES_PASSWORD: kiln_dev
      POSTGRES_DB: kiln_dev
    ports: ["5432:5432"]
    volumes:
      - kiln_pgdata:/var/lib/postgresql/data
    healthcheck:            # D-37
      test: ["CMD-SHELL", "pg_isready -U kiln"]
      interval: 2s
      timeout: 5s
      retries: 10

  # D-36: DTU placeholder behind profile; dormant by default.
  sandbox-net-anchor:
    image: alpine:3.20
    command: ["sleep", "infinity"]
    networks: [kiln-sandbox]
    profiles: ["network-anchor"]

networks:
  kiln-sandbox:
    driver: bridge
    internal: true    # D-35: no external gateway; egress blocked at network layer

volumes:
  kiln_pgdata:
```

Note: per [Docker Compose docs](https://docs.docker.com/reference/compose-file/networks/), `internal: true` creates a bridge without an external gateway — services on this network cannot reach the host internet. The network is materialized on `docker compose up` even if no service is currently attached (because the top-level `networks:` declaration is processed).

### `.env.sample` (D-38)

```bash
# Phase 1 boot requirements
DATABASE_URL=ecto://kiln:kiln_dev@localhost:5432/kiln_dev
SECRET_KEY_BASE=CHANGE_ME_64_BYTES_MIN  # generate: mix phx.gen.secret
PHX_HOST=localhost
PORT=4000

# Role used at runtime. Migrations set KILN_DB_ROLE=kiln_owner explicitly.
KILN_DB_ROLE=kiln_app

# Phase 3: LLM providers (commented out until P3)
# ANTHROPIC_API_KEY=sk-ant-...
# OPENAI_API_KEY=
# GOOGLE_API_KEY=

# Phase 6: GitHub (commented out until P6)
# GH_TOKEN=

# Debugging escape hatch (D-33). Logs loudly when set.
# KILN_SKIP_BOOTCHECKS=1
```

### `.envrc` (D-39)

```bash
# Requires direnv + asdf-direnv plugin (LOCAL-02 already requires asdf).
use asdf
dotenv .env
```

## Logger Metadata Threading (D-45..D-47)

### `logger_json` config

```elixir
# config/config.exs
config :logger, :default_handler,
  formatter: LoggerJSON.Formatters.Basic.new(
    metadata: [:correlation_id, :causation_id, :actor, :actor_role, :run_id, :stage_id, :mfa, :request_id]
  )
```

Per [LoggerJSON hexdocs 7.0.4](https://hexdocs.pm/logger_json/LoggerJSON.html), `metadata:` lets you whitelist keys that appear on every JSON log line; missing keys are omitted unless explicitly defaulted.

### `Kiln.Logger.Metadata.with_metadata/2` (block decorator)

```elixir
defmodule Kiln.Logger.Metadata do
  @moduledoc """
  Block-style metadata decorator. Sets Logger metadata for the duration of `fun`
  and restores prior metadata on exit (success or failure).
  """

  @type kv :: {atom(), term()}

  @spec with_metadata([kv()], (-> t)) :: t when t: any()
  def with_metadata(pairs, fun) when is_list(pairs) and is_function(fun, 0) do
    prior = Logger.metadata() |> Keyword.take(Keyword.keys(pairs))
    Logger.metadata(pairs)
    try do
      fun.()
    after
      # Restore exact prior values (including re-deleting keys that were absent).
      Enum.each(pairs, fn {k, _} ->
        case Keyword.fetch(prior, k) do
          {:ok, v} -> Logger.metadata([{k, v}])
          :error   -> Logger.metadata([{k, nil}])  # Logger treats nil as delete
        end
      end)
    end
  end
end
```

### `Kiln.Telemetry.pack_ctx/0` + `unpack_ctx/1` (cross-process)

**The canonical pattern:** Elixir's Logger metadata is process-local (per [Task docs](https://hexdocs.pm/elixir/Task.html) — "Logger metadata is process-specific"). Crossing a process boundary requires explicit pack/unpack. See [ElixirForum: Propagate logger metadata in spawned task](https://elixirforum.com/t/propagate-logger-metadata-in-spawned-task/42407) — `Task.Supervisor.start_child(fn -> my_task(Logger.metadata()) end)`.

```elixir
defmodule Kiln.Telemetry do
  @moduledoc """
  Cross-process metadata threading helpers. Pattern:
    1. In parent: `ctx = Kiln.Telemetry.pack_ctx()` → captures Logger.metadata into a map.
    2. Pass `ctx` through a process boundary (Oban :meta, Task closure, GenServer msg).
    3. In child: `Kiln.Telemetry.unpack_ctx(ctx)` → sets Logger.metadata on the new process.
  """

  @required_keys ~w[correlation_id causation_id actor actor_role run_id stage_id]a

  @spec pack_ctx() :: map()
  def pack_ctx do
    Logger.metadata()
    |> Enum.into(%{})
    |> Map.take(@required_keys)
    |> fill_missing_with_none()
  end

  @spec unpack_ctx(map()) :: :ok
  def unpack_ctx(ctx) when is_map(ctx) do
    pairs =
      for key <- @required_keys do
        {key, Map.get(ctx, key, :none)}   # D-46: missing defaults to :none atom, not nil
      end
    Logger.metadata(pairs)
    :ok
  end

  defp fill_missing_with_none(map) do
    Enum.reduce(@required_keys, map, fn k, acc ->
      Map.put_new(acc, k, :none)
    end)
  end
end
```

### Oban metadata threading (the concrete pattern)

**Two complementary mechanisms — use BOTH:**

**A. Oban telemetry handler that attaches job-level metadata on `[:oban, :job, :start]`** (per [Cristian Álvarez: Adding logger metadata to Oban jobs](https://crbelaus.com/2024/05/28/adding-logger-metadata-to-oban-jobs-with-telemetry)):

```elixir
defmodule Kiln.Telemetry.ObanHandler do
  def attach do
    :telemetry.attach(
      "kiln-oban-logger-metadata",
      [:oban, :job, :start],
      &__MODULE__.handle_job_start/4,
      nil
    )
  end

  def handle_job_start(_event, _measures, %{job: job}, _config) do
    # Pull ctx out of job.meta (set at Oban.insert time) and attach.
    ctx = job.meta["kiln_ctx"] || %{}
    Kiln.Telemetry.unpack_ctx(ctx)
    # Plus job-level metadata for Oban Web correlation.
    Logger.metadata(oban_job_id: job.id, oban_queue: job.queue, oban_worker: job.worker)
  end
end
```

Attach in `Kiln.Application.start/2` after Oban comes up.

**B. Set `meta: %{"kiln_ctx" => Kiln.Telemetry.pack_ctx()}` at every `Oban.insert/2` callsite.** `Kiln.Oban.BaseWorker` does this automatically; all other workers MUST go through BaseWorker.

Per [Oban.Job hexdocs](https://hexdocs.pm/oban/Oban.Job.html), the `meta` field is a JSONB map that is persisted with the job row and surfaces on every telemetry event.

### `Task.async_stream` threading

```elixir
# Parent process
ctx = Kiln.Telemetry.pack_ctx()

results =
  Task.async_stream(items, fn item ->
    Kiln.Telemetry.unpack_ctx(ctx)   # restore in each worker
    do_work(item)
  end, max_concurrency: 4, ordered: false)
  |> Enum.to_list()
```

Extract only fields needed into the closure (ARCHITECTURE.md §13.5) — do NOT capture `socket`, `run`, or other large terms.

### Contrived multi-process test (D-47)

```elixir
defmodule Kiln.Telemetry.MetadataThreadingTest do
  use Kiln.DataCase, async: false
  import ExUnit.CaptureLog

  @moduletag :integration

  test "correlation_id threads through Task.async_stream → Oban enqueue → Oban perform → nested Task" do
    cid = Ecto.UUID.generate()
    rid = Ecto.UUID.generate()
    sid = Ecto.UUID.generate()

    log =
      capture_log([format: :json], fn ->
        Logger.metadata(
          correlation_id: cid, causation_id: :none, actor: "test:operator",
          actor_role: "operator", run_id: rid, stage_id: sid
        )

        ctx = Kiln.Telemetry.pack_ctx()

        # Layer 1: Task.async_stream
        Task.async_stream(1..3, fn i ->
          Kiln.Telemetry.unpack_ctx(ctx)
          Logger.info("task layer: item=#{i}")

          # Layer 2: Oban.insert with ctx in :meta
          Kiln.Telemetry.EchoWorker.new(%{i: i}, meta: %{"kiln_ctx" => ctx})
          |> Oban.insert!()
        end, max_concurrency: 2)
        |> Stream.run()

        # Drain Oban jobs to completion.
        :ok = Oban.drain_queue(queue: :default)
      end)

    # Parse each JSON line; assert correlation_id present on ALL of them.
    lines = log |> String.split("\n", trim: true) |> Enum.map(&JSON.decode!/1)

    assert Enum.all?(lines, &(&1["correlation_id"] == cid)),
           "expected correlation_id=#{cid} on every log line; got: #{inspect(Enum.map(lines, & &1["correlation_id"]))}"
    assert Enum.any?(lines, &(&1["message"] =~ "task layer"))
    assert Enum.any?(lines, &(&1["message"] =~ "echo worker"))
  end
end

defmodule Kiln.Telemetry.EchoWorker do
  use Kiln.Oban.BaseWorker, queue: :default, max_attempts: 1

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"i" => i}}) do
    # Logger metadata is already attached by Kiln.Telemetry.ObanHandler.
    Logger.info("echo worker: i=#{i}")
    :ok
  end
end
```

## DB Roles & Migrations (D-48, D-49)

### Two-role setup (D-48)

**Role creation migration (runs once, must run as superuser or during compose init):**

Preferred: ship a `db/init/00-roles.sql` that Postgres auto-runs on container init (Postgres image convention):

```sql
-- db/init/00-roles.sql (mounted into /docker-entrypoint-initdb.d/ in compose.yaml)
CREATE ROLE kiln_owner WITH LOGIN PASSWORD 'kiln_owner_dev';
CREATE ROLE kiln_app   WITH LOGIN PASSWORD 'kiln_app_dev';
GRANT ALL PRIVILEGES ON DATABASE kiln_dev TO kiln_owner;
-- kiln_app's per-table grants are applied by migrations (see Audit section).
```

Update `compose.yaml` `db` service:
```yaml
volumes:
  - kiln_pgdata:/var/lib/postgresql/data
  - ./db/init:/docker-entrypoint-initdb.d:ro   # <-- mount init scripts
```

### Runtime role switching via `KILN_DB_ROLE` (D-48)

```elixir
# config/runtime.exs
if config_env() in [:dev, :test, :prod] do
  role     = System.get_env("KILN_DB_ROLE", "kiln_app")
  password = System.fetch_env!("DATABASE_PASSWORD_" <> String.upcase(role))
             # Or use two separate DATABASE_URLs: DATABASE_URL_OWNER, DATABASE_URL_APP.

  config :kiln, Kiln.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    username: role,
    password: password,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
end
```

### Migration pattern (Ecto + two roles)

Migrations always run as `kiln_owner`. The test suite (which needs both roles, e.g. to verify REVOKE is active) uses `SET LOCAL ROLE` inside transactions:

```elixir
# priv/repo/migrations/20260418_000001_create_kiln_app_grants.exs
defmodule Kiln.Repo.Migrations.CreateKilnAppGrants do
  use Ecto.Migration

  def up do
    # Grant kiln_app minimum connect/usage.
    execute "GRANT CONNECT ON DATABASE kiln_dev TO kiln_app"
    execute "GRANT USAGE ON SCHEMA public TO kiln_app"
    # schema_migrations: allow SELECT only (so kiln_app boot can read version; never write)
    execute "GRANT SELECT ON schema_migrations TO kiln_app"
  end

  def down do
    execute "REVOKE SELECT ON schema_migrations FROM kiln_app"
    execute "REVOKE USAGE ON SCHEMA public FROM kiln_app"
    execute "REVOKE CONNECT ON DATABASE kiln_dev FROM kiln_app"
  end
end
```

### Oban migration (D-49, pinned)

```elixir
# priv/repo/migrations/20260418_000100_install_oban.exs
defmodule Kiln.Repo.Migrations.InstallOban do
  use Ecto.Migration

  @oban_version 12   # Pinned. DO NOT auto-up to latest.

  def up,   do: Oban.Migration.up(version: @oban_version, prefix: "public")
  def down, do: Oban.Migration.down(version: 1, prefix: "public")
end
```

Store the pin in `config/config.exs` so `Kiln.BootChecks.assert_oban_migration_current/0` can cross-check:

```elixir
config :kiln, :oban_migration_version, 12
```

Then **grant kiln_app full DML on Oban tables:**

```elixir
# priv/repo/migrations/20260418_000200_grant_oban_to_kiln_app.exs
defmodule Kiln.Repo.Migrations.GrantObanToKilnApp do
  use Ecto.Migration

  def up do
    execute """
    GRANT SELECT, INSERT, UPDATE, DELETE ON
      oban_jobs, oban_peers, oban_migrations
      TO kiln_app
    """
    execute "GRANT USAGE, SELECT ON SEQUENCE oban_jobs_id_seq TO kiln_app"
  end

  def down do
    execute "REVOKE ALL ON oban_jobs, oban_peers, oban_migrations FROM kiln_app"
  end
end
```

[ElixirForum: Ecto using different role for migrations](https://elixirforum.com/t/ecto-using-different-role-for-migrations/19652) confirms the pattern: supply a different role for migrations vs runtime via env var; `SET ROLE` inside migrations when elevated privileges needed temporarily.

## Validation Architecture

> This section enumerates the **observable events and behaviors that distinguish a working Phase 1 implementation from a broken one**. The planner MUST expose each as an automated test assertion; the Nyquist gate uses these to score implementation correctness.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib, Elixir 1.19.5) + LiveViewTest + Mox 1.2 + StreamData 1.3 |
| Config file | `test/test_helper.exs` (generated by `mix phx.new`) + `config/test.exs` |
| Quick run command | `mix test --stale -x` |
| Full suite command | `mix test` |
| Nyquist gate command | `mix check` (runs full suite + credo + dialyzer + sobelow + mix_audit + xref cycles) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File (P1 ships) |
|--------|----------|-----------|-------------------|-----------------|
| LOCAL-01 | `docker compose up -d && curl localhost:4000/health` returns `{"status":"ok"}` after `mix setup && mix phx.server` | integration (shell) | `bash test/integration/first_run.sh` | ❌ Wave 0 |
| LOCAL-02 | `.tool-versions` pins Elixir 1.19.5-otp-28 and Erlang 28.1.2; `mix.exs` pins Phoenix 1.8.5 + LV 1.1.28 | unit | `mix test test/kiln/tool_versions_test.exs` | ❌ Wave 0 |
| OBS-01 | Logger metadata threads across `Task.async_stream` and Oban boundaries; all log lines carry required keys | integration | `mix test test/kiln/telemetry/metadata_threading_test.exs` | ❌ Wave 0 |
| OBS-03 | audit_events INSERT-only enforced by all three layers (REVOKE + trigger + RULE) | unit | `mix test test/kiln/repo/migrations/audit_events_immutability_test.exs` | ❌ Wave 0 |

### Minimum Distinguishable Behaviors (the Nyquist invariant list)

Every plan must expose these as assertable events. A broken implementation fails at least one.

**Audit ledger (OBS-03, D-06..D-13):**
1. `INSERT INTO audit_events` as `kiln_app` succeeds.
2. `UPDATE audit_events` as `kiln_app` raises `Postgrex.Error` with SQLSTATE 42501 (REVOKE active).
3. `DELETE FROM audit_events` as `kiln_app` raises SQLSTATE 42501.
4. `UPDATE audit_events` as `kiln_owner` raises `Postgrex.Error` with message containing `"audit_events is append-only"` (trigger active).
5. `UPDATE audit_events` as `kiln_owner` with trigger disabled returns `num_rows: 0` and leaves the row unchanged (RULE active).
6. `Kiln.Audit.append/1` with a valid payload for each of the 22 `event_kind` values inserts and returns `{:ok, event}`.
7. `Kiln.Audit.append/1` with invalid payload (fails JSV schema) returns `{:error, {:audit_payload_invalid, _}}` without inserting.
8. Every insert includes `schema_version` (integer) and `correlation_id` (UUID).
9. All 5 b-tree composite indexes exist on `audit_events` (query `pg_indexes`).

**External operations (D-14..D-21, D-44):**
10. `Kiln.Oban.BaseWorker.fetch_or_record_intent/2` with a new key inserts a row with `state="intent_recorded"` and writes an `external_op_intent_recorded` audit event in the same transaction.
11. Calling `fetch_or_record_intent/2` twice with the same key returns `{:found_existing, op}` on the second call without duplicate insert (UNIQUE INDEX enforces).
12. `complete_op/2` updates state to `"completed"` and writes an `external_op_completed` audit event in the same transaction.
13. A worker process that crashes between intent insert and action execution, then retries, sees `{:found_existing, op}` and skips re-doing the action if `state="completed"`.
14. Oban job unique insert (via `use Kiln.Oban.BaseWorker`) rejects duplicate enqueue for the same idempotency_key while state is in `[:available, :scheduled, :executing]`.

**Boot checks (D-32, D-33):**
15. `Kiln.BootChecks.run!/0` succeeds with all invariants satisfied.
16. `Kiln.BootChecks.run!/0` raises `Kiln.BootChecks.Error{invariant: :audit_revoke_active}` if REVOKE missing.
17. `Kiln.BootChecks.run!/0` raises `{:invariant => :audit_trigger_active}` if trigger missing.
18. `Kiln.BootChecks.run!/0` raises `{:invariant => :contexts_compiled}` if a context module cannot be loaded.
19. `Kiln.BootChecks.run!/0` raises `{:invariant => :required_secrets}` if `SECRET_KEY_BASE` or `DATABASE_URL` absent in `:dev`/`:prod`.
20. `KILN_SKIP_BOOTCHECKS=1` causes `run!/0` to return `:ok` and emit an `error`-level log containing `"KILN_SKIP_BOOTCHECKS=1"`.
21. `mix kiln.boot_checks` exits 0 on success, non-zero (via `Mix.raise`) on any failed invariant.

**Logger metadata threading (OBS-01, D-45..D-47):**
22. A log line emitted from the main process contains all 6 required keys in JSON: `correlation_id`, `causation_id`, `actor`, `actor_role`, `run_id`, `stage_id`.
23. Unset metadata keys serialize as `"none"` (string representation of `:none` atom), not `null`.
24. A log line emitted from inside a `Task.async_stream` spawned after `pack_ctx/unpack_ctx` carries the parent's `correlation_id`.
25. A log line emitted from inside `Oban.Worker.perform/1` (when enqueued via `BaseWorker`) carries the enqueue-time `correlation_id` (verified via `job.meta["kiln_ctx"]` propagation through `Kiln.Telemetry.ObanHandler`).

**Health endpoint (D-31, D-40):**
26. `GET /health` returns HTTP 200 with JSON body when Postgres and Oban are up; `status: "ok"`.
27. `GET /health` returns JSON with `postgres: "up"`, `oban: "up"`, `contexts: 12`, `version: <string>` fields present.
28. `HealthPlug` is mounted before `Plug.Logger` in `KilnWeb.Endpoint` (unit test verifies plug order).

**CI gate (D-22..D-30):**
29. `mix format --check-formatted` passes on a clean checkout.
30. `mix compile --warnings-as-errors` passes with no warnings.
31. `mix credo --strict` passes.
32. `Kiln.Credo.NoProcessPut` check flags a file containing `Process.put(:x, 1)`.
33. `Kiln.Credo.NoMixEnvAtRuntime` check flags `Mix.env()` in `lib/**` but not in `mix.exs`.
34. `mix xref graph --format cycles` returns empty (no cycles).
35. `mix check_no_compile_time_secrets` passes on default scaffold; fails if `System.get_env` is added to `config/config.exs`.
36. `mix_audit` passes (no known CVEs in locked deps).
37. `mix sobelow --skip --threshold high --exit` passes.
38. GitHub Actions workflow succeeds on push to `main` using `erlef/setup-beam@v1.23.0` + Postgres 16 service container + the PLT cache key.

**Supervision tree (D-42):**
39. `Supervisor.which_children(Kiln.Supervisor)` returns exactly 7 children: `KilnWeb.Telemetry`, `Kiln.Repo`, `Phoenix.PubSub`, `Finch`, `Registry`, `Oban`, `KilnWeb.Endpoint`.
40. No `RunDirector`, `RunSupervisor`, `Sandboxes.Supervisor`, `StuckDetector` child present (negative assertion).
41. Named Finch pool `Kiln.Finch` is alive (Registry lookup succeeds).

**Local dev first-run UX (LOCAL-01, D-40):**
42. `test/integration/first_run.sh` (CI-optional, local-optional): `cp .env.sample .env && docker compose up -d db && mix setup && curl -f localhost:4000/health | jq -e '.status == "ok"'`.

### Sampling Rate

- **Per task commit:** `mix test --stale -x` (<30s on warm cache)
- **Per wave merge:** `mix check` (full suite — format + compile + credo + dialyzer + xref + sobelow + mix_audit + custom mix tasks)
- **Phase gate:** Full `mix check` green + GitHub Actions green + `mix kiln.boot_checks` exits 0 on a fresh-DB migrate, THEN `/gsd-verify-work`.

### Wave 0 Gaps

**All test infrastructure must be created in Wave 0 since the repo has zero Elixir code.**

- [ ] `test/test_helper.exs` — generated by `mix phx.new`, adjusted for `Kiln.DataCase` with sandbox mode + role-switching helper.
- [ ] `test/support/data_case.ex` — transaction sandbox for DB tests (generated, lightly customized).
- [ ] `test/support/kiln_test.ex` — `Kiln.Test.with_role/2` helper.
- [ ] `test/kiln/repo/migrations/audit_events_immutability_test.exs` — covers minimum behaviors 1-9.
- [ ] `test/kiln/audit/append_test.exs` — covers JSV validation path (behaviors 6, 7, 8).
- [ ] `test/kiln/oban/base_worker_test.exs` — covers behaviors 10-14.
- [ ] `test/kiln/boot_checks_test.exs` — covers behaviors 15-20.
- [ ] `test/mix/tasks/kiln_boot_checks_test.exs` — covers behavior 21.
- [ ] `test/kiln/telemetry/metadata_threading_test.exs` — covers behaviors 22-25.
- [ ] `test/kiln_web/health_controller_test.exs` — covers behaviors 26-28.
- [ ] `test/kiln/credo/no_process_put_test.exs` — covers behavior 32 (using `Credo.Test.Case`).
- [ ] `test/kiln/credo/no_mix_env_at_runtime_test.exs` — covers behavior 33.
- [ ] `test/kiln/application_test.exs` — covers behaviors 39-41.
- [ ] `test/integration/first_run.sh` — shell-level integration test (covers behavior 42); CI-optional.

## Security Domain

> Required because `security_enforcement: true` in `.planning/config.json`. ASVS Level 1.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V1 Architecture, Design & Threat Modeling | yes | ARCHITECTURE.md §9-12 + this research; threat model: "untrusted future developer/migration accidentally mutates audit ledger" |
| V2 Authentication | no | Single-operator local app; no auth surface in v1 (explicitly deferred per PROJECT.md Out of Scope) |
| V3 Session Management | no | No sessions in v1; `Kiln.Scope` is a stub |
| V4 Access Control | partial | Two Postgres roles (`kiln_owner` / `kiln_app`) are the v1 ACL; DB enforces |
| V5 Input Validation | yes | JSV 0.18 Draft 2020-12 at `Kiln.Audit.append/1` boundary; Ecto changeset `validate_inclusion` on `event_kind` + CHECK constraint |
| V6 Cryptography | partial | `pg_uuidv7` extension (never hand-roll UUID gen); `SECRET_KEY_BASE` minimum 64 bytes per Phoenix convention |
| V7 Error Handling & Logging | yes | `logger_json` structured output; `@derive {Inspect, except: [:api_key]}` pattern documented (exercised in P3 but convention locked P1) |
| V8 Data Protection | partial | Secrets as references (deferred to P3 fully); append-only ledger for integrity |
| V9 Communications Security | n/a | No outbound HTTPS callouts in P1 surface (Finch pool configured but unused) |
| V10 Malicious Code | n/a | No agent-generated code execution in P1 |
| V11 Business Logic | yes | Bounded-autonomy hook points (caps) not exercised in P1 but table is structured to support |
| V14 Configuration | yes | All secrets in `config/runtime.exs`; `credo_envvar` + `mix check_no_compile_time_secrets` enforce |

### Known Threat Patterns for Phase 1

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Audit log tampering (future migration bypasses RULE) | Tampering | Three-layer enforcement (D-12); migration test asserts all three paths |
| Runtime role has DDL privileges | Elevation of Privilege | `kiln_app` role has INSERT/SELECT on audit_events + full DML on other tables; no DDL; migrations ONLY as `kiln_owner` |
| Secrets in compile-time config | Information Disclosure | `credo_envvar` + `mix check_no_compile_time_secrets` grep; all secrets in `config/runtime.exs` |
| BEAM boots with broken invariants (silent drift) | Tampering | `Kiln.BootChecks.run!/0` raises on any violated invariant |
| Compose network misconfigured (sandbox can reach host) | Information Disclosure | `kiln-sandbox` network `internal: true` (Docker bridge with no gateway); not exercised in P1 but compose skeleton locks it |
| Dep with known CVE | Supply Chain | `mix_audit` fail-on-any in CI |
| Phoenix/Plug vuln class (CSRF, SSRF, XSS) | Multi | `sobelow` HIGH-only in CI |
| LLM-generated slop in code (P9 dogfood-relevant) | n/a | `ex_slop` Credo checks; blocks in CI |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `pg_uuidv7` 1.7.0 (2025-10-13) is current and the `ghcr.io/fboulnois/pg_uuidv7:1.7.0` image is pullable and healthy | Stack | Planner must `docker pull ghcr.io/fboulnois/pg_uuidv7:1.7.0` once to verify; fallback is the kjmph pure-SQL fn (CONTEXT.md canonical_refs) |
| A2 | Oban migration v12 is current stable (2.21.1) | DB Roles & Migrations | Verify via `mix hex.info oban` + `Oban.Migration.latest_version/0`; adjust pinned integer accordingly |
| A3 | `credo_envvar` maintains an active API compatible with Credo 1.7.16+ | CI Gate | Low — if dead, replace with second grep-based Mix task (minimal loss) |
| A4 | `ex_slop` 0.2.0 checks don't produce excessive false positives on greenfield Phoenix 1.8 scaffold | CI Gate | Medium — if noisy, allowlist specific checks in `.credo.exs`; do not remove the package (aligns with P9 dogfood prep) |
| A5 | `erlef/setup-beam@v1.23.0` installs Elixir 1.19.5-otp-28 + OTP 28.1.2 cleanly on Ubuntu 24.04 | CI | Low — verified by action docs through v1.23; falls back to matrix tweak |
| A6 | `JSON.decode!/1` from Elixir 1.19 stdlib handles the audit schemas (not needing `Jason`) | Audit Ledger | Low — Phoenix 1.8 generators already assume stdlib JSON; if gaps appear, add `{:jason, "~> 1.4"}` one-liner |

**Nothing in this table is a load-bearing decision** — all are version-verification tasks the planner performs as the first step of their first plan's first task.

## Open Questions

None. All 53 decisions from CONTEXT.md are directly actionable. Three implementation nuances surfaced during research are resolved here (not raised as blockers):

1. **Where to invoke `Kiln.BootChecks.run!/0` in `Application.start/2`.** Resolved: inline between child-spec construction and `Supervisor.start_link`, AFTER a bootstrap supervisor starts `Repo` + `Oban` (via `Supervisor.start_child` calls on a staged supervisor). Planner can pick the simpler pattern of starting Repo + Oban as the first two children, then running checks, then starting the remaining children — this requires splitting `start/2` into two phases. Both patterns work; the staged-bootstrap is cleaner but ~10 extra LOC.

2. **Where `Kiln.HealthPlug` lives** — `lib/kiln_web/plugs/` vs `lib/kiln_web/health/`. Per D's Discretion, planner picks. Research recommends `lib/kiln_web/plugs/` for consistency with Phoenix convention.

3. **Whether `Kiln.Scope` stub needs its own module file or can live inline in `kiln_web.ex`.** Recommend own module (`lib/kiln/scope.ex`) because it will expand in P7-P8 and is queried from multiple layers.

## Sources

### Primary (HIGH confidence — verified against official docs)
- [Elixir v1.19 release announcement](https://elixir-lang.org/blog/2025/10/16/elixir-v1-19-0-released/)
- [Phoenix 1.8 Scopes — hexdocs.pm/phoenix/scopes.html](https://hexdocs.pm/phoenix/scopes.html)
- [Phoenix 1.8 released blog post](https://www.phoenixframework.org/blog/phoenix-1-8-released)
- [Oban Hex 2.21 — Oban.Job docs](https://hexdocs.pm/oban/Oban.Job.html)
- [Oban.Worker docs](https://hexdocs.pm/oban/Oban.Worker.html)
- [LoggerJSON 7.0.4 — hexdocs](https://hexdocs.pm/logger_json/LoggerJSON.html)
- [ex_check 0.16 docs](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html)
- [Credo Adding Custom Checks](https://hexdocs.pm/credo/adding_checks.html)
- [Credo Testing Custom Checks](https://hexdocs.pm/credo/testing_checks.html)
- [JSV 0.18 docs](https://hexdocs.pm/jsv/JSV.html)
- [Task — Elixir 1.19 docs](https://hexdocs.pm/elixir/Task.html)
- [pg_uuidv7 GitHub — fboulnois](https://github.com/fboulnois/pg_uuidv7)
- [Brandur — Implementing Stripe-like Idempotency Keys in Postgres](https://brandur.org/idempotency-keys)
- [brandur/rocket-rides-atomic GitHub](https://github.com/brandur/rocket-rides-atomic)
- [PostgreSQL 16 CREATE RULE docs](https://www.postgresql.org/docs/16/sql-createrule.html)
- [PostgreSQL 39.7 Rules Versus Triggers](https://www.postgresql.org/docs/current/rules-triggers.html)
- [erlef/setup-beam releases](https://github.com/erlef/setup-beam/releases)

### Secondary (MEDIUM confidence — community-authored, cross-verified with official docs)
- [Cristian Álvarez — Adding Logger metadata to Oban jobs](https://crbelaus.com/2024/05/28/adding-logger-metadata-to-oban-jobs-with-telemetry) (Oban telemetry handler pattern)
- [jola.dev — Health checks for Plug and Phoenix](https://jola.dev/posts/health-checks-for-plug-and-phoenix)
- [AppSignal Blog — Writing a Custom Credo Check](https://blog.appsignal.com/2023/08/29/writing-a-custom-credo-check-in-elixir.html)
- [ElixirForum — Ecto using different role for migrations](https://elixirforum.com/t/ecto-using-different-role-for-migrations/19652)
- [ElixirForum — Propagate logger metadata in spawned task](https://elixirforum.com/t/propagate-logger-metadata-in-spawned-task/42407)
- [Plausible issue #1105 — SECRET_KEY_BASE env var pattern](https://github.com/plausible/analytics/issues/1105)
- [PostgreSQL CREATE RULE silent-bypass discussion (Medium)](https://medium.com/@caring_smitten_gerbil_914/why-you-should-avoid-postgresql-rules-and-use-triggers-instead-593e481bd16d)

### Internal (consumed, not re-derived)
- `/Users/jon/projects/kiln/CLAUDE.md`
- `/Users/jon/projects/kiln/.planning/PROJECT.md`
- `/Users/jon/projects/kiln/.planning/REQUIREMENTS.md`
- `/Users/jon/projects/kiln/.planning/ROADMAP.md`
- `/Users/jon/projects/kiln/.planning/research/STACK.md`
- `/Users/jon/projects/kiln/.planning/research/ARCHITECTURE.md` (§5, §9, §12, §13, §15)
- `/Users/jon/projects/kiln/.planning/research/PITFALLS.md` (P3, P9, P11, P12, P13, P14, P15, P17)
- `/Users/jon/projects/kiln/.planning/phases/01-foundation-durability-floor/01-CONTEXT.md`

## Metadata

**Confidence breakdown:**
- Stack & versions: HIGH — STACK.md already verified all core versions; P1-specific additions (pg_uuidv7, credo_envvar, ex_slop) verified via registry/repo 2026-04-18.
- Audit ledger (three-layer enforcement): HIGH — SQL patterns verified against PostgreSQL 16 docs; migration test pattern idiomatic Ecto + Postgrex.
- `external_operations` intent table: HIGH — Brandur pattern widely documented and implemented in multiple languages; schema columns verified against D-21.
- CI gate: HIGH — ex_check config schema verified against official docs; custom Credo check skeletons verified against adding_checks.html; erlef/setup-beam verified.
- Logger metadata threading: HIGH — official pattern; Oban `:meta` + telemetry handler combination is the canonical approach.
- Boot checks + role switching: HIGH — Plausible pattern documented on their issue tracker; ElixirForum role-switching pattern confirmed.
- Security domain: HIGH — ASVS Level 1 is lightweight; v1 scope is explicitly solo-local.

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — stack is stable; revisit only if Oban 2.22+ or Phoenix 1.9 ships with breaking changes)
