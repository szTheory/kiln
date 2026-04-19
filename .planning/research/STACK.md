# Stack Research

**Project:** Kiln — software dark factory
**Domain:** Elixir/Phoenix LiveView operator dashboard + OTP-native LLM agent orchestrator + Docker sandbox runner + Postgres-durable workflow engine
**Researched:** 2026-04-18
**Overall confidence:** HIGH for core stack and infra; MEDIUM for LLM SDKs (ecosystem is young, no official Anthropic Elixir SDK)

---

## TL;DR Recommendation

Build Kiln on **Elixir 1.19.5 + OTP 28 + Phoenix 1.8.5 + LiveView 1.1.28 + Ecto 3.13.5 + Postgrex 0.22.0 + Oban 2.21.1 + Bandit 1.10.4 + Req 0.5.17**, with **Anthropix 0.6.2** as the Anthropic client behind a **`Kiln.Agents.Adapter` behaviour** that also admits OpenAI, Google, and Ollama adapters. Parse workflows with **yaml_elixir 2.12.1** + validate with **JSV 0.18.1**. Observe with **opentelemetry 1.6 + opentelemetry_api 1.4 + opentelemetry_exporter 1.8** plus the phoenix/ecto/oban instrumentation packages; log structured JSON via **logger_json 7.0.4**. Sandbox stages using `System.cmd("docker", ...)` + **docker_engine_api 1.43** for introspection, and reuse **testcontainers 1.13** in integration tests. Static analysis: **Credo 1.7.16 + Dialyxir 1.4 + mix xref** (built-in). Security: **mix_audit + sobelow** via **ex_check 0.16**. CI: **erlef/setup-beam@v1.23.0** on GitHub Actions.

This is validated against current Elixir 1.19.5/OTP 28.1+/Phoenix 1.8.5/LiveView 1.1.28/Oban 2.21 docs. As of April 2026 the actively maintained stable is 1.19.5/OTP 28.1+ and Phoenix generators assume that baseline; the stack is pinned to that baseline across `.tool-versions` and `mix.exs`. See "Stale items in existing `/prompts/` docs" below.

---

## Recommended Stack

### Core Runtime (BEAM + Web)

| Technology | Version | Purpose | Why for Kiln (confidence) |
|---|---|---|---|
| Elixir | **1.19.5** (released 2026-01-09) | BEAM language | Current stable; ships improved type-checking, 4x faster compilation, better `mix xref --min-cycle-label` output; required by modern Phoenix generators. **HIGH** |
| Erlang/OTP | **28.x** (Elixir 1.19 officially supports OTP 28.1+) | VM, supervision, schedulers | OTP 28 is the current active line; Elixir 1.19 targets it. Kiln's crash-isolated per-stage processes, PartitionSupervisors, and DynamicSupervisors all depend on this. **HIGH** |
| Phoenix | **1.8.5** | Web framework, generators, scopes | Phoenix 1.8 scopes + `current_scope` threading map cleanly onto Kiln's per-run + per-actor filtering; verified routes (`~p`), HEEx function components, and the `mix phx.gen.auth` baseline are all v1.8 conventions. **HIGH** |
| Phoenix LiveView | **1.1.28** | Real-time operator UI | v1.1 brought colocated hooks/JS, `<.portal>`, `JS.ignore_attributes/1`, `stream_async/4`, `Phoenix.LiveView.Debug`, and the LazyHTML test replacement for Floki — all directly useful for Kiln's run board + stage detail + event stream. **HIGH** |
| Phoenix PubSub | **~> 2.1** (ships with phoenix) | In-node + clustered broadcast | Powers real-time dashboard updates from Oban job events, agent chatter, stage transitions. Single-node for solo v1, but already ready for cluster. **HIGH** |
| Ecto | **3.13.5** | Data mapping, changesets, Multi | `Repo.transact/2` (replaces deprecated `Repo.transaction/2`), `redact: true`, `load_in_query: false`, and `writable: :never` support the security/immutability constraints on audit ledger rows and run state. **HIGH** |
| ecto_sql | **3.13.5** | SQL adapter + migrations | Matches Ecto. Migrations support partial indexes, check constraints, `migration_lock`. **HIGH** |
| Postgrex | **0.22.0** (2026-01-10) | PostgreSQL driver | Current stable; supports Postgres 16/17 wire protocol, replication connections (potentially useful for audit-ledger streaming later). **HIGH** |
| PostgreSQL | **16.x** (17.x fine if available) | Durable source of truth | `citext`, partial unique indexes, `nulls_distinct: false` (15+), advisory locks for migration coordination, strong JSON/JSONB for event payloads. **HIGH** |

**Postgres extensions:**

