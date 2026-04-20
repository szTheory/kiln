# Phase 3: Agent Adapter, Sandbox, DTU & Safety — Pattern Map

**Mapped:** 2026-04-20
**Files analyzed:** 57 new / 8 modified
**Analogs found:** 52 / 57

This document is the pattern bridge between Phase 3 research/context and the planner. It extracts concrete Phase-1/Phase-2 analogs for each new/modified file, with copy-ready code excerpts and line references. Where no analog exists, it flags the gap so the planner uses `03-RESEARCH.md` patterns instead.

---

## Reading Guide for the Planner

Each `###` entry below names:

- The **new or modified file** and its role/data-flow classification.
- The **closest existing analog** — always a file under `lib/` or `test/` that already ships in Kiln.
- One or more **concrete code excerpts** (with line numbers) the planner should copy into the plan action section.
- Where the new file **diverges** from the analog (if it does).

The planner should reference excerpts by file path and line number rather than copy them into PLAN files verbatim — the executor reads the analog directly.

---

## File Classification

### New modules (lib/)

| New File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|
| `lib/kiln/secrets.ex` | context-facade | lookup / persistent_term | `lib/kiln/stages/contract_registry.ex` + `lib/kiln/audit.ex` | role-match |
| `lib/kiln/secrets/ref.ex` | struct / redaction | value-wrapper | `lib/kiln/external_operations/operation.ex` (`@derive`) | role-match |
| `lib/kiln/blockers.ex` | context-facade | registry dispatch | `lib/kiln/audit.ex` | role-match |
| `lib/kiln/blockers/reason.ex` | enum SSOT | pure data | `lib/kiln/audit/event_kind.ex` | **exact** |
| `lib/kiln/blockers/playbook.ex` | struct / rendered output | pure data | `lib/kiln/audit/event.ex` (struct) | partial |
| `lib/kiln/blockers/playbook_registry.ex` | compile-time registry | file-IO at compile | `lib/kiln/audit/schema_registry.ex` | **exact** |
| `lib/kiln/notifications.ex` | shell-out / external-op | System.cmd → intent → ack | `lib/kiln/external_operations.ex` + `lib/kiln/external_operations/pruner.ex` | role-match |
| `lib/kiln/model_registry.ex` | context-facade | compile-time preset lookup | `lib/kiln/stages/contract_registry.ex` | role-match |
| `lib/kiln/model_registry/preset.ex` | struct | pure data | `lib/kiln/workflows/compiled_graph.ex` (not read — naming-only precedent) | partial |
| `lib/kiln/pricing.ex` | pure calc | pricing-table lookup | `lib/kiln/stages/contract_registry.ex` (compile-time load) | role-match |
| `lib/kiln/agents/adapter.ex` | behaviour | callback contract | `lib/kiln/sandboxes.ex` (stub) — no existing behaviour; closest real behaviour usage is `Oban.Worker` via `Kiln.Oban.BaseWorker` | partial |
| `lib/kiln/agents/prompt.ex` | struct | pure data | `lib/kiln/external_operations/operation.ex` (struct w/ `@derive Jason.Encoder only:`) | partial |
| `lib/kiln/agents/response.ex` | struct | pure data | same as above | partial |
| `lib/kiln/agents/structured_output.ex` | pure facade | request → JSV validate → retry | `lib/kiln/workflows/loader.ex` (validate-pipeline) | role-match |
| `lib/kiln/agents/budget_guard.ex` | pure function + telemetry + raise | pre-flight gate | `lib/kiln/policies/stuck_detector.ex` (`check/1` hook) | role-match |
| `lib/kiln/agents/session_supervisor.ex` | DynamicSupervisor | supervision | `lib/kiln/runs/run_supervisor.ex` | **exact** |
| `lib/kiln/agents/adapter/anthropic.ex` | behaviour impl (live) | HTTP → telemetry → audit | `lib/kiln/external_operations/pruner.ex` (Oban worker pattern, role-only match) | partial — use `03-RESEARCH.md` Anthropix snippets |
| `lib/kiln/agents/adapter/openai.ex` | behaviour impl (scaffold) | Req + Mox contract | no direct analog | **none** — use `03-RESEARCH.md` |
| `lib/kiln/agents/adapter/google.ex` | behaviour impl (scaffold) | Req + Mox contract | no direct analog | **none** |
| `lib/kiln/agents/adapter/ollama.ex` | behaviour impl (scaffold) | Req + Mox contract | no direct analog | **none** |
| `lib/kiln/sandboxes/driver.ex` | behaviour | callback contract | (same as `adapter.ex`) | partial |
| `lib/kiln/sandboxes/docker_driver.ex` | shell-out / external-op | `MuonTrap.cmd → telemetry → intent` | `lib/kiln/external_operations/pruner.ex` + `lib/kiln/external_operations.ex` | role-match |
| `lib/kiln/sandboxes/env_builder.ex` | pure function (allowlist) | map → envfile | `lib/kiln/logger/metadata.ex` (`default_filter/2`) | partial |
| `lib/kiln/sandboxes/hydrator.ex` | pure function | CAS read → /workspace | `lib/kiln/artifacts.ex` (`get/2`, `stream!/1`) | role-match |
| `lib/kiln/sandboxes/harvester.ex` | pure function | /workspace → CAS write + audit in tx | `lib/kiln/artifacts.ex` (`put/4`) | **exact** |
| `lib/kiln/sandboxes/image_resolver.ex` | pure calc | Map lookup | `lib/kiln/stages/contract_registry.ex` | partial |
| `lib/kiln/sandboxes/limits.ex` | pure / persistent_term | YAML load at boot | `lib/kiln/workflows/schema_registry.ex` (compile-time file load) | role-match |
| `lib/kiln/sandboxes/container_spec.ex` | struct | pure data | `lib/kiln/external_operations/operation.ex` | role-match |
| `lib/kiln/sandboxes/orphan_sweeper.ex` | GenServer | boot-scan + telemetry | `lib/kiln/runs/run_director.ex` | role-match |
| `lib/kiln/sandboxes/supervisor.ex` | Supervisor | `:one_for_one` | `lib/kiln/runs/run_supervisor.ex` | role-match |
| `lib/kiln/sandboxes/dtu/supervisor.ex` | Supervisor | `:one_for_one` | same | role-match |
| `lib/kiln/sandboxes/dtu/health_poll.ex` | GenServer | periodic HTTP GET + PubSub | `lib/kiln/runs/run_director.ex` (periodic-scan pattern) | role-match |
| `lib/kiln/sandboxes/dtu/contract_test.ex` | Oban worker (stub) | scheduled no-op | `lib/kiln/artifacts/gc_worker.ex` | **exact** |
| `lib/kiln/sandboxes/dtu/callback_router.ex` | Plug router | HTTP POST → audit | (no Plug router exists yet in Kiln) | **none** |
| `lib/kiln/policies/factory_circuit_breaker.ex` | GenServer (no-op) | scaffolded hook | `lib/kiln/policies/stuck_detector.ex` | **exact** |
| `lib/kiln/stages/next_stage_dispatcher.ex` | pure module | graph walk → Oban insert | `lib/kiln/stages/stage_worker.ex` (`maybe_transition_after_stage/2`) | role-match |
| `lib/kiln/logging/secret_redactor.ex` | LoggerJSON.Redactor impl | structured-log filter | `lib/kiln/logger/metadata.ex` (`default_filter/2`) | role-match |

### Modified modules (lib/)