- **`pg_uuidv7`** (<https://github.com/fboulnois/pg_uuidv7>, version 1.7.0 as of 2025-10) — Postgres 16-compatible extension exposing `uuid_generate_v7()` for time-sortable, b-tree-locality-preserving primary keys. Used by `audit_events` and `external_operations`. Kiln's compose.yaml pins `ghcr.io/fboulnois/pg_uuidv7:1.7.0` which ships the extension pre-built; migrations run `CREATE EXTENSION IF NOT EXISTS pg_uuidv7`. **Migration note:** when the project moves to Postgres 18, drop this extension in favor of the native `uuidv7()` function. Fallback: `kjmph` pure-SQL implementation (see CONTEXT.md D-06 canonical_refs) if the extension cannot be installed on some exotic Postgres host.

| Bandit | **1.10.4** | HTTP/1.1, HTTP/2, WebSocket server | Default Phoenix server since 1.7.11; pure Elixir; up to 4x faster than Cowboy on HTTP/1; 100% h2spec + Autobahn compliance. Required by `opentelemetry_phoenix` adapter config. **HIGH** |
| Plug | **1.19.x** | HTTP plumbing | Kiln needs `Plug.RequestId`, `Plug.Telemetry`, `Plug.SSL` for structured log correlation and edge hygiene. **HIGH** |

### Durable Jobs

| Technology | Version | Purpose | Why (confidence) |
|---|---|---|---|
| Oban | **2.21.1** (OSS edition, MIT) | Durable background jobs | Locks in Postgres-durable, transactionally-inserted jobs. Oban's transactional-insert guarantee is **the** correctness lever for Kiln's "checkpoint + enqueue in same tx" stage pattern. Unique jobs give idempotency keys for ORCH-07. `Oban.Testing` has sandbox-friendly helpers. **HIGH** |
| Oban Web | **2.12.2** (Apache-2.0, **now OSS** as of 2025) | Embedded LiveView admin for jobs | Oban Web went open-source in 2025. Mount it at `/ops/oban` for queue depth, failures, retries, job filtering. Zero cost, zero add-on infra. Use in v1. **HIGH** |

**Do NOT need Oban Pro/Web paid tiers for v1.** Rationale: solo-engineer scope, single workspace, no multi-tenant, OSS Oban already covers unique jobs, scheduled jobs, cron, plugins (`Oban.Plugins.Pruner`), queues per worker role, and telemetry. Upgrade later only if Kiln grows into team mode.

### HTTP Client (for LLM provider APIs)

**Decision: `Req 0.5.17` as the sole HTTP client; do not bypass to raw Finch.**

| Technology | Version | Purpose | Why (confidence) |
|---|---|---|---|
| Req | **0.5.17** (2026-01-05) | Batteries-included HTTP client | Built on Finch (which handles the pool). Gives auto-decompress, retry with backoff, redirect follow, JSON codec, request/response step plugins — all of which Kiln's LLM adapter layer wants anyway. Wojtek Mach (Elixir core team) maintains. **HIGH** |
| Finch | transitive (~> 0.19) | Mint-based connection pool | Only configured via Req; named pools per provider (Anthropic, OpenAI, Google, Ollama) so a rate-limit storm in one pool does not starve another. **HIGH** |

**Why Req over Finch directly:** Kiln has maybe 4 HTTP-speaking adapters (3 LLM providers + 1 Ollama). Req's plugin model (`Req.Request.append_request_steps/2`) is a clean place to hang retry policy, structured logging, token counting, and OTel span emission. Dropping to raw Finch would give us pooling tuning we do not need yet and force us to rebuild the step pipeline Req already ships. Escape hatch: a single adapter can drop to `Finch.build/Finch.request` if a provider needs streaming SSE with manual chunk handling (Req supports streaming, but some providers are fussy).

### LLM SDK Strategy

**Decision: behaviour-based `Kiln.Agents.Adapter` + Anthropic-first implementation using `anthropix`.**

```elixir
defmodule Kiln.Agents.Adapter do
  @callback complete(prompt :: Kiln.Agents.Prompt.t(), opts :: keyword()) ::
              {:ok, Kiln.Agents.Response.t()} | {:error, term()}
  @callback stream(prompt :: Kiln.Agents.Prompt.t(), opts :: keyword()) ::
              {:ok, Enumerable.t()} | {:error, term()}
  @callback count_tokens(prompt :: Kiln.Agents.Prompt.t()) ::
              {:ok, non_neg_integer()} | {:error, term()}
  @callback capabilities() :: %{streaming: boolean(), tools: boolean(), thinking: boolean(), vision: boolean()}
end
```

| Provider | Implementation strategy | Confidence |
|---|---|---|
| **Anthropic** | `Kiln.Agents.Adapter.Anthropic` using **anthropix 0.6.2** (unofficial but actively maintained, supports tool use, extended thinking, prompt caching, message batching, streaming). **No official Anthropic Elixir SDK exists** as of April 2026. | **MEDIUM** — anthropix is maintained by a single maintainer; I'd wrap it behind our behaviour so we can swap to a direct-Req implementation if the SDK stalls. |
| **OpenAI** | `Kiln.Agents.Adapter.OpenAI` — **roll own with Req**. OpenAI's API is simple JSON over HTTPS; community libs (e.g., `openai_ex`) exist but evolve slowly behind the real API. Kiln only needs chat completions + streaming — ~200 LOC. | **MEDIUM** |
| **Google (Gemini)** | `Kiln.Agents.Adapter.Google` — **roll own with Req**. Same argument as OpenAI. | **MEDIUM** |
| **Ollama (local)** | `Kiln.Agents.Adapter.Ollama` — **roll own with Req** against Ollama's HTTP API (`/api/chat`, `/api/generate`, `/api/tags`). Simplest adapter; no auth. | **HIGH** |

**Rationale for rolling three of four:** LLM APIs drift monthly. Community SDKs chase them and routinely lag. Kiln needs a *tight* surface (complete + stream + count + capabilities), not a full SDK's worth of parameter wrappers. Keeping the surface small via the adapter behaviour lets us stay current in <50 LOC per provider update instead of waiting for a third-party release.

**Structured output:** Consider `instructor_ex 0.1.x` later if we want Ecto-schema-driven LLM outputs (e.g., Planner returning a strict `WorkflowPatch` struct). For v1, explicit JSON mode on each provider + JSV validation is sufficient.

### Workflow Format (YAML + JSON Schema)

**Decision: YAML on disk, validated against a JSON Schema that is also checked into the repo and evolved with versioned migrations.**

| Technology | Version | Purpose | Why (confidence) |
|---|---|---|---|
| yaml_elixir | **2.12.1** (2026-02-17) | YAML parser | Wraps yamerl (pure Erlang). No native deps. Adequate speed for workflow files (human-written, tens of KB). Familiar, battle-tested, Hex-published. **HIGH** |
| yamerl | transitive | YAML 1.2 / JSON parser (Erlang) | Underneath yaml_elixir. No direct dependency management needed. **HIGH** |
| **JSV** | **0.18.1** | JSON Schema 2020-12 validator | Full Draft 2020-12 compliance (100% on official test suite); draft 7 also supported; custom meta-schemas supported; clean error normalization for APIs. Actively developed 2024–2026. **HIGH** |
| ymlr | **5.1.4** | YAML encoder (for round-tripping / diff-tooling) | Optional; only needed if Kiln writes workflow files back out. For v1, LiveView renders workflows read-only — skip unless diff-viewer needs canonical YAML emit. **MEDIUM — optional** |

**Do NOT use `fast_yaml`.** It wraps libyaml (C) and needs `libyaml-dev` system headers at build time. For a workflow-file scale (small, human-authored), the perf gain is negligible and the native-dep footgun is a real cost on Docker builds and asdf setups.

**Do NOT use `ex_json_schema`** (the common `jonasschmidt/ex_json_schema`). It only supports Draft 4 and has not kept up. JSV is the modern answer.

### Sandbox (Docker)

**Decision: `System.cmd("docker", [...])` wrapping, with `docker_engine_api` for introspection/stream cases.**

| Approach | When to use | Confidence |
|---|---|---|
| `System.cmd/3` shelling out to `docker` CLI | Default: `docker run`, `docker exec`, `docker kill`, `docker rm`, `docker cp`. Easy to reason about, matches how operators debug locally, integrates cleanly with the user's logged-in Docker Desktop / Engine. **HIGH** |
| `docker_engine_api` (~> 1.43, Hex: `ex_docker_engine_api`) | Secondary: programmatic container listing, `docker stats` equivalents, streaming logs over the Engine socket. Autogenerated from the official Docker OpenAPI spec — aligned with Docker Engine API v1.43+. **MEDIUM** |
| `testcontainers 1.13.3` | Only in `test/` — ephemeral Postgres + engine mock containers for integration suites. Not a runtime dependency. **HIGH** |

**Why shell-out first:** (1) Docker CLI is the source of truth operators already use; matching its behavior reduces "works in Kiln but not in `docker run`" drift. (2) Auth to Docker Engine (socket permissions, Docker Desktop credential helpers) is already handled. (3) `System.cmd/3` gives you stdout/stderr capture with zero ceremony. (4) Kiln already has a dependency on the operator having Docker installed — calling `docker` is not adding one.

**Why `docker_engine_api` as a secondary:** Structured responses (JSON from Engine API) beat string-parsing `docker ps` output when Kiln needs to list "all Kiln sandboxes", enforce cleanup invariants, or stream container logs into the LiveView event feed.

**Egress-block enforcement (SAND-02)**: `docker run --network kiln-sandbox-net` where `kiln-sandbox-net` is a Docker bridge network with no external gateway; Digital Twin Universe mocks bind to that network only. This is infrastructure config, not code.

### Observability

| Technology | Version | Purpose | Why (confidence) |
|---|---|---|---|
| opentelemetry (SDK) | **1.6.0** | OTel Erlang SDK | Traces API stable. Metrics + logs OTel APIs are still marked *development* in the Erlang SDK as of April 2026 — for v1 use traces for stages/agent-calls and rely on `:telemetry` + Phoenix LiveDashboard for metrics. **HIGH for traces, MEDIUM for metrics/logs** |
| opentelemetry_api | **~> 1.4** | OTel API (compile-only) | Required. **HIGH** |
| opentelemetry_exporter | **~> 1.8** | OTLP exporter (HTTP + gRPC) | Export to any OTel collector (SigNoz, Tempo, Jaeger, Honeycomb). **HIGH** |
| opentelemetry_phoenix | **~> 2.0** | Auto-instrument Phoenix requests | Call with `adapter: :bandit` to capture the full Bandit request lifecycle. **HIGH** |
| opentelemetry_bandit | **~> 0.2** | Bandit-specific adapter | Required alongside `opentelemetry_phoenix` for full Bandit spans. **HIGH** |
| opentelemetry_ecto | **~> 1.2** | Auto-instrument Ecto queries | Links preload tasks back to the initiating span. **HIGH** |
| opentelemetry_oban | **~> 2.5** | Auto-instrument Oban jobs | Kiln stages are Oban jobs — this gives per-stage spans for free. **HIGH** |
| telemetry | **~> 1.3** | Event emission (transitive) | Foundation of all Phoenix/Ecto/Oban instrumentation. **HIGH** |
| telemetry_metrics | **~> 1.1** | Metric aggregation | Paired with `telemetry_poller` in the supervision tree for VM/scheduler metrics. **HIGH** |
| telemetry_poller | **~> 1.1** | Periodic measurements | VM memory, run queue, GC — consumed by LiveDashboard. **HIGH** |
| phoenix_live_dashboard | **~> 0.8** (0.8.7) | In-app metrics UI | Mount at `/ops/dashboard` for OS/VM/metrics/home pages. Cheap to add, high leverage. **HIGH** |
| logger_json | **7.0.4** | Structured JSON log formatter | Kiln requires correlation_id / causation_id / actor / run_id / stage_id on every log line (OBS-01) — logger_json + Logger metadata with `Plug.RequestId` is the idiomatic pattern. Use `LoggerJSON.Formatters.Basic` (or Datadog/GCP when deploying). **HIGH** |

### Testing

| Technology | Version | Purpose | Why (confidence) |
|---|---|---|---|
| ExUnit | stdlib (Elixir 1.19) | Built-in test framework | Standard. Run `async: true` for pure/context tests; `async: false` for anything touching app env, Oban plugins, or OTel globals. **HIGH** |
| LiveViewTest | via phoenix_live_view | LiveView lifecycle testing | v1.1 switched from Floki to **LazyHTML**. Do not carry Floki selectors from older examples. Use `live/2`, `element/3`, `form/3`, `render_async/2`. Duplicate DOM/LiveComponent ids now raise in tests by default. **HIGH** |
| Mox | **1.2.0** | Behaviour-based mocks | Paired with the `Kiln.Agents.Adapter` behaviour this is the right way to mock the LLM layer. Supports `async: true`. Do NOT use `meck` or `mock`. **HIGH** |
| StreamData | **1.3.0** | Property-based testing + data generation | Property tests for workflow YAML parser, JSON Schema validator edge cases, idempotency-key uniqueness. Native Elixir, idiomatic. **HIGH** |
| testcontainers | **1.13.3** | Docker-driven integration test fixtures | Spin up Postgres for tests that need real DB constraints (as opposed to `Ecto.Adapters.SQL.Sandbox`). Also useful for end-to-end sandbox tests. **HIGH** |
| Ecto.Adapters.SQL.Sandbox | via ecto_sql | Transactional test isolation | PostgreSQL supports concurrent sandbox tests (MySQL does not — not relevant here). **HIGH** |

**Anti-rec: Floki.** LiveView 1.1 moved to LazyHTML in LiveViewTest. You will not need Floki for LiveView tests. If you need CSS/XPath queries on rendered HTML outside LiveView (e.g., Markdown rendering tests), `LazyHTML` from phoenix_html_helpers is sufficient.

### Static Analysis

| Tool | Version | Purpose | Why (confidence) |
|---|---|---|---|
| Credo | **1.7.16** | Linter / style / design warnings | Opinionated but configurable. Useful for catching overuse of `if/cond` where `case` would do, missing `@moduledoc`, cyclomatic complexity. Run in CI with `--strict`. **HIGH** |
| Dialyxir (Dialyzer) | **~> 1.4** | Success-typing static analyzer | *The `/prompts/elixir-best-practices-deep-research.md` doc is ambivalent on Dialyzer.* Kiln should use it anyway. With `@spec`s on public context boundaries (per Phoenix context guide), Dialyzer catches shape drift across the Adapter/Provider axis — exactly where Kiln's agent calls live. Cache PLT in CI. **MEDIUM — judgment call; enable but do not gate initial merges on it** |
| `mix xref` | stdlib | Compile-time dependency & cycle detection | Run `mix xref graph --format cycles` and `mix xref --min-cycle-label=compile` in CI. Catches macro-driven recompile cascades. Essentially free. Elixir 1.19 improved this. **HIGH** |
| `mix format` | stdlib | Code formatter | Non-negotiable; hard law per the Elixir best-practices doc. CI fails on `mix format --check-formatted`. **HIGH** |
| `mix compile --warnings-as-errors` | stdlib | Treat warnings as errors | CI requirement. Especially valuable with Phoenix's compile-time verified routes (`~p`) and HEEx attr/slot warnings. **HIGH** |

### Security

| Tool | Version | Purpose | Why (confidence) |
|---|---|---|---|
| mix_audit | **~> 2.1** (latest 2026) | Scan deps for known CVEs | `mix deps.audit` against the GitHub-sourced advisory DB. Run in CI. **HIGH** |
| sobelow | **~> 0.14** | Phoenix-focused security static analysis | Catches `Plug.Csrf` misuse, unsafe `Code.eval_string`, missing CSP, config leaks. **HIGH** |
| ex_check | **0.16.0** | Meta-runner for all of the above | `mix check` runs format + compile + credo + dialyzer + xref + mix_audit + sobelow in one command with curated defaults. Use in `.github/workflows/ci.yml` and in pre-commit. **HIGH** |

### Development Tools

| Tool | Purpose | Notes |
|---|---|---|
| **asdf** | Tool version pinning | `.tool-versions` pins Elixir + Erlang + Node (for esbuild/tailwind if Phoenix retains them). See section below. |
| **Docker** | Local orchestration + sandbox runtime | 24+ (Docker Desktop on macOS, Docker Engine on Linux). |
| **Docker Compose** | `docker-compose up` starts Kiln + Postgres + sandbox network | See reference config below. |
| **GitHub Actions** | CI/CD | `erlef/setup-beam@v1.23.0` for BEAM setup; `services:` block for Postgres. |
| **Phoenix LiveDashboard** | Internal ops UI | Mounted at `/ops/dashboard`, peer to Oban Web at `/ops/oban`. |
| **ExDoc** | API docs | Optional for v1 (Kiln is not a library), but helpful once the core context API stabilizes. |
| **Livebook** | Interactive notebooks for local agent experimentation | Optional; useful for "poke the Anthropic adapter" scratch sessions. |

---

## Installation & Setup (Kiln repo, greenfield)

### `.tool-versions`

```
elixir 1.19.5-otp-28
erlang 28.1.2
nodejs 22.11.0
```

Rationale: Elixir 1.19 requires OTP 28.1+; pin the exact OTP patch to avoid asdf surprises. Keep Node for Phoenix asset pipeline (esbuild + tailwind) until Phoenix 1.9 potentially drops it.

### `mix.exs` deps excerpt

```elixir
defp deps do
  [
    # Core web
    {:phoenix, "~> 1.8.5"},
    {:phoenix_html, "~> 4.2"},
    {:phoenix_live_view, "~> 1.1.28"},
    {:phoenix_live_dashboard, "~> 0.8.7"},
    {:bandit, "~> 1.10"},
    {:plug_cowboy, "~> 2.7", only: [:dev, :test]}, # only if you still need cowboy tests; otherwise omit
    # Data
    {:ecto_sql, "~> 3.13"},
    {:postgrex, "~> 0.22"},
    # Jobs
    {:oban, "~> 2.21"},
    {:oban_web, "~> 2.12"},
    # HTTP
    {:req, "~> 0.5"},
    # LLM
    {:anthropix, "~> 0.6"},
    # Workflow parsing & validation
    {:yaml_elixir, "~> 2.12"},
    {:jsv, "~> 0.18"},
    # Observability
    {:opentelemetry, "~> 1.6"},
    {:opentelemetry_api, "~> 1.4"},
    {:opentelemetry_exporter, "~> 1.8"},
    {:opentelemetry_phoenix, "~> 2.0"},
    {:opentelemetry_bandit, "~> 0.2"},
    {:opentelemetry_ecto, "~> 1.2"},
    {:opentelemetry_oban, "~> 2.5"},
    {:telemetry_metrics, "~> 1.1"},
    {:telemetry_poller, "~> 1.1"},
    {:logger_json, "~> 7.0"},
    # Docker introspection
    {:ex_docker_engine_api, "~> 1.43"},
    # Dev & test
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
    {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
    {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
    {:mox, "~> 1.2", only: :test},
    {:stream_data, "~> 1.3", only: [:dev, :test]},
    {:testcontainers, "~> 1.13", only: :test}
  ]
end
```

### `docker-compose.yml` (reference)

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: kiln
      POSTGRES_PASSWORD: kiln_dev
      POSTGRES_DB: kiln_dev
    ports:
      - "5432:5432"
    volumes:
      - kiln_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U kiln"]
      interval: 2s
      timeout: 5s
      retries: 10

  # Kiln web/app runs on the host (asdf-managed) for fastest dev loop.
  # Sandboxes are spawned by Kiln via `docker run` onto this network:
  sandbox-net:
    image: alpine:3.20
    command: ["sleep", "infinity"]
    networks:
      - kiln-sandbox
    profiles: ["network-anchor"] # dummy container to materialize the network

networks:
  kiln-sandbox:
    driver: bridge
    internal: true  # no external gateway → egress blocked (SAND-02)

volumes:
  kiln_pgdata:
```

> Kiln's `compose.yaml` uses `ghcr.io/fboulnois/pg_uuidv7:1.7.0` (PG 16 + pg_uuidv7 extension pre-installed) instead of `postgres:16-alpine` — see CONTEXT.md D-52.

**Notes:**
- Postgres 16-alpine is fine for dev. Phoenix docs recommend Debian/Ubuntu bases for *production* releases to avoid Alpine DNS issues — that applies to Kiln's own runtime image, not Postgres.
- Kiln runs on the host (asdf Elixir) in dev, not in a container. Faster reload, easier `iex -S mix phx.server`.
- `internal: true` on the sandbox network enforces SAND-02 at the Docker networking layer.
- The DTU mock services (SAND-03) attach themselves to `kiln-sandbox` so sandboxed stages can reach them.

### `.github/workflows/ci.yml` skeleton

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-24.04
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: kiln_test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 5s --health-retries 10
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1.23.0
        with:
          elixir-version: "1.19.5"
          otp-version: "28.1.2"
      - uses: actions/cache@v4
        with:
          path: |
            deps
            _build
            priv/plts
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
      - run: mix deps.get
      - run: mix check   # runs format, compile, credo, dialyzer, xref, mix_audit, sobelow
      - run: mix test
```

---

## Supervision Tree (Kiln `application.ex` — target shape)

```elixir
def start(_type, _args) do
  children = [
    KilnWeb.Telemetry,
    Kiln.Repo,
    {Phoenix.PubSub, name: Kiln.PubSub},
    {Finch, name: Kiln.Finch},                                   # pool shared by Req + Anthropix
    {Registry, keys: :unique, name: Kiln.RunRegistry},
    {PartitionSupervisor,                                        # dynamic per-stage processes
      child_spec: DynamicSupervisor.child_spec(strategy: :one_for_one),
      name: Kiln.StageSupervisors},
    {PartitionSupervisor,
      child_spec: Task.Supervisor.child_spec([]),
      name: Kiln.TaskSupervisors},
    {Oban, Application.fetch_env!(:kiln, Oban)},
    Kiln.SandboxJanitor,                                         # GenServer reaping stale Docker containers
    KilnWeb.Endpoint
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: Kiln.Supervisor)
end
```

Grounded in the system-design doc's recommended default tree (`Repo → PubSub → Registry → PartitionSupervisor → Oban → Endpoint`). `Kiln.Finch` is named so Req can use it via `req: [finch: Kiln.Finch]` — this is the correct pattern for shared HTTP pools in Phoenix apps.

---

## Secret Management

**Decision: `config/runtime.exs` for all secret reads. Never `config/config.exs`, never `config/prod.exs`.**

```elixir
# config/runtime.exs
import Config

if config_env() in [:dev, :prod] do
  config :kiln, :anthropic,
    api_key: System.fetch_env!("ANTHROPIC_API_KEY"),
    default_model: System.get_env("KILN_ANTHROPIC_MODEL", "claude-sonnet-4-5")

  config :kiln, :openai,
    api_key: System.get_env("OPENAI_API_KEY")  # optional

  config :kiln, :google,
    api_key: System.get_env("GOOGLE_API_KEY")  # optional

  config :kiln, :ollama,
    base_url: System.get_env("OLLAMA_URL", "http://localhost:11434")

  config :kiln, Kiln.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
end
```

**Why:** `runtime.exs` runs on every boot (release + `mix phx.server`), so secrets are never baked into the release tarball. The Elixir/Phoenix releases guide explicitly recommends this. Dev uses `.env` loaded via `direnv` or a `Mix.Task` wrapper — never commit secrets.

**.env.example** (checked into repo):
```
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=
GOOGLE_API_KEY=
OLLAMA_URL=http://localhost:11434
DATABASE_URL=ecto://kiln:kiln_dev@localhost:5432/kiln_dev
```

**Redact in schemas.** All API-key-bearing config structs use `@derive {Inspect, except: [:api_key]}` or store keys in `persistent_term` with a keyed lookup so they never land in logs, crash dumps, or `Ecto.Changeset` error messages.

---

## Git CLI Wrapping Strategy (GIT-01 → GIT-04)

**Decision: shell out via `System.cmd/3`, with a thin `Kiln.Git` module that normalizes error shapes.**

```elixir
defmodule Kiln.Git do
  @spec run([binary()], keyword()) :: {:ok, binary()} | {:error, {integer(), binary()}}
  def run(args, opts \\ []) do
    cwd = Keyword.fetch!(opts, :cd)  # required: we never accept ambient cwd
    env = build_env(opts)
    case System.cmd("git", args, cd: cwd, env: env, stderr_to_stdout: true) do
      {out, 0} -> {:ok, out}
      {out, exit} -> {:error, {exit, out}}
    end
  end

  # Public helpers wrap run/2:
  def commit(repo, message, opts \\ []),   do: run(["commit", "-m", message], [cd: repo] ++ opts)
  def push(repo, remote, branch, opts),    do: run(["push", remote, branch], [cd: repo] ++ opts)
  def diff(repo, from, to, opts \\ []),    do: run(["diff", from <> ".." <> to], [cd: repo] ++ opts)
  # ...
end
```

**Why not a Hex package?** `git_cli`-ish Hex packages exist but are thin wrappers over exactly this. Kiln needs: (1) deterministic cwd, (2) controlled env (no ambient `GIT_*` leakage), (3) structured `{:ok, out} | {:error, {exit, out}}` returns that fit into Oban retry logic. A 30-line module beats a dependency.

**`gh` CLI (GIT-02, GIT-03):** Same strategy. `Kiln.GitHub` module shells to `gh pr create`, `gh pr view --json`, `gh api /repos/.../actions/runs`. `gh` is already a required operator tool per the spec.

**Idempotency (ORCH-07):** Every `git push` and `gh pr create` goes through an Oban worker with a unique job key of `{run_id, stage_id, "git_push"}`. If the worker retries, we `git show-ref --verify refs/heads/$branch` and confirm the remote already has the commit before re-pushing.

---

## Alternatives Considered (and rejected)

| Recommended | Alternative | When alternative is better | Why we pass |
|---|---|---|---|
| Bandit 1.10 | Cowboy 2.x | You're locked to a Cowboy-specific plug or telemetry. | Default flipped in Phoenix 1.7.11. Bandit is faster, pure Elixir, better protocol conformance. No reason to pick Cowboy for greenfield. |
| Req 0.5 | Finch 0.19 (direct) | Extreme-perf HTTP with custom streaming semantics. | Req already uses Finch. Kiln is not that perf-critical. |
| Req 0.5 | HTTPoison / Tesla | Familiarity with Tesla middleware. | Tesla is fine but Req is the modern Elixir-core maintainer's client with better defaults. HTTPoison is legacy. |
| Oban 2.21 | Broadway + GenStage | High-throughput streaming pipelines with backpressure (Kafka/SQS). | Kiln's jobs are workflow stages — low volume, high durability. Oban's transactional insert is the right primitive. |
| yaml_elixir | fast_yaml | Parsing gigabyte YAML files. | Adds C build dependency. Not worth it at Kiln scale. |
| JSV | ex_json_schema (jonasschmidt) | Schemas written against Draft 4. | JSV is Draft 2020-12. Kiln's workflow schema should be authored against 2020-12 from day one. |
| anthropix + roll-own for others | `langchain_elixir` / `bumblebee` all-in-one | You want a unified in-Elixir LangChain analog with prompt templates, chains, memory. | LangChain's abstractions actively fight Kiln's architecture. Kiln owns workflow graphs; LangChain wants to own them. Bumblebee is for running models *locally*, which is explicitly out-of-scope (Ollama handles that via its HTTP API). |
| `System.cmd("docker", ...)` | `ex_docker_api` / `bearice/elixir-docker` | Pure-Elixir unit-tested container lifecycle. | Those libs are under-maintained and thin over the same Engine API that `docker_engine_api` wraps. The CLI is the source of truth operators actually use. |
| `System.cmd("git", ...)` | `nerves_git` / `git_cli` / `libgit2` NIFs | Need in-process git ops for perf or security. | Shell-out is 100% compatible with user's git config, credential helpers, SSH keys. NIFs that crash take down the BEAM. |
| Dialyzer | No types / Gradient / type-check-only | You already shipped and want faster CI. | The Elixir 1.19 type-checker + Dialyzer + `@spec` on context boundaries is the belt-and-suspenders config. CI gate is optional but recommended. |
| PostgreSQL 16 | SQLite (via Oban's SQLite engine) | Zero-ops demo mode. | Audit ledger (OBS-03), PubSub eventual cluster support, `citext`, and Ecto.Multi with advisory locks all assume Postgres. SQLite mode would require re-testing every migration and job query. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|---|---|---|
| **Cowboy (plug_cowboy)** as production Phoenix server | Phoenix 1.7.11+ ships Bandit by default; Cowboy is in maintenance. Bandit is faster and passes h2spec/Autobahn 100%. | Bandit 1.10+ |
| **Poison** JSON library | Replaced by the stdlib `JSON` module (available on the current Elixir 1.19.5/OTP 28.1+ baseline) and by `Jason` for anything the stdlib does not cover. | Elixir 1.19's `JSON` stdlib module (already used by Phoenix 1.8 generators) |
| **HTTPoison** | Legacy hackney-based client. Blocks scheduler on CPU-heavy TLS; weaker connection reuse than Finch. | Req |
| **ex_json_schema** (jonasschmidt/ex_json_schema) | Draft 4 only; dormant. | JSV 0.18 |
| **fast_yaml** | C NIF build-time dependency for no meaningful runtime win at Kiln scale. | yaml_elixir |
| **Timex** for date math | Elixir's built-in `Calendar`, `Date`, `DateTime`, `Duration` modules (Elixir 1.17 added Durations) cover 95% of needs. Timex adds deps + its own pitfalls. | `Calendar.strftime/3`, `DateTime.shift/2`, `Date.range/3` |
| **meck / mock** for Elixir tests | Compile-time module replacement; breaks concurrency; Dashbit explicitly argues against this pattern. | Mox + behaviour-based adapters |
| **Floki** in LiveViewTest | LiveView 1.1 replaced it with LazyHTML. Floki selectors will silently not match. | LazyHTML via LiveViewTest helpers |
| **Distillery / ad-hoc release scripts** | Superseded by `mix release` (Elixir 1.9+). | `mix release` |
| **Phoenix 1.7** in greenfield | 1.8 has scopes, new auth generators, improved Bandit integration, and is the current docs baseline. | Phoenix 1.8.5 |
| **Erlang cookies as authentication** for clustered distribution | Not cryptographic; plaintext handshake. | Not relevant for v1 (single-node); use TLS distribution + cookie rotation if Kiln ever clusters. |
| **"One GenServer for Kiln state"** | Kiln's stage/run/agent processes are the right boundary; a central GenServer becomes a bottleneck per the anti-pattern guides. | OTP supervision tree + DynamicSupervisor + Registry |

---

## Version Compatibility Notes

| Package | Compatible with | Notes |
|---|---|---|
| Elixir 1.19.5 | OTP 28.1+ | Required. Kiln pins OTP 28.1+ to keep the type-checker and `mix xref` improvements that Elixir 1.19 depends on. |
| Phoenix 1.8.5 | Elixir 1.14+ | Generators assume Bandit + LiveView 1.1. |
| LiveView 1.1.28 | Phoenix 1.7+ | LazyHTML test matcher replaces Floki. Do not mix Floki selectors in new tests. |
| Ecto 3.13.5 | Elixir 1.14+ | `Repo.transact/2` replaces deprecated `Repo.transaction/2` — use the new name. |
| Oban 2.21.1 | Postgres 14+ (for partitioned jobs table) | OSS edition supports insert, unique, cron, prune, retry — sufficient for v1. |
| opentelemetry_phoenix 2.x | Bandit | Must call `OpentelemetryPhoenix.setup(adapter: :bandit)` + include `opentelemetry_bandit` or spans are incomplete. |
| Anthropix 0.6.2 | Anthropic API 2024-10-22+ | Supports tool use, streaming, extended thinking, prompt caching. Unofficial, single maintainer — wrap behind adapter behaviour. |
| Postgrex 0.22.0 | Postgres 9.0–17 | 16 confirmed. `:replication_connection` useful if we stream audit ledger later. |

---

## Stale items in existing `/prompts/` docs (flagged for roadmap)

Read this list as *minor* corrections to otherwise excellent docs — the architectural guidance in those files is sound and should still be followed.

1. **`elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md`** correctly notes Elixir 1.19.x is current on OTP 28.x. **Resolved:** `PROJECT.md` Constraints block now reads `Elixir 1.19.5+/OTP 28.1+`, matching this research baseline (see Phase 1 Plan 07, D-53).
2. **`elixir-best-practices-deep-research.md`** is explicitly ambivalent about Dialyzer. For Kiln I recommend enabling it anyway — the LLM adapter behaviour + Ecto context boundaries are exactly where `@spec`s pay. Treat this as an opinion difference, not a correction.
3. **`elixir-search-lib-deep-research.md`** targets a hypothetical search-library project (Typesense/Meilisearch) — irrelevant to Kiln's v1. Keep in `prompts/` as reference context but do not wire search into Kiln.
4. **`phoenix-best-practices-deep-research.md`** mentions Phoenix 1.7/1.8 interchangeably in places; new Kiln code should target 1.8 conventions explicitly (`~p`, scopes, `<.form>` with `to_form/1`, function components over LiveComponents).
5. **`phoenix-live-view-best-practices-deep-research.md`** is current (as of April 2026) on LiveView 1.1. No corrections.
6. **`ecto-best-practices-deep-research.md`** notes `Repo.transaction/2` is deprecated in favor of `Repo.transact/2`. **Verified; use `Repo.transact/2` in new code.**

---

## Confidence Summary

| Area | Confidence | Notes |
|---|---|---|
| Core BEAM + Phoenix + Ecto stack | **HIGH** | All versions verified against Hex.pm and docs current as of April 2026. |
| Oban (OSS) + Oban Web (now OSS) | **HIGH** | Oban 2.21.1 verified; Oban Web 2.12.2 under Apache-2.0 verified. |
| Bandit as HTTP server | **HIGH** | Phoenix default since 1.7.11; perf + compliance claims verified. |
| Req as HTTP client | **HIGH** | Maintained by Elixir core team member; built on Finch. |
| OpenTelemetry traces | **HIGH** | Traces API stable; phoenix/bandit/ecto/oban instrumentation packages available. |
| OpenTelemetry metrics/logs | **MEDIUM** | Still marked development in the Erlang SDK as of April 2026; use `:telemetry` + LiveDashboard for metrics in v1. |
| YAML parsing (yaml_elixir) + JSON Schema (JSV) | **HIGH** | Both current and actively maintained. |
| Anthropix for Anthropic | **MEDIUM** | Unofficial; single maintainer; wrap behind our adapter behaviour so a swap is <1 day. |
| Rolling own OpenAI/Google/Ollama adapters | **MEDIUM** | Low risk because the APIs are small and Req's step model is friendly. |
| `System.cmd("docker", ...)` wrapping | **HIGH** | Standard pattern; shell is the canonical Docker interface. |
| `System.cmd("git", ...)` + `gh` wrapping | **HIGH** | Standard pattern; idempotency handled at Oban layer. |
| Testing stack (ExUnit + Mox + StreamData + testcontainers) | **HIGH** | All current, idiomatic, battle-tested. |
| Static analysis + security (Credo + Dialyxir + sobelow + mix_audit + ex_check) | **HIGH** | Standard Phoenix CI stack; ex_check composes them cleanly. |
| asdf + Docker Compose + GitHub Actions | **HIGH** | `erlef/setup-beam@v1.23.0` verified current. |

---

## Sources

### Verified against official docs / Hex.pm / GitHub releases
- [Elixir v1.19 release announcement](https://elixir-lang.org/blog/2025/10/16/elixir-v1-19-0-released/) — confirmed 1.19.5 stable on OTP 28.
- [Elixir install page](https://elixir-lang.org/install.html) — asdf pinning pattern.
- [Phoenix LiveView changelog](https://hexdocs.pm/phoenix_live_view/changelog.html) — LiveView 1.1.28 + LazyHTML migration.
- [Phoenix changelog](https://hexdocs.pm/phoenix/changelog.html) — Phoenix 1.8.5.
- [Ecto changelog](https://hexdocs.pm/ecto/changelog.html) — 3.13.5; `Repo.transact/2`.
- [Postgrex changelog](https://hexdocs.pm/postgrex/changelog.html) — 0.22.0 (2026-01-10).
- [Oban on Hex.pm](https://hex.pm/packages/oban) — 2.21.1.
- [Oban Web GitHub](https://github.com/oban-bg/oban_web) — Apache-2.0, v2.12.2.
- [Bandit on HexDocs](https://hexdocs.pm/bandit/) — 1.10.4; Phoenix default since 1.7.11.
- [Req on Hex.pm](https://hex.pm/packages/req) — 0.5.17 (2026-01-05).
- [Anthropix on Hex.pm](https://hex.pm/packages/anthropix) — 0.6.2; unofficial.
- [Claude API Client SDKs](https://platform.claude.com/docs/en/api/client-sdks) — no official Elixir SDK listed.
- [yaml_elixir on Hex.pm](https://hex.pm/packages/yaml_elixir) — 2.12.1 (2026-02-17).
- [JSV docs](https://hexdocs.pm/jsv/) — 0.18.1; full Draft 2020-12 support.
- [OpenTelemetry Erlang](https://opentelemetry.io/docs/languages/erlang/) — SDK 1.6; api 1.4; exporter 1.8.
- [opentelemetry-erlang-contrib](https://github.com/open-telemetry/opentelemetry-erlang-contrib) — phoenix, ecto, oban, bandit instrumentations.
- [logger_json on HexDocs](https://hexdocs.pm/logger_json/) — 7.0.4.
- [Mox on HexDocs](https://hexdocs.pm/mox/Mox.html) — 1.2.0; Dashbit-maintained.
- [StreamData on Hex.pm](https://hex.pm/packages/stream_data) — 1.3.0.
- [testcontainers-elixir](https://github.com/testcontainers/testcontainers-elixir) — 1.13.3.
- [docker-engine-api-elixir](https://github.com/jarlah/docker-engine-api-elixir) — 1.43.
- [Credo on HexDocs](https://hexdocs.pm/credo/) — 1.7.16.
- [ex_check](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html) — 0.16.0; composes credo/dialyzer/sobelow/mix_audit.
- [mix_audit on Hex.pm](https://hex.pm/packages/mix_audit) — ~> 2.1.
- [sobelow GitHub](https://github.com/nccgroup/sobelow) — Phoenix security static analysis.
- [erlef/setup-beam releases](https://github.com/erlef/setup-beam/releases) — v1.23.0 (2026-03-14).
- [A Breakdown of HTTP Clients in Elixir](https://andrealeopardi.com/posts/breakdown-of-http-clients-in-elixir/) — Req-on-Finch rationale.
- [Dashbit: Mocks and explicit contracts](https://dashbit.co/blog/mocks-and-explicit-contracts) — behaviour-based testing discipline.

### Internal references (consumed, not re-derived)
- `/Users/jon/projects/kiln/prompts/elixir-best-practices-deep-research.md`
- `/Users/jon/projects/kiln/prompts/phoenix-best-practices-deep-research.md`
- `/Users/jon/projects/kiln/prompts/phoenix-live-view-best-practices-deep-research.md`
- `/Users/jon/projects/kiln/prompts/ecto-best-practices-deep-research.md`
- `/Users/jon/projects/kiln/prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md`
- `/Users/jon/projects/kiln/prompts/dark_software_factory_context_window.md`
- `/Users/jon/projects/kiln/.planning/PROJECT.md`

---
*Stack research for: Kiln — software dark factory*
*Researched: 2026-04-18*