| Modified File | Change | Analog Pattern |
|---|---|---|
| `lib/kiln/application.ex` | insert 4 new supervision children before `RunDirector` | existing `start/2` (see lines 34–44) |
| `lib/kiln/agents.ex` | replace stub moduledoc; add top-level `@behaviour` doc refs | `lib/kiln/runs.ex` pattern (narrow public-read API) |
| `lib/kiln/sandboxes.ex` | rewrite INCORRECT "Phase 4" moduledoc → D-111..D-120 | `lib/kiln/runs.ex` / `lib/kiln/artifacts.ex` |
| `lib/kiln/boot_checks.ex` | extend 6 → 8 invariants (`secrets_presence_map_non_empty`, `no_prior_boot_sandbox_orphans`) | existing `run!/0` structure (lines 115–132) |
| `lib/kiln/audit/event_kind.ex` | extend 25 → 30 atoms (D-145 list) | existing `@kinds` list (lines 34–61) — APPEND only |
| `lib/kiln/runs/run_director.ex` | `start_run/1` adds `Kiln.Secrets.present?/1` check raising `:missing_api_key` before any LLM call | existing `assert_workflow_unchanged/1` pattern (lines 176–204) |
| `lib/kiln/stages/stage_worker.ex` | call `Kiln.Stages.NextStageDispatcher` after successful stage completion inside the same stage-completion tx | existing `maybe_transition_after_stage/2` (lines 185–215) |
| `config/config.exs` | register `Kiln.Logging.SecretRedactor` under `:logger_json`; ship Finch named pools per provider (consolidated into existing `Kiln.Finch` child) | existing LoggerJSON block (lines 117–131) + Oban block (lines 79–100) |
| `config/runtime.exs` | read `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `GOOGLE_API_KEY` / `OLLAMA_HOST` + `Kiln.Secrets.put/2` at startup | existing prod-only DB/secret reads (lines 36–74) |

### Priv data files (new)

| New File | Role | Analog |
|---|---|---|
| `priv/sandbox/base.Dockerfile` + `priv/sandbox/elixir.Dockerfile` | build input | none (no Dockerfile exists yet) |
| `priv/sandbox/limits.yaml` | YAML config | `priv/workflows/elixir_phoenix_feature.yaml` (YAML parse pattern) |
| `priv/sandbox/images.lock` | pinned digests | none |
| `priv/playbooks/v1/<reason>.md` (9 files) | markdown + YAML frontmatter | none yet — 4th instance of compile-time-registry pattern |
| `priv/playbook_schemas/v1/playbook.json` | JSV Draft 2020-12 | `priv/workflow_schemas/v1/workflow.json` + `priv/audit_schemas/v1/*.json` |
| `priv/model_registry/<preset>.exs` (6 files) | Elixir data | no direct analog (first Elixir-file-as-data in priv) |
| `priv/pricing/v1/<provider>.exs` (4 files) | Elixir data | same |
| `priv/dtu/mix.exs` + `priv/dtu/Dockerfile` + `priv/dtu/lib/kiln_dtu/**` | separate mini-mix-project | none |
| `priv/dtu/contracts/github/api.github.com.2026-04.json` | OpenAPI 3.1 | none |
| `priv/audit_schemas/v1/<new kind>.json` (8 files) | JSV schema | existing `priv/audit_schemas/v1/stage_started.json` etc. |

### New test files (test/)

| New File | Role | Analog |
|---|---|---|
| `test/kiln/agents/adapter_contract_test.exs` | Mox-based behaviour contract | no prior Mox usage yet | none |
| `test/kiln/agents/budget_guard_test.exs` | pre-flight logic | `test/kiln/policies/stuck_detector_test.exs` | **exact** |
| `test/kiln/agents/structured_output_test.exs` | JSV validate + retry | `test/kiln/stages/contract_registry_test.exs` | role-match |
| `test/kiln/agents/adapter/anthropic_test.exs` | Req.Test mocked Anthropic | none | none |
| `test/kiln/sandboxes/docker_driver_test.exs` | MuonTrap + docker CLI | none | none |
| `test/kiln/sandboxes/egress_blocking_test.exs` | **adversarial / SC#2** | none — new category | none |
| `test/kiln/sandboxes/hydrator_test.exs` | CAS → /workspace | `test/kiln/artifacts/cas_test.exs` | role-match |
| `test/kiln/sandboxes/harvester_test.exs` | /workspace → CAS + audit | same | role-match |
| `test/kiln/sandboxes/env_builder_test.exs` | allowlist enforcement | `test/kiln/logger/*` (not listed — use metadata tests pattern) | partial |
| `test/kiln/sandboxes/orphan_sweeper_test.exs` | GenServer + docker label filter | `test/kiln/runs/run_director_test.exs` | role-match |
| `test/kiln/sandboxes/dtu/router_test.exs` | Plug + JSV validate | none | none |
| `test/kiln/sandboxes/dtu/health_poll_test.exs` | periodic GenServer | `test/kiln/runs/run_director_test.exs` | role-match |
| `test/kiln/blockers/reason_test.exs` | enum SSOT tests | `test/kiln/audit/event_kind_test.exs` (if present — pattern assumed from analog audit tests) | **exact** |
| `test/kiln/blockers/playbook_registry_test.exs` | compile-time registry | `test/kiln/workflows/schema_registry_test.exs` | **exact** |
| `test/kiln/policies/factory_circuit_breaker_test.exs` | no-op supervised GenServer | `test/kiln/policies/stuck_detector_test.exs` | **exact** |
| `test/kiln/secrets_test.exs` | persistent_term + Ref inspect | none | none |
| `test/kiln/model_registry_test.exs` | preset resolution + fallback | `test/kiln/workflows/compiler_test.exs` (nearby — graph resolution) | partial |
| `test/integration/secrets_never_leak_test.exs` | **adversarial / SC#6** | none | none |
| `test/kiln/stages/next_stage_dispatcher_test.exs` | Oban enqueue verification | `test/kiln/stages/stage_worker_test.exs` | **exact** |

---

## Pattern Assignments

### 1. Compile-time registry from `priv/<thing>/v1/<name>.<ext>` (FOURTH instance)

**Applies to:**
- `lib/kiln/blockers/playbook_registry.ex` (markdown + YAML frontmatter under `priv/playbooks/v1/<reason>.md`)
- `lib/kiln/model_registry.ex` (Elixir `.exs` files under `priv/model_registry/`)
- `lib/kiln/pricing.ex` (Elixir `.exs` files under `priv/pricing/v1/`)
- `lib/kiln/sandboxes/limits.ex` (YAML under `priv/sandbox/limits.yaml`)

**Analog file:** `lib/kiln/audit/schema_registry.ex` (lines 1–68)
**Sibling precedents:** `lib/kiln/workflows/schema_registry.ex`, `lib/kiln/stages/contract_registry.ex`.

**Core pattern to copy (schema_registry.ex lines 22–67):**

```elixir
@schemas_dir Path.expand("../../../priv/audit_schemas/v1", __DIR__)

@build_opts [default_meta: "https://json-schema.org/draft/2020-12/schema"]

@schemas (for kind <- EventKind.values(), into: %{} do
            path = Path.join(@schemas_dir, "#{kind}.json")

            # Mark every schema file as an external resource so a change
            # triggers recompile of this module.
            @external_resource path

            case File.read(path) do
              {:ok, json} ->
                raw = Jason.decode!(json)
                root = JSV.build!(raw, @build_opts)
                {kind, root}

              {:error, :enoent} ->
                {kind, :missing}
            end
          end)

@spec fetch(atom()) :: {:ok, JSV.Root.t()} | {:error, :schema_missing}
def fetch(kind) when is_atom(kind) do
  case Map.get(@schemas, kind, :missing) do
    :missing -> {:error, :schema_missing}
    root -> {:ok, root}
  end
end
```

**Diverges for `PlaybookRegistry`:**
- Parse markdown body via `String.split(raw, ~r/^---\n/, parts: 3)` (no dep needed — inline splitter) to separate `---\n<yaml>\n---\n<body>`.
- Use `YamlElixir.read_from_string/1` on frontmatter, then `JSV.validate/2` against `priv/playbook_schemas/v1/playbook.json` root.
- Store `%{reason => %Playbook{frontmatter: map, body_markdown: binary}}`.
- Expose `render(reason, context_map)` that does Mustache `{var}` substitution into `short_message`/`title`/`body_markdown`.

**Diverges for `ModelRegistry`:**
- Files are `.exs` not `.json`. Use `Code.eval_file/1` inside the module-attribute `for`-comprehension (captured at compile time), and `@external_resource path` per file.
- The six presets are `@presets ~w(elixir_lib phoenix_saas_feature typescript_web_feature python_cli bugfix_critical docs_update)a`.

**Diverges for `Pricing`:**
- Same as ModelRegistry but four provider files (`anthropic`, `openai`, `google`, `ollama`).

**Diverges for `Limits`:**
- YAML file, one file not N. Use `YamlElixir.read_from_file/1` at compile time (not at boot — adopt `:persistent_term` instead per D-112).
- Alternative per Claude's-discretion: boot-time load via `Application.start/2` hook writing to `:persistent_term` keyed by `{Kiln.Sandboxes.Limits, :limits}`.

---

### 2. Scaffold-now-fill-later supervised no-op GenServer (SECOND instance)

**Applies to:** `lib/kiln/policies/factory_circuit_breaker.ex`

**Analog file:** `lib/kiln/policies/stuck_detector.ex` (lines 1–74) — EXACT PATTERN.

**Core pattern to copy verbatim (stuck_detector.ex lines 36–74):**

```elixir
use GenServer

@spec start_link(keyword()) :: GenServer.on_start()
def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

@doc """
Synchronous hook called from inside <caller>. Returns `:ok` in Phase 3
(no-op body); Phase 5 replaces only the `handle_call/3` body with the
sliding-window threshold logic.

Signature is locked through Phase 5 — callers never change.
"""
@spec check(map()) :: :ok | {:halt, atom(), map()}
def check(ctx) when is_map(ctx), do: GenServer.call(__MODULE__, {:check, ctx})

@impl true
def init(_opts), do: {:ok, %{}}

@impl true
def handle_call({:check, _ctx}, _from, state) do
  # Phase 3: no-op — the hook PATH is the behavior to exercise. Phase 5
  # fills the sliding-window body. Stable return shape:
  #   :ok | {:halt, reason :: atom(), payload :: map()}
  {:reply, :ok, state}
end
```

**Test pattern — copy verbatim from `test/kiln/policies/stuck_detector_test.exs`:**

```elixir
use Kiln.StuckDetectorCase, async: false
# Phase 3 will need a sibling Kiln.FactoryCircuitBreakerCase support module
# if the test helper shape ends up identical.

test "check/1 returns :ok for any map (no-op body P3)" do
  assert :ok == FactoryCircuitBreaker.check(%{run: :fake, spend_last_60min_usd: Decimal.new("0")})
end
```

---

### 3. Supervision child insertion (14-child tree; D-141 / D-142)

**Applies to:** `lib/kiln/application.ex` (modification).

**Analog file:** `lib/kiln/application.ex` (lines 30–73) — existing staged-boot pattern stays.

**Current infra-children block (lines 34–44):**

```elixir
infra_children = [
  KilnWeb.Telemetry,
  Kiln.Repo,
  {Phoenix.PubSub, name: Kiln.PubSub},
  {Finch, name: Kiln.Finch},
  {Registry, keys: :unique, name: Kiln.RunRegistry},
  {Oban, Application.fetch_env!(:kiln, Oban)},
  Kiln.Runs.RunSupervisor,
  {Kiln.Runs.RunDirector, []},
  Kiln.Policies.StuckDetector
]
```

**Phase 3 target — insert the 4 new children before `RunDirector` (D-120 requires OrphanSweeper boots before `RunDirector`):**

```elixir
infra_children = [
  KilnWeb.Telemetry,
  Kiln.Repo,
  {Phoenix.PubSub, name: Kiln.PubSub},
  # D-109 — Finch stays as ONE child; named pools per provider configured via:
  {Finch,
   name: Kiln.Finch,
   pools: %{
     "https://api.anthropic.com" => [size: 10, count: 1],
     "https://api.openai.com" => [size: 10, count: 1],
     "https://generativelanguage.googleapis.com" => [size: 10, count: 1],
     :default => [size: 10, count: 1]
   }},
  {Registry, keys: :unique, name: Kiln.RunRegistry},
  {Oban, Application.fetch_env!(:kiln, Oban)},
  # D-141 new children — inserted BEFORE RunDirector:
  Kiln.Sandboxes.Supervisor,
  Kiln.Sandboxes.DTU.Supervisor,
  Kiln.Agents.SessionSupervisor,
  Kiln.Policies.FactoryCircuitBreaker,
  Kiln.Runs.RunSupervisor,
  {Kiln.Runs.RunDirector, []},
  Kiln.Policies.StuckDetector
]
```

**Critical — do NOT add separate `Kiln.Finch.Anthropic`/etc. children:** Finch natively supports named pools per host inside a single supervisor child. Adding 4 separate Finch processes would raise child count to 17 and break D-142's 14-child lock.

**BootChecks already raises if the 14-child invariant drifts** (via `test/kiln/application_test.exs`). Update that test's expected count to 14.

---

### 4. BootChecks invariant extension (6 → 8)

**Applies to:** `lib/kiln/boot_checks.ex`.

**Analog file:** `lib/kiln/boot_checks.ex` itself (lines 115–132 `run!/0`, lines 396–411 `check_workflow_schema_loads!/0`, lines 420–447 `check_required_secrets!/0`).

**Pattern for new invariant 7 (`secrets_presence_map_non_empty`) — mirror `check_required_secrets!/0` (lines 420–447):**

```elixir
# -----------------------------------------------------------------
# Invariant: :secrets_presence_map_non_empty (D-131 / D-143)
# -----------------------------------------------------------------
#
# In :prod, ≥1 provider key MUST be present. In :dev, this is
# warn-only (so a fresh clone without .env doesn't break `iex -S mix`).
# Always logs a structured presence map so the operator sees which
# providers are live.
defp check_secrets_presence_map_non_empty! do
  env = Application.get_env(:kiln, :env, :prod)

  {present, missing} =
    [:anthropic_api_key, :openai_api_key, :google_api_key, :ollama_host]
    |> Enum.split_with(&Kiln.Secrets.present?/1)

  Logger.info(
    "provider_keys_loaded=#{inspect(present)} provider_keys_missing=#{inspect(missing)}"
  )

  case {env, present} do
    {:prod, []} ->
      raise Error,
        invariant: :secrets_presence_map_non_empty,
        details: %{present: present, missing: missing, env: env},
        remediation_hint:
          "At least one provider API key must be present in :prod. " <>
            "Set ANTHROPIC_API_KEY (or another provider) before booting."

    _ ->
      :ok
  end
end
```

**Pattern for new invariant 8 (`no_prior_boot_sandbox_orphans`) — mirror the probe pattern (lines 270–331) combined with shell-out:**

- Use `ex_docker_engine_api` for introspection (not `System.cmd` — the CONTEXT specifies `ex_docker_engine_api` for LIST; `System.cmd("docker", ["rm", "-f", ...])` for DESTROY).
- Filter by label `kiln.boot_epoch` ≠ current boot epoch.
- Emit one `orphan_container_swept` audit event per container.
- Fatal only when `docker` CLI is unreachable (not when the list is non-empty — sweeping IS the cure).

**Extend `run!/0` (insert at line 129, after `check_required_secrets!()`):**

```elixir
check_required_secrets!()
check_secrets_presence_map_non_empty!()  # invariant 7 — D-143
check_no_prior_boot_sandbox_orphans!()   # invariant 8 — D-143
:ok
```

**Test pattern:** `test/kiln/boot_checks_test.exs` lines 41–57 + describe blocks at lines 60+. Pattern:

```elixir
describe ":secrets_presence_map_non_empty invariant (D-143)" do
  test "raises in :prod when all four provider keys are missing" do
    # use `on_exit` to restore Application.put_env/3 :env
  end

  test "passes in :prod when ≥1 provider key present" do
    # seed Kiln.Secrets with a single anthropic_api_key via Secrets.put/2
  end

  test "warns only (no raise) in :dev even with zero keys" do
    # capture_log + assert message substring
  end
end
```

---

### 5. Audit event kind taxonomy extension (25 → 30)

**Applies to:** `lib/kiln/audit/event_kind.ex`.

**Analog file:** `lib/kiln/audit/event_kind.ex` (lines 34–61).

**Current list to extend — APPEND ONLY, never reorder (D-145):**

```elixir
@kinds [
  # Phase 1 (22) ...
  :block_raised,
  :block_resolved,
  :escalation_triggered,
  # Phase 2 D-85 extension (3)
  :stage_input_rejected,
  :artifact_written,
  :integrity_violation,
  # Phase 3 D-145 extension (5 new — decision enumerates 8 but
  # notification_fired + notification_suppressed + model_deprecated_resolved
  # + factory_circuit_opened + factory_circuit_closed + dtu_contract_drift_detected
  # + dtu_health_degraded + orphan_container_swept = 8. Confirm target = 30+ during planning.)
  :orphan_container_swept,
  :dtu_contract_drift_detected,
  :dtu_health_degraded,
  :factory_circuit_opened,
  :factory_circuit_closed,
  :model_deprecated_resolved,
  :notification_fired,
  :notification_suppressed
]
```

**Migration pattern — mirror `priv/repo/migrations/20260419000001_extend_audit_event_kinds.exs`:**

The pattern is DROP the old `event_kind IN (...)` CHECK and re-ADD it from `Kiln.Audit.EventKind.values_as_strings/0`. Phase 3 adds a new migration `20260420000001_extend_audit_event_kinds_p3.exs` that does the same DROP-and-re-ADD. The values-as-strings generation (`event_kind.ex` lines 69–74) means the migration body never hard-codes the list — it imports from `Kiln.Audit.EventKind` at generation time.

**JSV schema files to add under `priv/audit_schemas/v1/`:** one JSON Schema Draft 2020-12 per new kind. Mirror an existing minimal schema (e.g., `priv/audit_schemas/v1/stage_started.json`). SchemaRegistry recompiles automatically via `@external_resource`.

---

### 6. Oban worker stub (registered on `:dtu` queue, cron nil)

**Applies to:** `lib/kiln/sandboxes/dtu/contract_test.ex`.

**Analog file:** `lib/kiln/artifacts/gc_worker.ex` (lines 1–33) — EXACT PATTERN.

**Core pattern to copy verbatim (gc_worker.ex lines 26–33):**

```elixir
use Oban.Worker,
  queue: :dtu,
  max_attempts: 1,
  unique: [period: 60 * 60 * 20]

@impl Oban.Worker
def perform(_job), do: :ok
```

**Cron registration — mirror `config/config.exs` lines 93–99** (leave the cron entry COMMENTED OUT; Phase 6 toggles):

```elixir
crontab: [
  {"0 3 * * *", Kiln.ExternalOperations.Pruner, queue: :maintenance}
  # {"0 4 * * 0", Kiln.Sandboxes.DTU.ContractTest, queue: :dtu},  # P6 activation
]
```

---

### 7. Behaviour contract with typed `@callback` specs

**Applies to:** `lib/kiln/agents/adapter.ex`, `lib/kiln/sandboxes/driver.ex`.

**Analog:** Kiln has no `@behaviour` modules yet (all OTP behaviours are framework-provided like `Oban.Worker`, `GenServer`, `Supervisor`). Use the shape from **Oban.Worker's source documentation pattern** AND the `Kiln.Oban.BaseWorker` macro wrapping.

**Pattern (write from first principles — no Kiln analog yet):**

```elixir
defmodule Kiln.Agents.Adapter do
  @moduledoc """
  Behaviour every LLM adapter implements. Phase 3 ships:

    * `Kiln.Agents.Adapter.Anthropic` — LIVE via Anthropix 0.6.2
    * `Kiln.Agents.Adapter.OpenAI` — scaffolded (Req + Mox contract test)
    * `Kiln.Agents.Adapter.Google` — scaffolded
    * `Kiln.Agents.Adapter.Ollama` — scaffolded

  Callers invoke adapters via `Kiln.Agents.complete/2`, `stream/2`, etc.
  which resolves the right adapter via `Kiln.ModelRegistry`.
  """

  alias Kiln.Agents.{Prompt, Response}

  @callback complete(Prompt.t(), keyword()) :: {:ok, Response.t()} | {:error, term()}
  @callback stream(Prompt.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  @callback count_tokens(Prompt.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback capabilities() :: %{
              streaming: boolean(),
              tools: boolean(),
              thinking: boolean(),
              vision: boolean(),
              json_schema_mode: boolean()
            }
end
```

**Note — no `@optional_callbacks` in P3.** D-102 locks all four callbacks as required.

**Mox pattern for contract tests:** add `Mox.defmock(Kiln.Agents.AdapterMock, for: Kiln.Agents.Adapter)` in `test/support/mocks.ex` (new file) and wire up in `test/test_helper.exs` via `Mox.defmock` calls.

---

### 8. External side-effect with two-phase intent (llm_complete, docker_run, osascript_notify, secret_resolve)

**Applies to:**
- `lib/kiln/agents/adapter/anthropic.ex` (kind: `"llm_complete"`, `"llm_stream"`)
- `lib/kiln/sandboxes/docker_driver.ex` (kinds: `"docker_run"`, `"docker_kill"`)
- `lib/kiln/notifications.ex` (kind: `"osascript_notify"`)
- `lib/kiln/secrets.ex` (`reveal!/1` — kind `"secret_resolve"`, audit-only no intent row needed per D-17 semantics; choose during planning)

**Analog file:** `lib/kiln/external_operations.ex` (lines 63–127 for `fetch_or_record_intent/2`; lines 138–170 for `complete_op/2`).

**Core pattern to copy (external_operations.ex lines 85–121):**

```elixir
Repo.transaction(fn ->
  changeset = Operation.changeset(%Operation{}, insert_attrs)

  case Repo.insert(changeset,
         on_conflict: :nothing,
         conflict_target: :idempotency_key
       ) do
    {:ok, %Operation{id: nil}} ->
      # Conflict — re-read with FOR UPDATE to observe the winner's row.
      op =
        Repo.one!(
          from(o in Operation,
            where: o.idempotency_key == ^idempotency_key,
            lock: "FOR UPDATE"
          )
        )
      {:found_existing, op}

    {:ok, %Operation{} = op} ->
      # First writer — append the paired intent audit event in the
      # SAME transaction (D-18).
      {:ok, _ev} =
        Audit.append(%{
          event_kind: :external_op_intent_recorded,
          run_id: op.run_id,
          stage_id: op.stage_id,
          correlation_id: cid,
          payload: %{
            "op_kind" => op.op_kind,
            "idempotency_key" => op.idempotency_key
          }
        })
      {:inserted_new, op}

    {:error, changeset} ->
      Repo.rollback(changeset)
  end
end)
```

**Phase 3 integration — every external side-effect wraps inside the two-phase machine.** Concretely:

```elixir
# Example for Kiln.Agents.Adapter.Anthropic.complete/2
idempotency_key = "run:#{run_id}:stage:#{stage_id}:llm_complete:#{attempt}"

{_status, op} =
  Kiln.ExternalOperations.fetch_or_record_intent(idempotency_key, %{
    op_kind: "llm_complete",
    intent_payload: Prompt.to_audit_shape(prompt),
    run_id: run_id,
    stage_id: stage_id
  })

# SIDE EFFECT HAPPENS HERE — outside the txn, between intent + completion:
case do_anthropix_call(prompt, opts) do
  {:ok, response} ->
    Kiln.ExternalOperations.complete_op(op, %{
      "result" => "ok",
      "tokens_in" => response.tokens_in,
      "tokens_out" => response.tokens_out,
      "actual_model_used" => response.actual_model_used
    })
    {:ok, response}

  {:error, reason} ->
    Kiln.ExternalOperations.fail_op(op, %{"reason" => inspect(reason)})
    {:error, reason}
end
```

---

### 9. Harvester writes to CAS + audit in one Postgres transaction

**Applies to:** `lib/kiln/sandboxes/harvester.ex`.

**Analog file:** `lib/kiln/artifacts.ex` (lines 73–113 `put/4`) — **EXACT PATTERN**.

**Core pattern to copy (artifacts.ex lines 80–113):**

```elixir
with {:ok, sha, size} <- CAS.put_stream(body) do
  Repo.transact(fn ->
    cs =
      Artifact.changeset(%Artifact{}, %{
        stage_run_id: stage_run_id,
        run_id: run_id,
        name: name,
        sha256: sha,
        size_bytes: size,
        content_type: normalize_content_type(content_type),
        schema_version: 1,
        producer_kind: producer_kind
      })

    with {:ok, artifact} <- Repo.insert(cs),
         {:ok, _ev} <-
           Audit.append(%{
             event_kind: :artifact_written,
             run_id: artifact.run_id,
             stage_id: artifact.stage_run_id,
             correlation_id:
               Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
             payload: %{
               "name" => name,
               "sha256" => sha,
               "size_bytes" => size,
               "content_type" => to_string(content_type)
             }
           }) do
      {:ok, artifact}
    end
  end)
end
```

**Harvester shape:** walk `/workspace/out/` via `File.ls!/1`, `File.stat!/1`, wrap each `File.stream!/2` call into the `Artifacts.put/4` call above. The inner transaction pattern is IDENTICAL — one `artifact_written` audit event per output file, one outer iteration writing N artifacts inside N transactions (NOT one giant transaction — transactions per artifact are independent and deadlock-free).

**Hydrator is the mirror:** use `Kiln.Artifacts.get/2` (lines 119–129) + `Kiln.Artifacts.stream!/1` (lines 186–189) or `read!/1` (lines 147–179 if integrity-check is demanded) to rehydrate `/workspace/<artifact_name>` from CAS.

---

### 10. Application-level long-running GenServer with boot-scan + periodic-scan

**Applies to:** `lib/kiln/sandboxes/orphan_sweeper.ex`, `lib/kiln/sandboxes/dtu/health_poll.ex`.

**Analog file:** `lib/kiln/runs/run_director.ex` (lines 70–122) — role-match.

**Core pattern to copy (run_director.ex lines 82–102):**

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

@impl true
def init(_opts) do
  # D-92 — supervisor boot NEVER blocks on the scan. Defer to a
  # self-message so `Kiln.Application.start/2` returns promptly.
  send(self(), :boot_scan)
  {:ok, %{monitors: %{}}}
end

@impl true
def handle_info(:boot_scan, state) do
  state = do_scan(state)
  Process.send_after(self(), :periodic_scan, @periodic_scan_ms)
  {:noreply, state}
end

def handle_info(:periodic_scan, state) do
  state = do_scan(state)
  Process.send_after(self(), :periodic_scan, @periodic_scan_ms)
  {:noreply, state}
end

# Catch-all for unexpected messages — don't crash on stray message.
def handle_info(_msg, state), do: {:noreply, state}
```

**Diverges for `OrphanSweeper`:**
- `do_scan/1` calls `ex_docker_engine_api` container-list (filter `label=kiln.boot_epoch != current`).
- On each orphan: `Kiln.Audit.append(%{event_kind: :orphan_container_swept, ...})` + `System.cmd("docker", ["rm", "-f", id])`.
- Runs ONCE at boot (BootChecks 8th invariant also calls the same sweep synchronously pre-endpoint); the GenServer's periodic-scan is defense-in-depth for long-running hosts.

**Diverges for `HealthPoll`:**
- `do_scan/1` does `Req.get("http://172.28.0.10:80/healthz", finch: Kiln.Finch)`.
- After 3 consecutive misses: `Kiln.Audit.append(%{event_kind: :dtu_health_degraded, ...})` + `Phoenix.PubSub.broadcast(Kiln.PubSub, "dtu_health", {:dtu_unhealthy, reason})` (consumer is Phase 7).

---

### 11. Desktop notification shell-out via `System.cmd` wrapped in external-operations intent

**Applies to:** `lib/kiln/notifications.ex`.

**Analog files:**
- `lib/kiln/external_operations/pruner.ex` (lines 23–64 — `use Oban.Worker` + `Repo.query!` pattern; the SHELL-OUT aspect is not there yet).
- `System.cmd` usage appears only implicitly in docs so far — **P3 introduces the first real `System.cmd` to this codebase**.

**Pattern (synthesise from external_operations.ex + run_director.ex):**

```elixir
defmodule Kiln.Notifications do
  @moduledoc """
  Desktop notifications via `osascript` (macOS) / `notify-send` (Linux),
  dispatched synchronously inside the block-raising transaction via
  `external_operations` two-phase intent (D-140).

  ETS-backed dedup: `{run_id, reason}` with 5-minute TTL. Identical
  key within TTL is silently dropped; audit kind
  `notification_fired` vs `notification_suppressed` recorded either way.
  """

  require Logger
  alias Kiln.ExternalOperations

  @dedup_ttl_seconds 5 * 60

  @spec desktop(atom(), map()) :: :ok
  def desktop(reason, ctx) when is_atom(reason) and is_map(ctx) do
    run_id = Map.get(ctx, :run_id)
    dedup_key = {run_id, reason}

    case check_dedup(dedup_key) do
      :fire ->
        idempotency_key = "notify:#{run_id}:#{reason}:#{System.system_time(:millisecond)}"

        {_status, op} =
          ExternalOperations.fetch_or_record_intent(idempotency_key, %{
            op_kind: "osascript_notify",
            intent_payload: %{reason: Atom.to_string(reason), run_id: run_id},
            run_id: run_id
          })

        case dispatch_platform(ctx) do
          :ok ->
            ExternalOperations.complete_op(op, %{"result" => "fired"})
            audit_fired(reason, run_id, dedup_key)

          {:error, err} ->
            ExternalOperations.fail_op(op, %{"reason" => inspect(err)})
            Logger.error("notification dispatch failed: #{inspect(err)}")
        end

        :ok

      :suppress ->
        audit_suppressed(reason, run_id, dedup_key)
        :ok
    end
  end

  defp dispatch_platform(ctx) do
    case :os.type() do
      {:unix, :darwin} ->
        body = format_body(ctx)
        case System.cmd("osascript", ["-e", "display notification #{inspect(body)} with title \"Kiln\""]) do
          {_out, 0} -> :ok
          {err, code} -> {:error, {code, err}}
        end

      {:unix, :linux} ->
        case System.cmd("notify-send", ["-u", "critical", "-c", "kiln",
               "-h", "string:x-canonical-private-synchronous:#{ctx[:run_id]}_#{ctx[:reason]}",
               "Kiln", format_body(ctx)]) do
          {_out, 0} -> :ok
          {err, code} -> {:error, {code, err}}
        end

      other ->
        {:error, {:unsupported_platform, other}}
    end
  end

  # ... dedup (ETS) + audit_fired + audit_suppressed private helpers
end
```

**Key point the planner must enforce:**
- Use `:os.type/0` at RUNTIME, NOT `Mix.env()` — D-140 explicitly bans `Mix.env()` at runtime per P15 / CLAUDE.md.
- Dedup table must be started as a child of `Kiln.Sandboxes.Supervisor` (or a new `Kiln.Notifications.Supervisor`) via `:ets.new(__MODULE__, [:set, :public, :named_table])` in an `init/1`.

---

### 12. Run-state-transition producer (typed-block raise → `:blocked`)

**Applies to:** `lib/kiln/blockers.ex`, integration with `lib/kiln/runs/run_director.ex`.

**Analog file:** `lib/kiln/runs/transitions.ex` (lines 93–118 `transition/3`).

**Phase 3 integration pattern — block-raising in `Kiln.Agents.BudgetGuard.check!/2`:**

```elixir
defmodule Kiln.Agents.BudgetGuard do
  @moduledoc """
  Pre-flight gate: runs BEFORE every LLM call (D-138). Reads
  `runs.caps_snapshot.max_tokens_usd`, sums completed-stage spend,
  calls adapter's `count_tokens/1`, estimates USD via `Kiln.Pricing`,
  raises typed block on breach.

  **No `KILN_BUDGET_OVERRIDE` escape hatch** — operator must edit
  workflow caps and restart run.
  """

  alias Kiln.{Audit, Pricing, Runs}
  alias Kiln.Runs.Transitions

  @spec check!(Prompt.t(), keyword()) :: :ok | no_return()
  def check!(prompt, opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    stage_id = Keyword.fetch!(opts, :stage_id)
    model = Keyword.fetch!(opts, :model)
    adapter = Keyword.fetch!(opts, :adapter)

    :telemetry.span([:kiln, :agents, :budget_guard, :check], %{run_id: run_id}, fn ->
      run = Runs.get!(run_id)
      cap = Decimal.new(run.caps_snapshot["max_tokens_usd"])
      spent = sum_stage_spend(run_id)
      remaining = Decimal.sub(cap, spent)

      {:ok, tokens_in} = adapter.count_tokens(prompt)
      estimated = Pricing.estimate_usd(model, tokens_in, estimated_output_tokens(prompt))

      if Decimal.compare(estimated, remaining) == :gt do
        # Typed-block producer — transitions run through :blocked with
        # reason :budget_exceeded. Playbook rendered from
        # priv/playbooks/v1/budget_exceeded.md.
        _ =
          Audit.append(%{
            event_kind: :budget_check_failed,
            run_id: run_id,
            stage_id: stage_id,
            correlation_id: Logger.metadata()[:correlation_id],
            payload: %{
              "estimated_usd" => Decimal.to_string(estimated),
              "remaining_usd" => Decimal.to_string(remaining),
              "model" => model
            }
          })

        _ = Transitions.transition(run_id, :blocked, %{reason: :budget_exceeded})
        _ = Kiln.Notifications.desktop(:budget_exceeded, %{run_id: run_id, estimated_usd: estimated})

        raise Kiln.Blockers.BlockedError,
          reason: :budget_exceeded,
          run_id: run_id,
          context: %{estimated_usd: estimated, remaining_usd: remaining}
      else
        _ =
          Audit.append(%{
            event_kind: :budget_check_passed,
            run_id: run_id,
            stage_id: stage_id,
            correlation_id: Logger.metadata()[:correlation_id],
            payload: %{
              "estimated_usd" => Decimal.to_string(estimated),
              "remaining_usd" => Decimal.to_string(remaining)
            }
          })

        {:ok, :ok}
      end
    end)
  end
end
```

**Typed exception pattern — mirror `lib/kiln/runs/illegal_transition_error.ex` (lines 1–47):**

```elixir
defmodule Kiln.Blockers.BlockedError do
  defexception [:reason, :run_id, :context, :message]

  @impl true
  def exception(fields) do
    reason = Keyword.fetch!(fields, :reason)
    run_id = Keyword.fetch!(fields, :run_id)
    context = Keyword.get(fields, :context, %{})

    msg =
      "run blocked with reason=#{inspect(reason)} run_id=#{inspect(run_id)}: " <>
        "#{inspect(context)}"

    struct!(__MODULE__, Keyword.put(fields, :message, msg))
  end
end
```

---

### 13. Telemetry emission with cross-process context (Oban-safe)

**Applies to:** every LLM call in `lib/kiln/agents/adapter/*.ex`; every docker-run call in `lib/kiln/sandboxes/docker_driver.ex`.

**Analog file:** `lib/kiln/telemetry.ex` (lines 33–61 `pack_ctx`/`unpack_ctx`) + `lib/kiln/telemetry/oban_handler.ex` (lines 30–40 attach).

**Pattern (telemetry + unpack at adapter boundary):**

```elixir
def complete(prompt, opts) do
  # Unpack Oban-provided ctx so child log lines + telemetry carry
  # correlation_id / run_id / stage_id through to Anthropic's HTTP call.
  ctx = Keyword.get(opts, :kiln_ctx, %{})
  if map_size(ctx) > 0, do: Kiln.Telemetry.unpack_ctx(ctx)

  meta = %{
    run_id: Logger.metadata()[:run_id],
    stage_id: Logger.metadata()[:stage_id],
    requested_model: opts[:model],
    provider: :anthropic,
    role: opts[:role]
  }

  :telemetry.span([:kiln, :agent, :call], meta, fn ->
    start_time = System.monotonic_time()

    case do_anthropix_call(prompt, opts) do
      {:ok, response} ->
        duration = System.monotonic_time() - start_time

        measurements = %{
          duration_native: duration,
          tokens_in: response.tokens_in,
          tokens_out: response.tokens_out,
          cost_usd: response.cost_usd
        }

        meta_with_actual =
          Map.merge(meta, %{
            actual_model_used: response.actual_model_used,
            fallback?: response.actual_model_used != opts[:model]
          })

        {{:ok, response}, Map.merge(measurements, meta_with_actual)}

      {:error, _} = err ->
        {err, meta}
    end
  end)
end
```

**Attach a Phase 3 handler — mirror `Kiln.Telemetry.ObanHandler.attach/0` (oban_handler.ex lines 30–40):**

```elixir
defmodule Kiln.Agents.TelemetryHandler do
  @handler_id {__MODULE__, :agent_call_lifecycle}

  def attach do
    :telemetry.attach_many(
      @handler_id,
      [
        [:kiln, :agent, :call, :start],
        [:kiln, :agent, :call, :stop],
        [:kiln, :agent, :call, :exception],
        [:kiln, :agent, :stream, :chunk]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:kiln, :agent, :call, :stop], measurements, metadata, _config) do
    # Emit audit event — ONE audit row per LLM call
    Kiln.Audit.append(%{
      event_kind: :model_routing_fallback,
      run_id: metadata.run_id,
      stage_id: metadata.stage_id,
      correlation_id: Logger.metadata()[:correlation_id],
      payload: %{
        "requested_model" => to_string(metadata.requested_model),
        "actual_model_used" => to_string(metadata.actual_model_used),
        "provider" => to_string(metadata.provider),
        "fallback?" => metadata[:fallback?] || false,
        "tokens_in" => measurements.tokens_in,
        "tokens_out" => measurements.tokens_out,
        "cost_usd" => Decimal.to_string(measurements.cost_usd)
      }
    })
  end
end
```

**Attach pattern in `Kiln.Application.start/2`:** insert `_ = Kiln.Agents.TelemetryHandler.attach()` after the existing `ObanHandler.attach()` call (application.ex lines 57–61) in Stage 3.

---

### 14. Mox-based contract test for behaviour

**Applies to:** `test/kiln/agents/adapter_contract_test.exs` + `test/kiln/agents/adapter/*_test.exs`.

**Analog:** No prior Mox usage in this codebase yet — `mox ~> 1.2` is in `mix.exs` line 115 but unused.

**Pattern (write from first principles, mirroring Mox best practices):**

- Add `test/support/mocks.ex` with `Mox.defmock(Kiln.Agents.AdapterMock, for: Kiln.Agents.Adapter)`.
- Call `Mox.defmock/2` from `test/test_helper.exs` so the mock module is defined before any test runs.
- Contract tests assert each real adapter implements the behaviour via `Kiln.Agents.Adapter` as the `for:` target.
- Use `@tag :live_anthropic` (and `@tag :live_openai`, etc.) — tests gated by env-var tags per D-101. In `config/test.exs`, exclude all `:live_*` tags by default; CI runs them only on `main` with real keys.

**Live-test gating — mirror `@moduletag :integration` pattern from `test/integration/workflow_end_to_end_test.exs` line 45:**

```elixir
@moduletag :live_anthropic
# test/test_helper.exs: ExUnit.configure(exclude: [:live_anthropic, :live_openai, :live_google, :live_ollama])
```

---

### 15. Adversarial negative-test suite (SC #2 egress / SC #6 secrets)

**Applies to:** `test/kiln/sandboxes/egress_blocking_test.exs`, `test/integration/secrets_never_leak_test.exs`.

**Analog:** No prior adversarial suite exists — Phase 3 introduces the category.

**Guidance from RESEARCH.md + CONTEXT.md (D-119):** The egress-blocking suite must test ALL FIVE vectors against a real stage container:

```elixir
defmodule Kiln.Sandboxes.EgressBlockingTest do
  use ExUnit.Case, async: false

  @moduletag :docker
  # Excluded by default; CI runs only when docker is available.

  setup do
    # Start a stage container via Kiln.Sandboxes.DockerDriver with
    # the hardened options from D-117. Return container_id for tests.
  end

  test "TCP egress to public IP fails", %{container: id} do
    # docker exec <id> curl -v --max-time 3 http://1.1.1.1
    # assert non-zero exit; assert no "HTTP/1.1 200" in stderr
  end

  test "UDP nc to 8.8.8.8:53 fails", %{container: id}
  test "DNS getent for google.com returns NXDOMAIN", %{container: id}
  test "ICMP ping 8.8.8.8 fails", %{container: id}
  test "IPv6 curl to [2606:4700::]:443 fails", %{container: id}
  test "DTU reachable — curl api.github.com/user succeeds (GitHub PAT returned)", %{container: id}
end
```

**Secrets-never-leak suite — pattern (D-133 Layer 6 + bonus Layer 7):**

```elixir
defmodule Kiln.Integration.SecretsNeverLeakTest do
  use Kiln.ObanCase, async: false

  @moduletag :integration
  @moduletag :docker

  setup do
    Kiln.Secrets.put(:anthropic_api_key, "sk-ant-fake-test-key-12345")
    on_exit(fn -> Kiln.Secrets.put(:anthropic_api_key, nil) end)
    :ok
  end

  test "docker inspect on a live stage container shows no secret-shaped env" do
    {:ok, container_id} = Kiln.Sandboxes.DockerDriver.run_stage(%ContainerSpec{...})
    {out, 0} = System.cmd("docker", ["inspect", "--format", "{{json .Config.Env}}", container_id])
    refute out =~ ~r/sk-ant-/, "container env MUST NOT contain secret"
    refute out =~ ~r/sk-proj-/
    refute out =~ ~r/ghp_/
    refute out =~ ~r/AIza/
  end

  test "adapter HTTP call reaches wire with Authorization header while state holds %Ref{}" do
    # Use Req.Test + Mox to intercept; assert request.headers["authorization"] =~ "Bearer sk-ant-"
    # AND assert the adapter's pre-call struct field is %Kiln.Secrets.Ref{name: :anthropic_api_key}
  end

  test "telemetry emission metadata carries %Ref{}, not raw string" do
    # Attach test handler to [:kiln, :agent, :request, :start]
    # Assert metadata.api_key == %Kiln.Secrets.Ref{...} and NOT a string
  end
end
```

---

### 16. NextStageDispatcher inside stage-completion transaction

**Applies to:** `lib/kiln/stages/next_stage_dispatcher.ex`.

**Analog file:** `lib/kiln/stages/stage_worker.ex` (lines 101–104 + 185–215).

**Current call site (stage_worker.ex lines 92–104):**

```elixir
with {:ok, root} <- ContractRegistry.fetch(stage_kind),
     :ok <- validate_input(stage_input, root),
     {_status, op} <-
       fetch_or_record_intent(key, %{...}),
     :ok <- guard_not_completed(op),
     {:ok, _artifact} <- stub_dispatch(run_id, stage_run_id, stage_kind),
     :ok <- maybe_transition_after_stage(run_id, stage_kind) do
  _ = complete_op(op, %{"result" => "stub_ok", ...})
  :ok
```

**Phase 3 target:** replace `stub_dispatch/3` (lines 172–180) with real agent invocation via `Kiln.Agents.complete/2`; call `Kiln.Stages.NextStageDispatcher.enqueue_next!/2` after `maybe_transition_after_stage/2` inside the same completion flow.

**NextStageDispatcher pattern:**

```elixir
defmodule Kiln.Stages.NextStageDispatcher do
  @moduledoc """
  Picks up Phase 2's deferred auto-enqueue responsibility. Called by
  `StageWorker.perform/1` after successful stage completion. Reads
  CompiledGraph.stages_by_id from the run's pinned workflow, finds
  stages whose depends_on is satisfied, enqueues next StageWorker
  Oban job(s) with idempotency key "run:<run_id>:stage:<stage_id>".

  Handles fan-out and fan-in barrier. No GenServer.
  """

  alias Kiln.{Runs, Stages, Workflows}
  alias Kiln.Stages.StageWorker
  alias Kiln.Factory.StageRun, as: StageRunFactory  # test-only

  @spec enqueue_next!(run_id :: Ecto.UUID.t(), completed_stage_id :: String.t()) :: :ok
  def enqueue_next!(run_id, completed_stage_id) do
    run = Runs.get!(run_id)
    {:ok, cg} = Workflows.load("priv/workflows/#{run.workflow_id}.yaml")

    satisfied_children = find_satisfied_children(cg, run_id, completed_stage_id)

    Enum.each(satisfied_children, fn stage ->
      stage_run = create_or_fetch_stage_run(run, stage)

      %{
        "idempotency_key" => "run:#{run_id}:stage:#{stage.id}",
        "run_id" => run_id,
        "stage_run_id" => stage_run.id,
        "stage_kind" => Atom.to_string(stage.kind),
        "stage_input" => build_stage_input(run, stage_run, stage.kind)
      }
      |> StageWorker.new(meta: Kiln.Telemetry.pack_meta())
      |> Oban.insert!()
    end)

    :ok
  end

  # find_satisfied_children/3, create_or_fetch_stage_run/2, build_stage_input/3 helpers
end
```

**Test pattern — mirror `test/kiln/stages/stage_worker_test.exs` lines 91–113** with `assert_enqueued(worker: StageWorker)` between the two `perform_job` calls:

```elixir
test "auto-enqueues next stage after completion" do
  # ... setup planning stage run
  assert :ok = perform_job(StageWorker, args_for_planning)
  # After Phase 3: NextStageDispatcher should have enqueued coding stage
  assert_enqueued(worker: StageWorker, args: %{"stage_kind" => "coding"})
end
```

---

### 17. Secrets `%Ref{}` struct with `@derive Inspect`

**Applies to:** `lib/kiln/secrets/ref.ex`.

**Analog file:** `lib/kiln/external_operations/operation.ex` (lines 38–53 `@derive {Jason.Encoder, only: [...]}`).

**Pattern:**

```elixir
defmodule Kiln.Secrets.Ref do
  @moduledoc """
  A reference to a named secret held in `:persistent_term`. Raw
  string values NEVER appear on this struct — the `name` atom is
  resolved to the raw string only via `Kiln.Secrets.reveal!/1`
  inside the adapter's HTTP-call stack frame (D-132).

  `@derive {Inspect, except: [:name]}` renders as `#Secret<anthropic_api_key>`
  to prevent grep-leakage of which secret is referenced in logs.
  """

  @derive {Inspect, except: [:name]}
  defstruct [:name]

  @type t :: %__MODULE__{name: atom()}
end
```

**Ecto schema field pattern — any schema with a secret-name reference:**

```elixir
# D-133 Layer 3: Ecto redact
field :api_key_reference, :string, redact: true
```

**LoggerJSON.Redactor pattern (`lib/kiln/logging/secret_redactor.ex`):**

```elixir
defmodule Kiln.Logging.SecretRedactor do
  @behaviour LoggerJSON.Redactor
  # D-133 Layer 4

  @secret_keys ~w(api_key secret token authorization bearer)
  @secret_prefixes ~w(sk-ant- sk-proj- ghp_ gho_ AIza)

  @impl true
  def redact(key, value, _opts) do
    cond do
      is_atom(key) and Atom.to_string(key) |> String.downcase() |> matches_secret_key?() ->
        "**redacted**"

      is_binary(value) and Enum.any?(@secret_prefixes, &String.starts_with?(value, &1)) ->
        "**redacted**"

      true ->
        value
    end
  end

  defp matches_secret_key?(key_str) do
    Enum.any?(@secret_keys, &String.contains?(key_str, &1))
  end
end
```

**Config registration (`config/config.exs` — extend the `:default_handler` block at lines 120–131):**

```elixir
config :logger_json, :redactors, [{Kiln.Logging.SecretRedactor, []}]
```

---

### 18. Finch per-provider named pools (inside existing `Kiln.Finch` child)

**Applies to:** `lib/kiln/application.ex` (modification).

**Analog:** existing `{Finch, name: Kiln.Finch}` line (application.ex line 38).

**Pattern — expand into per-host pool config:**

```elixir
{Finch,
 name: Kiln.Finch,
 pools: %{
   "https://api.anthropic.com" => [size: 10, count: 1, protocols: [:http2]],
   "https://api.openai.com" => [size: 10, count: 1, protocols: [:http2]],
   "https://generativelanguage.googleapis.com" => [size: 10, count: 1],
   "http://localhost:11434" => [size: 5, count: 1],  # Ollama local
   "http://172.28.0.10:80" => [size: 5, count: 1],   # DTU sidecar
   :default => [size: 10, count: 1]
 }}
```

**Adapters call Finch via Req:**

```elixir
Req.post("https://api.anthropic.com/v1/messages",
  finch: Kiln.Finch,  # single named Finch; pool chosen by host
  json: request_body,
  headers: [
    {"authorization", "Bearer #{Kiln.Secrets.reveal!(:anthropic_api_key)}"},
    {"anthropic-version", "2023-06-01"}
  ]
)
```

**Critical — do NOT add separate Finch children per provider.** This would add 4 children to the supervision tree and violate D-142's 14-child lock.

---

## Shared Patterns (cross-cutting)

### Pattern S1. Logger metadata threading through Oban boundaries

**Analog:** `lib/kiln/telemetry.ex` (`pack_ctx` / `unpack_ctx`) + `lib/kiln/telemetry/oban_handler.ex`.
**Applies to:** every new Oban worker (`ContractTest`) + every adapter call that executes inside a `StageWorker.perform/1`.

Call `Kiln.Telemetry.unpack_ctx(ctx)` at the top of any function spawned from an Oban worker. Pass `meta: Kiln.Telemetry.pack_meta()` at every `Oban.insert/1` site (mirror `stage_worker.ex` lines 78–84).

### Pattern S2. Correlation-ID inheritance into audit events

**Analog:** `lib/kiln/audit.ex` (lines 132–142 `correlation_id_from_logger/0`).

Every new audit-event-appending path should read `Logger.metadata()[:correlation_id] || Ecto.UUID.generate()` — never raise on missing correlation_id unless the call is INSIDE a sync user action (tests use `setup do Logger.metadata(correlation_id: ...) end` per stage_worker_test.exs lines 34–38).

### Pattern S3. ExUnit case templates for shared setup

**Analog:** `test/support/oban_case.ex`, `test/support/audit_ledger_case.ex`, `test/support/stuck_detector_case.ex` (not read — inferred from stuck_detector_test.exs).

Phase 3 adds new case templates:
- `test/support/mox_case.ex` — defmock setup + verify on exit.
- `test/support/sandbox_case.ex` — `@tag :docker` + container cleanup on exit.
- `test/support/dtu_case.ex` — starts DTU sidecar via `docker compose up -d dtu`.

All three follow the `use ExUnit.CaseTemplate` + `using do quote do ... end` + `setup tags do ... end` pattern verbatim from `oban_case.ex` lines 43–66.

### Pattern S4. Structured JSON log presence-map line

**Analog:** `lib/kiln/boot_checks.ex` (lines 441–446 remediation hint with structured payload).

For invariant 7 (`secrets_presence_map_non_empty`), emit a single structured `Logger.info` line with both loaded + missing provider keys. Format: `provider_keys_loaded=[:anthropic] provider_keys_missing=[:openai, :google, :ollama] database_url=present secret_key_base_bytes=64`.

### Pattern S5. `external_operations` intent kinds already declared in P1 D-17

**Reference:** `lib/kiln/external_operations.ex` moduledoc + `priv/repo/migrations/20260418000006_create_external_operations.exs`.

Phase 3 LIGHTS UP the already-declared kinds:
- `"llm_complete"` — every Adapter `complete/2` call.
- `"llm_stream"` — every Adapter `stream/2` call.
- `"docker_run"` — every sandbox launch.
- `"docker_kill"` — every explicit container termination (timeouts).
- `"osascript_notify"` — every desktop notification.
- `"secret_resolve"` — planner-discretion (may be audit-only).

No schema migration needed — kinds are string values, not enum-constrained at the DB layer for `op_kind` (verified: `external_operations.ex` line 56 uses bare `:string`).

---

## Files with No Close Analog

The planner should derive patterns from `03-RESEARCH.md` directly for:

| File | Role | Reason |
|---|---|---|
| `lib/kiln/agents/adapter/anthropic.ex` | live LLM adapter | No existing HTTP-client-with-retry-and-telemetry example; 03-RESEARCH.md §"Standard Stack" + §"Code Examples" has Anthropix snippets. |
| `lib/kiln/agents/adapter/openai.ex` + `google.ex` + `ollama.ex` | scaffolded LLM adapters | No prior Req-based external-API scaffold in Kiln. RESEARCH.md §"Alternatives" + OpenAI docs canonical references. |
| `lib/kiln/sandboxes/docker_driver.ex` | MuonTrap + docker CLI | First MuonTrap usage in codebase; first `System.cmd("docker", ...)` usage. 03-RESEARCH.md §"Common Pitfalls" section + MuonTrap hexdocs. |
| `lib/kiln/sandboxes/dtu/callback_router.ex` | Plug.Router inside Bandit | Phoenix-only codebase; no separate Plug router yet. Bandit + `Plug.Router` standard pattern. |
| `priv/sandbox/*.Dockerfile` | container build | First Dockerfile in priv/ — use `hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21` per D-111. |
| `priv/dtu/mix.exs` + `priv/dtu/lib/kiln_dtu/**` | separate mini-mix-project | First non-umbrella sibling project. Standard `mix new` layout. |
| `priv/dtu/contracts/github/api.github.com.2026-04.json` | pinned OpenAPI 3.1 | Downloaded from `github/rest-api-description` per D-122. |
| `test/kiln/sandboxes/egress_blocking_test.exs` | adversarial (SC #2) | No prior adversarial pattern. RESEARCH.md §"Adversarial Negative-Test Suite". |
| `test/integration/secrets_never_leak_test.exs` | adversarial (SC #6) | Same. |

---

## Critical Anti-Pattern Flags for the Planner

**DO NOT reuse these surfaces as analogs:**

1. **`Kiln.Policies.StuckDetector`'s SUPERVISION shape is NOT the model for `FactoryCircuitBreaker`'s PLACEMENT.** StuckDetector is called from INSIDE `Runs.Transitions.transition/3` (the transition-time hook); `FactoryCircuitBreaker` is called from INSIDE `Kiln.Agents.BudgetGuard.check!/2` (pre-LLM-call hook). The GenServer no-op body pattern IS the analog; the call site is NOT.

2. **`Kiln.Sandboxes.Hydrator` is NOT a GenServer.** It is a pure module called synchronously by `StageWorker.perform/1` pre-run. D-113 explicitly says "pure module, called synchronously". Do NOT add it as a supervision child — the "GenServer-per-work-unit" anti-pattern applies (CLAUDE.md "No GenServer-per-work-unit. Work units are Ecto rows + PubSub; GenServers are for behavior, not data organization"). Same for `Kiln.Sandboxes.Harvester`, `Kiln.Sandboxes.EnvBuilder`, `Kiln.Sandboxes.ImageResolver`, `Kiln.Agents.BudgetGuard`, `Kiln.Agents.StructuredOutput`, `Kiln.Stages.NextStageDispatcher`, `Kiln.Pricing`.

3. **Anthropix 0.6.2 does NOT wrap `count_tokens/1`.** RESEARCH.md correction #3: build a direct Req call against `POST https://api.anthropic.com/v1/messages/count_tokens`. Do not expect Anthropix to have this method — it does not. Response shape: `{"input_tokens": <number>}`.

4. **Do NOT mount `/var/run/docker.sock` into any container.** CLAUDE.md explicit; D-118 REJECTED; CIS Docker Benchmark 5.28. Phase 3 uses `System.cmd("docker", ...)` + `ex_docker_engine_api` FROM THE HOST BEAM, never from inside a container.

5. **The StageWorker already has `fetch_or_record_intent` + `complete_op` via `Kiln.Oban.BaseWorker`.** Do NOT duplicate these helpers — call them from `perform/1`. The `BaseWorker` macro (base_worker.ex lines 62–84) imports them into every `use Kiln.Oban.BaseWorker` module.

6. **Oban 2.21 `:discard` is deprecated — use `:cancel`.** `stage_worker.ex` lines 122+ already uses `:cancel` correctly. Phase 3 adapters returning to Oban workers must follow suit.

7. **`Kiln.Audit.append/1` requires correlation_id from Logger.metadata.** When a Phase 3 adapter or sandbox driver emits an audit event, `Logger.metadata(correlation_id: ...)` MUST be set first (via `Kiln.Telemetry.unpack_ctx/1` at the Oban-worker entry point or by explicit call from host). A missing correlation_id raises `ArgumentError` (audit.ex lines 134–141).

8. **`persistent_term` is write-once-at-boot — NEVER mutate at runtime in production.** The only write path is `Kiln.Secrets.put/2` called from `config/runtime.exs`. D-131 explicit. Writing at runtime triggers global GC and breaks throughput.

9. **`priv/playbooks/v1/<reason>.md` frontmatter must be JSV-validated at COMPILE time**, not at render time. Mirror `Kiln.Audit.SchemaRegistry`'s compile-time validation — any frontmatter failing the playbook JSV schema fails `mix compile` with a loud error.

10. **The audit `event_kind` enum is a POSTGRES CHECK constraint, NOT just an Ecto.Enum.** Adding new kinds requires both updating `@kinds` in `event_kind.ex` AND writing a migration that drops and re-adds the CHECK constraint (mirror `20260419000001_extend_audit_event_kinds.exs`). Do NOT ship Phase 3 without the paired migration, or all 8 new audit appends will fail at the DB layer.

---

## Metadata

**Analog search scope:** `lib/kiln/**/*.ex`, `test/kiln/**/*.ex`, `test/integration/*.exs`, `test/support/*.ex`, `config/*.exs`, `priv/repo/migrations/*.exs`.
**Files scanned:** 53 (all existing `lib/` modules + all existing test support + all config + all migrations).
**Strong matches found:** 52 of 57 new files have at least one analog (partial or better).
**Pattern extraction date:** 2026-04-20
**Pattern mapping agent:** gsd-pattern-mapper (Opus 4.7)
