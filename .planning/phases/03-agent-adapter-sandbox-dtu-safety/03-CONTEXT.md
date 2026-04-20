# Phase 3: Agent Adapter, Sandbox, DTU & Safety - Context

**Gathered:** 2026-04-20
**Status:** Ready for research (`/gsd-research-phase 3` — HIGH flag) → then planning

<domain>
## Phase Boundary

A stage invokes an LLM via `Kiln.Agents.Adapter` (Anthropix live + OpenAI/Google/Ollama scaffolded on Req with Mox contract tests and `@tag :live_*` gates), routed through `Kiln.ModelRegistry`'s preset → role → model resolution (all 6 D-57 presets mapped live; same-provider tier cascade on 429/5xx/context-length/content-policy failures recording both `requested_model` and `actual_model_used` to `stage_runs`; `fallback_policy: :same_provider | :cross_provider` field reserved on every preset so Phase 5's OpenAI-live flip is a data edit, not a schema migration). `Kiln.Agents.BudgetGuard.check!/2` runs BEFORE every LLM call using Anthropic's free `count_tokens` pre-flight + `Kiln.Pricing.estimate_usd/3` against `runs.caps_snapshot.max_tokens_usd` minus accumulated `SUM(stage_runs.tokens_used_usd)`; on breach the run transitions through `:blocked` with typed reason `:budget_exceeded` (playbook strict — **no `KILN_BUDGET_OVERRIDE` escape hatch**). `Kiln.Policies.FactoryCircuitBreaker` ships as a supervised no-op GenServer in the tree (D-91 StuckDetector precedent re-applied) with `factory_circuit_opened/closed` audit kinds declared in P3 so Phase 5 fills the sliding-window body with zero schema churn. Structured output goes through `Kiln.Agents.StructuredOutput.request/2` facade calling each provider's native path (Anthropic `tool_use`, OpenAI `response_format: {type: "json_schema"}`, Gemini `function_calling`, Ollama prompted-JSON fallback gated on `Adapter.capabilities().json_schema_mode`) with JSV Draft 2020-12 validation as defense-in-depth. Streaming `stream/2` returns `{:ok, Enumerable.t()}` passthrough of Anthropix's lazy stream wrapped in `Stream.each` emitting `[:kiln, :agent, :stream, :chunk]` telemetry — **no PubSub topology committed in P3**; Phase 4 (work units) and Phase 7 (LiveView `stream_async/4`) each name their own consumer shape.

Each stage runs in an ephemeral `kiln/sandbox-elixir:<digest>` container (per-language Dockerfile pattern, Elixir-first for Phase 9 dogfood; `priv/sandbox/elixir.Dockerfile` ← `hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21` with git + build-base + non-root `kiln:1000` user baked in; `priv/sandbox/images.lock` pins digests; `mix kiln.sandbox.build` rebuilds idempotently; new language = drop sibling Dockerfile, no refactor). The container joins the already-declared `kiln-sandbox` Docker bridge (`internal: true`), resolves `api.github.com` to the DTU sidecar's static IP `172.28.0.10` via `--dns <DTU_IP>` + `--add-host api.github.com:172.28.0.10` belt-and-suspenders, runs with the hardened flag set (see D-117), and writes only to three tmpfs mounts (`/tmp`, `/workspace`, `/home/kiln/.cache` — auto-scrubbed on exit for P21 defense). Stage I/O flows purely through `artifact_ref` handoff: `Kiln.Sandboxes.Hydrator` reads each stage's declared `input_artifacts` from `Kiln.Artifacts` CAS and materializes them into `/workspace` at stage start; `Kiln.Sandboxes.Harvester` walks `/workspace/out/` on stage exit and streams each output through `Kiln.Artifacts.put_stream/4` (streaming SHA-256), emitting one `artifact_written` audit event per output — all inside the stage-completion Postgres transaction. **No `git` command inside the container, ever**: `git init/add/commit/push` happens on the BEAM host against harvested CAS artifacts, defense-in-depth against P5 and P21. Resource limits come from `priv/sandbox/limits.yaml` keyed by stage `kind` — planning/verifying conservative (768m/1cpu/256 pids/4k fds), coding/testing/merge permissive (2g/2cpu/512 pids/8k fds), `--memory-swap=<same>` to hard-cap; tunable without code. `MuonTrap.cmd/3` wraps `docker run` so a BEAM crash mid-container kills the Docker client subprocess-tree (cgroup-v2 on Linux; port-close semantic on macOS). Labels `kiln.run_id`, `kiln.stage_run_id`, `kiln.boot_epoch` (BEAM monotonic start time), `kiln.stage_kind` drive `Kiln.Sandboxes.OrphanSweeper` at boot — enumerates containers with `kiln.boot_epoch != <current>`, force-removes, emits `orphan_container_swept` audit event per; this becomes BootChecks 8th invariant. An adversarial ExUnit suite (`test/kiln/sandboxes/egress_blocking_test.exs`) verifies all 5 egress vectors fail (TCP/UDP/DNS/ICMP/IPv6) and DTU reachability succeeds, closing SC #2.

The DTU ships as a **compose sidecar service** (`dtu` at static IP 172.28.0.10 on the `kiln-sandbox` IPAM subnet) running a Bandit + Plug.Router app hosting **hand-written GitHub REST handlers** whose responses are **JSV-validated at response-send time against pinned `priv/dtu/contracts/github/api.github.com.2026-04.json`** (bundled-dereferenced from `github/rest-api-description`). LLM-provider mocks and remaining chaos modes defer to Phase 5 where OPS-02 adaptive-routing tests actually need them; unknown endpoints return `HTTP 501 Not Implemented` with structured body (`{error: "dtu_unmocked", path, method}`) — **no echo-sink** (Kiln "fail loudly" ethos). Chaos in P3 ships exactly the two OPS-02 needs: `X-DTU-Chaos: rate_limit_429` (with GitHub-accurate `Retry-After` header) and `X-DTU-Chaos: outage_503`; timeout/slow/malformed/schema_drift defer to P5. `Kiln.Sandboxes.DTU.Supervisor` supervises `Kiln.Sandboxes.DTU.HealthPoll` (pings sidecar `/healthz` every 30s, reports stuck via PubSub) and registers `Kiln.Sandboxes.DTU.ContractTest` on Oban `:dtu` queue (stubbed + unscheduled; Phase 6 toggles the cron). DTU lives as a **separate mini-mix-project under `priv/dtu/`** (NOT umbrella — D-97 strict single-app invariant preserved) with its own release; shared code via bind-mount during dev, snapshot-baked into the production image. DTU posts request metadata to Kiln on a host-loopback internal endpoint (best-effort → `external_op_completed` audit); its local JSONL log at `priv/dtu/runs/<run_id>.jsonl` is authoritative so DTU never blocks on Kiln availability.

Secrets enter via `config/runtime.exs` into `persistent_term` **at boot** (write-once, no global-GC thrash) as `%Kiln.Secrets.Ref{name: :anthropic_api_key}` values whose raw strings are **only resolvable** via `Kiln.Secrets.reveal!/1` inside the adapter's HTTP-call function stack frame — never in any struct that crosses a function boundary. BootChecks 7th invariant asserts ≥1 provider key present in `:prod` (warn in `:dev`) and logs a structured presence map: `provider_keys_loaded=[:anthropic] provider_keys_missing=[:openai, :google, :ollama]`. When a run's `model_profile_snapshot` demands a provider whose `Kiln.Secrets.present?/1` returns false, `Kiln.Runs.RunDirector.start_run/1` raises a typed `:missing_api_key` block **before any LLM call** (literal SC #4 wording) — playbook rendered from `priv/playbooks/v1/missing_api_key.md`, desktop notification fires via `Kiln.Notifications.desktop/2` (`osascript` on macOS / `notify-send` on Linux) with ETS-based `{run_id, reason}` 5-minute dedup. Six redaction layers (struct type-system, `@derive {Inspect, except: [:api_key]}`, Ecto `field :..., redact: true`, `LoggerJSON.Redactor` regex + known-prefix scrub, `Ecto.Changeset.redact_fields`, docker-inspect negative test) mean grep-audit for `reveal!` call sites finds exactly ~3 (one per provider's `call_http/2`). The sandbox env-builder (`Kiln.Sandboxes.EnvBuilder`) carries an explicit ALLOWLIST only; any env var whose NAME matches `~r/(api_key|secret|token|authorization|bearer)/i` fails sandbox launch with `:sandbox_env_contains_secret` — SC #6's `docker inspect` assertion passes by construction.

`Kiln.Blockers.Reason` enum declares ALL 9 BLOCK-01 atoms in P3 (consumers pattern-match exhaustively from P3 forward); P3 ships **5 fully-authored playbooks** (`missing_api_key`, `invalid_api_key`, `rate_limit_exhausted`, `quota_exceeded`, `budget_exceeded`) + **4 stub playbooks** with explicit `owning_phase: 5|6` frontmatter (`gh_auth_expired`, `gh_permissions_insufficient`, `unrecoverable_stage_failure`, `policy_violation`). Storage mirrors D-09/D-73 compile-time-registry pattern verbatim: `priv/playbooks/v1/<reason>.md` with YAML frontmatter + markdown body, `@external_resource` + `Kiln.Blockers.PlaybookRegistry` build at compile time, frontmatter JSV-validated against `priv/playbook_schemas/v1/playbook.json`. Markdown body renders to terminal (P3 notifications), LiveView (P8 unblock panel), and Slack (hypothetical v1.1+) without content rewrite. Playbook templating uses Mustache-style `{var}` substitution from the block's context map.

Phase 3 supervision tree moves children from 10 → 13 (D-42 re-lock): `+Kiln.Agents.SessionSupervisor`, `+Kiln.Sandboxes.Supervisor` (which hosts `DockerDriver` + `OrphanSweeper`), `+Kiln.Sandboxes.DTU.Supervisor` (which hosts `HealthPoll` + registers `ContractTest` stub), `+Kiln.Policies.FactoryCircuitBreaker` (scaffolded no-op). BootChecks moves from 6 → 8 invariants (`+secrets_presence_map_non_empty`, `+no_prior_boot_sandbox_orphans`). The StageWorker from Plan 02-08 gains the auto-enqueue-next-stage responsibility Phase 2 deferred here (reading `CompiledGraph.stages_by_id` + current run state to dispatch next `:stages` queue entry). Oban queue taxonomy locked (D-67) stays unchanged; D-71 provider-split trigger stays armed (2+ live adapters + observable cross-provider delay) — P3 has 1 live adapter so the trigger does not fire, but P5 likely will hit it.

Workflow YAML dialect, stage input contracts, artifacts CAS, run state machine, RunDirector rehydration, and auto-enqueue-next-stage hook (delivered here) all belong to locked earlier phases or this phase. Work-unit store + Mayor/agent-role GenServer tree (P4), scenario runner + bounded-autonomy full caps + stuck-detector body (P5), real git/gh integration (P6), LiveView streaming consumers + PubSub topology (P7), BLOCK-02 unblock panel + onboarding wizard + cost intel (P8), and dogfood + OTel coverage validation (P9) all belong to later phases.

</domain>

<decisions>
## Implementation Decisions

### Adapter, Model Registry & Streaming (Gray Area 1)

- **D-101:** **Adapter scope = Option A (ROADMAP literal): `Kiln.Agents.Adapter.Anthropic` LIVE wrapping Anthropix 0.6.2; `.OpenAI`, `.Google`, `.Ollama` scaffolded on Req 0.5 (~200 LOC each) with Mox contract tests + `@tag :live_*` gates.** Behaviour polymorphism is *actually* exercised in P3 (prevents Anthropic-shaped leakage into the `Adapter` contract). Mirrors `instructor_lite`'s proven minimal-adapter shape. Live token burn gated by env-var tags; SC #1 (record `requested_model` + `actual_model_used`) verifiable against Anthropic alone.
- **D-102:** **`Kiln.Agents.Adapter` behaviour callbacks:** `@callback complete(prompt :: Prompt.t(), opts :: keyword()) :: {:ok, Response.t()} | {:error, term()}`, `@callback stream(prompt, opts) :: {:ok, Enumerable.t()} | {:error, term()}`, `@callback count_tokens(prompt) :: {:ok, non_neg_integer()} | {:error, term()}`, `@callback capabilities() :: %{streaming: boolean(), tools: boolean(), thinking: boolean(), vision: boolean(), json_schema_mode: boolean()}`. `json_schema_mode` is the linchpin for `StructuredOutput` to pick native-vs-prompted per adapter.
- **D-103:** **Streaming = Option C: `stream/2 → {:ok, Enumerable.t()}` passthrough** wrapping Anthropix's lazy Enumerable in `Stream.each` that emits `[:kiln, :agent, :stream, :chunk]` telemetry (measurements: `byte_size`, `elapsed_since_start`; metadata: `run_id`, `stage_id`, `actual_model_used`). **NO `Phoenix.PubSub.broadcast` in P3.** Phase 4 (work units) and Phase 7 (LiveView `stream_async/4`) each name their own consumer shape. Rationale: LiveView has no built-in backpressure (Hex Shift writeups) — committing PubSub shape in P3 commits backpressure *policy* without a consumer to calibrate against. The `langchain_elixir` `on_llm_new_delta` shape is our reference for P7 when it lands.
- **D-104:** **Structured output = Option A: per-provider native modes behind `Kiln.Agents.StructuredOutput.request(schema, adapter: atom, model: binary, prompt: Prompt.t())` facade + JSV Draft 2020-12 defense-in-depth validation.** Anthropic `tool_use`, OpenAI `response_format: {type: "json_schema", json_schema: {...}}`, Gemini `function_calling`. Ollama falls back to prompted-JSON + JSV post-validation + 1 retry (retry counted against stage budget) when `capabilities().json_schema_mode == false`. 2025 industry consensus (Mastra, Glukhov comparison): native modes cut error rates 15% → 3%.
- **D-105:** **ModelRegistry = Option A: all 6 D-57 presets live** (`elixir_lib`, `phoenix_saas_feature`, `typescript_web_feature`, `python_cli`, `bugfix_critical`, `docs_update`) in `priv/model_registry/<preset>.exs` — runtime-loaded Elixir files (NOT compile-time config; respects no-`Mix.env()`-at-runtime ban). Deterministic resolution via `Kiln.ModelRegistry.resolve(preset_name, stage_overrides)` returns map keyed by `agent_role`, each role carrying `%{model, fallback: [model_ids], tier_crossing_alerts_on: [model_ids], fallback_policy: :same_provider | :cross_provider}`. `mix kiln.registry.show <preset>` CLI task dumps the resolved mapping for 2am operator debugging.
- **D-106:** **Fallback triggers** (mirroring LiteLLM's taxonomy, extended): HTTP 429, HTTP 5xx, connection errors, timeouts, `:context_length_exceeded`, `:content_policy_violation`. Each fallback attempt writes ONE `model_routing_fallback` audit event with payload `%{stage_run_id, run_id, role, requested_model, actual_model_used, fallback_reason: atom, tier_crossed: boolean, attempt_number: integer, provider_http_status: integer | nil, wall_clock_ms: integer}`. Exhaustion → stage transitions `:failed` with typed block reason `:model_unavailable_all_tiers` (declare at P3 as 10th reason IF operator accepts; otherwise reuse `:unrecoverable_stage_failure`) + diagnostic artifact (prompt + last error + full attempt trace) captured via `Kiln.Artifacts`. **Tier-crossing warning** surfaced via audit event only in P3 (desktop notification for tier-cross deferred to Phase 7 — `Kiln.Notifications` in P3 is used only for typed-block notifications, not for fallback visibility).
- **D-107:** **Fallback policy in P3 = `:same_provider` only** (Opus → Sonnet → Haiku within Anthropic). `fallback_policy: :cross_provider` is declaratively present on every preset but never exercised in P3 because only Anthropic is live. Phase 5's OpenAI-live flip flips the policy field; **zero schema migration**.
- **D-108:** **Deprecated model handling:** each preset role mapping carries optional `@deprecated_on: ~D[YYYY-MM-DD]` field. On resolve, deprecated models emit `model_deprecated_resolved` audit warning but still resolve (give operator runway); after the deprecation date, fall through to next in fallback chain and emit warning. `mix kiln.registry.show` highlights deprecated entries.
- **D-109:** **Finch named pools per provider** at supervision-tree level: `Kiln.Finch.Anthropic`, `Kiln.Finch.OpenAI`, `Kiln.Finch.Google`, `Kiln.Finch.Ollama`. A 429-storm on one provider cannot starve another. Req uses these pools via `req: [finch: Kiln.Finch.<Provider>]`. Do NOT bypass Req to raw Finch in P3 (escape hatch reserved for pathological SSE streaming in later phases).

### D-109 (amendment, 2026-04-20): Single Finch child with per-host pool routing

Phase 3 implementation consolidates the four named Finch children into a single
`Kiln.Finch` child configured with `:pools` keyed by host:
  {"https://api.anthropic.com", size: 20, count: 1},
  {"https://api.openai.com", size: 20, count: 1},
  {"https://generativelanguage.googleapis.com", size: 20, count: 1},
  {"http://localhost:11434", size: 20, count: 1}

Rationale:
- Finch's per-host pool sharding delivers the same provider isolation as separate
  children (a 429 on Anthropic's host pool cannot starve OpenAI's pool).
- Keeps D-142's 14-child supervision tree cap intact (a switch to 4 named Finch
  children would raise it to 17).
- Adapters pass `finch: Kiln.Finch` (not `finch: Kiln.Finch.Anthropic`) — provider
  selection happens via the HTTP URL host, which Finch routes to the correct pool.

Supersedes D-109's original "four named Finch children" wording while preserving
the decision's INTENT: provider-pool isolation without cross-provider starvation.

- **D-156 (resolution of Open Question #1 from 03-RESEARCH.md):** **Structured output for Anthropic in P3 = Anthropix `tool_use` path only.** Anthropix 0.6.2 does NOT expose the 2026 native `output_config.format.json_schema` endpoint; a direct-Req bypass is NOT justified in P3 when `tool_use + strict: true` already delivers provider-side enforcement (D-104). `Kiln.Agents.StructuredOutput.Anthropic` routes via `tool_use` through Anthropix; JSV Draft 2020-12 post-validation (defense in depth) remains unconditional. Consolidate to `output_config` in a future phase (likely Phase 5 or 9) when Anthropix 0.7.x exposes it natively. Plan 03-05's `StructuredOutput.request/2` native path is correct as-planned.

- **D-110:** **Telemetry contract.** `[:kiln, :agent, :call, :start | :stop | :exception]` — measurements: `duration_native`, `tokens_in`, `tokens_out`, `cost_usd`; metadata: `requested_model`, `actual_model_used`, `provider`, `role`, `run_id`, `stage_id`, `fallback?`. `[:kiln, :agent, :stream, :chunk]` per D-103. `[:kiln, :agent, :call, :exception]` captures provider error taxonomy for fallback decision trees. `opentelemetry_process_propagator`'s `fetch_parent_ctx(1, :"$callers")` used inside StageWorker to link LLM spans to the enqueueing transition (PITFALLS P17 mitigation).

### Sandbox Image, Limits, Workspace & Docker Options (Gray Area 2)

- **D-111:** **Base image strategy = Option A: per-language Dockerfile, Elixir-first.** `priv/sandbox/base.Dockerfile` (shared: non-root `kiln:1000` user, `kiln.*` labels, UTF-8 locale, minimal `/etc/resolv.conf` template). `priv/sandbox/elixir.Dockerfile` FROM `hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21` + git + build-base + openssl-dev + coreutils + bash. Tagged `kiln/sandbox-elixir:<git-sha>` + `kiln/sandbox-elixir:<digest>` pinned in `priv/sandbox/images.lock` (regenerated by `mix kiln.sandbox.build`). Phase 3 ships Elixir only; other languages are sibling Dockerfiles added per-adoption. Image selection: pure function `Kiln.Sandboxes.ImageResolver.resolve(workflow.metadata.language || "elixir") → {image_ref, digest}`.
- **D-112:** **Resource limits = Option C: adaptive per-stage-kind via `priv/sandbox/limits.yaml`.** Starter values (planner will validate via research + live measurement): `default: {memory: "768m", memory_swap: "768m", cpus: 1, pids_limit: 256, ulimit_nofile: "4096:8192", ulimit_nproc: 128, tmpfs_workspace: "512m", tmpfs_tmp: "128m", tmpfs_cache: "256m"}`; `coding/testing/merge: {memory: "2g", memory_swap: "2g", cpus: 2, pids_limit: 512, ulimit_nofile: "4096:8192", ulimit_nproc: 256, tmpfs_workspace: "1024m", tmpfs_tmp: "256m", tmpfs_cache: "512m"}`. Loaded at boot into `:persistent_term` via `Kiln.Sandboxes.Limits`. **Exact numbers are research-flagged** — the POLICY SHAPE is locked; `/gsd-research-phase 3` validates numbers against real Phoenix/Oban workload.
- **D-113:** **Workspace mount = Option A: RO-in + WO-out via CAS (artifact_ref handoff).** `Kiln.Sandboxes.Hydrator` (pure module, called synchronously by StageWorker pre-run): reads the stage input contract's declared `input_artifacts` (list of `artifact_ref`), materializes each from CAS into `/workspace/<artifact_name>`. `Kiln.Sandboxes.Harvester` (pure module, called post-run): walks `/workspace/out/`, streams each file through `Kiln.Artifacts.put_stream/4` (streaming SHA-256 — never materializes full bytes in memory), emits `artifact_ref` list + one `artifact_written` audit event per output, all inside the stage-completion Postgres transaction. **NO `git` command inside the container, ever.**
- **D-114:** **Workflow YAML `sandbox` enum semantics clarified (schema docs, NOT a schema change):** `sandbox: none` = no container spawn (pure-function stages, e.g., pure-read planning against artifacts); `sandbox: readonly` = container spawned, no `/workspace/out` mount, stage `output_contract.artifacts` MUST be empty (rejected at load time); `sandbox: readwrite` = tmpfs `/workspace` + `/workspace/out/` harvested to CAS. Input/output artifacts declared explicitly per stage.
- **D-115:** **Driver = `Kiln.Sandboxes.Driver` behaviour with one live impl `Kiln.Sandboxes.DockerDriver`** — invokes `docker run` via **`MuonTrap.cmd/3`** for crash-safe subprocess-tree cleanup (cgroup-v2 on Linux; port-close semantics on macOS Docker Desktop). Behaviour callbacks: `@callback run_stage(ContainerSpec.t()) :: {:ok, run_result()} | {:error, reason()}`, `@callback kill(container_id) :: :ok`, `@callback list_orphans(boot_epoch :: integer) :: [container_id()]`. Emits `[:kiln, :sandbox, :docker, :run, :start | :stop]` telemetry including the **exact `docker run` command vector** (operator "repro locally" UX).
- **D-116:** **`%Kiln.Sandboxes.ContainerSpec{}` struct** fields: `image_ref`, `image_digest`, `cmd` (list), `env_file_path`, `network` (default `"kiln-sandbox"`), `limits` (Limits struct), `tmpfs_mounts` (list `{path, size}`), `labels` (map: run_id, stage_run_id, boot_epoch, stage_kind), `stop_timeout` (default 10s), `user` (default `"1000:1000"`), `workdir` (default `"/workspace"`), `security_opts` (list), `cap_drop_all` (default true), `read_only` (default true), `init` (default true), `dns` (list, default `[DTU_IP]`), `extra_hosts` (list, default `["api.github.com:#{dtu_ip}"]`), `ipv6_disabled` (default true).
- **D-117:** **Hardened Docker option set (adopted — every stage container):**
  - `--rm` (first-line orphan prevention)
  - `--network kiln-sandbox` (the already-declared `internal: true` bridge)
  - `--cap-drop=ALL` (OWASP Container Rule #3 / CIS 5.3 — tested: Elixir `mix compile`/`mix test`/`git` as non-root work with zero caps)
  - `--security-opt=no-new-privileges` (blocks setuid escalation; CIS 5.25)
  - `--security-opt=seccomp=default` (Docker's default ~44-syscall profile; NO custom JSON in P3)
  - `--read-only` (immutable root FS; writes only to explicit tmpfs)
  - `--tmpfs /tmp:rw,noexec,nosuid,size=<limits>`
  - `--tmpfs /workspace:rw,nosuid,size=<limits>` (auto-scrubs secrets on exit — P21 defense)
  - `--tmpfs /home/kiln/.cache:rw,nosuid,size=<limits>`
  - `--user 1000:1000` (non-root kiln user baked into image)
  - `--memory=<K> --memory-swap=<same>` (hard cap, no swap thrash)
  - `--cpus=<K> --pids-limit=<K>` (fork-bomb defense; P2 mitigation)
  - `--ulimit nofile=4096:8192 --ulimit nproc=<K>` (cap nofile below 65535 per elixir-lang#2571 slowdown)
  - `--stop-timeout 10` (SIGTERM grace for Elixir shutdown hooks + test flushing)
  - `--label kiln.run_id=<id> --label kiln.stage_run_id=<id> --label kiln.boot_epoch=<monotonic_ms> --label kiln.stage_kind=<atom>`
  - `--env-file <priv/run/<stage_run_id>.env>` (dynamically-generated, chmod 0600, ALLOWLIST only: `DTU_BASE_URL`, `DTU_TOKEN`, `MIX_ENV=test`, `LANG=en_US.UTF-8` — deleted at end of stage-completion tx)
  - `--hostname kiln-stage-<stage_run_id_short>` (deterministic log correlation)
  - `--workdir /workspace`
  - `--init` (Docker's built-in tini; reaps zombie children)
  - `--dns <DTU_IP>` (name resolution to DTU only; Docker embedded DNS on internal bridge already blocks public names, this is belt-and-suspenders)
  - `--add-host api.github.com:<DTU_IP>` (escape hatch for IP-literal code paths)
  - `--sysctl net.ipv6.conf.all.disable_ipv6=1` (per-container IPv6 kill — moby#20559 inconsistencies)
- **D-118:** **REJECTED Docker options in P3:** rootless Docker (Desktop-macOS networking caveats; revisit Phase 9 hardening), `--userns-remap` (same), `--security-opt=apparmor=docker-default` (Linux-only; Phase 9 conditional), custom `seccomp.json` (tuning pit; revisit only if adversarial suite finds gap), Kata/gVisor/Firecracker/Docker Sandboxes microVM (overkill for solo-op v1), `--privileged` (obviously never), arbitrary `-v /var/run/docker.sock` (explicitly forbidden per CLAUDE.md + P5), arbitrary host bind-mount of workspace (replaced by tmpfs + CAS hydration per D-113).
- **D-119:** **DNS-block enforcement (SC #2):** Layer 1 = `internal: true` bridge gateway-less (blocks routing); Layer 2 = Docker embedded DNS at 127.0.0.11 resolves only bridge-container names (NXDOMAIN on public); Layer 3 = `--dns <DTU_IP>` override + `--dns-opt=ndots:0 --dns-search=.` prevents search-domain leakage; Layer 4 = `--sysctl net.ipv6.conf.all.disable_ipv6=1` per-container IPv6 kill; Layer 5 = compose declares `kiln-sandbox` as IPv4-only in IPAM config. Adversarial suite (`test/kiln/sandboxes/egress_blocking_test.exs`) verifies all 5 vectors (TCP curl to public IP; UDP nc to 8.8.8.8:53; DNS getent for google.com; ICMP ping 8.8.8.8; IPv6 curl to `[2606:4700::]:443`) fail + positive DTU reachability via `curl api.github.com/user`.
- **D-120:** **Orphan cleanup = `Kiln.Sandboxes.OrphanSweeper` at boot** (GenServer in `Kiln.Application` children BEFORE `RunDirector` — ordering matters). `init/1`: call `docker ps -a --filter label=kiln.run_id --filter label=kiln.boot_epoch!=<current>` via `ex_docker_engine_api`, enumerate survivors, emit `orphan_container_swept` audit event per (payload: `container_id, run_id, stage_run_id, boot_epoch_found, age_seconds`), force `docker rm -f`. Becomes **BootChecks 8th invariant**. Post-stage `docker inspect` hook captures `.State.OOMKilled`, `.State.ExitCode`, `.State.StartedAt/FinishedAt` into the `docker_run` `external_operations.result_payload` for "why did this stage fail" DX.

### DTU Mock Scope, Generation & Hosting (Gray Area 3)

- **D-121:** **Coverage = Option D: GitHub API only in P3.** LLM-provider mocks defer to Phase 5 where OPS-02 adaptive-routing tests live and actually exercise them. Generic HTTP sink: explicitly rejected — unknown endpoint returns `HTTP 501 Not Implemented` with body `{"error": "dtu_unmocked", "path": "/repos/...", "method": "POST"}`. Fail loudly. Adapter E2E tests from P1..P4 continue using `Req.Test` + `Mox` fakes at the HTTP-client layer.
- **D-122:** **Generation = Option C: hybrid.** Hand-written Plug handlers (behavioral realism — StrongDM's "SDK-compatibility" success metric) + responses JSV-validated at send-time against pinned `priv/dtu/contracts/github/api.github.com.2026-04.json` (bundled + dereferenced from `github/rest-api-description` via `mix kiln.dtu.regen_contract` task). Record-and-replay (ExVCR) explicitly REJECTED — PAT leak risk into fixtures violates SEC-01.
- **D-123:** **Hosting = Option A: compose sidecar service.** `compose.yaml` gains `dtu` service with static IP `172.28.0.10` on the `kiln-sandbox` IPAM subnet (subnet declared alongside so IPAM is deterministic), image `kiln/dtu:<git-sha>` built from `priv/dtu/Dockerfile` (multi-stage: Elixir release stage 1 → Alpine + BEAM runtime + minimal dnsmasq stage 2; target ~80-120MB). BEAM-hosted DTU is impossible without defeating SC #2 (cannot reach `internal: true` bridge from host without breaking egress-block tests).
- **D-124:** **DTU as separate mini-mix-project at `priv/dtu/`** — **NOT umbrella app** (D-97 strict single-app invariant). Layout: `priv/dtu/mix.exs`, `priv/dtu/lib/kiln_dtu/router.ex`, `priv/dtu/lib/kiln_dtu/handlers/github/*.ex`, `priv/dtu/lib/kiln_dtu/chaos.ex`, `priv/dtu/lib/kiln_dtu/validation.ex` (JSV against pinned schema). Shared code with Kiln: dev uses bind-mount (`volumes: ["./priv/dtu:/app/priv/dtu"]`), production image snapshot-bakes it. Dev-loop iteration: `docker compose build dtu && docker compose up dtu` (~5s on warm cache).
- **D-125:** **Chaos + contract scaffold = Option B: 429 + 503 only in P3.** `X-DTU-Chaos: rate_limit_429` returns HTTP 429 with GitHub-accurate `Retry-After` header; `X-DTU-Chaos: outage_503` returns HTTP 503. Reserved future values declared but not handled: `timeout_30s`, `slow_5s`, `malformed_json`, `schema_drift`. `Kiln.Sandboxes.DTU.ContractTest` Oban worker registered on `:dtu` queue (concurrency 2 per D-67), **stubbed body + cron unscheduled**; Phase 6 toggles the cron schedule without new plumbing. Weekly contract test uses a real GitHub PAT via SEC-01 to fetch current schema, diffs against `priv/dtu/contracts/github/api.github.com.2026-04.json`, emits `dtu_contract_drift_detected` audit event on mismatch.
- **D-126:** **DTU `Kiln.Sandboxes.DTU.Supervisor` children:** `Kiln.Sandboxes.DTU.HealthPoll` (GenServer; pings `http://172.28.0.10:80/healthz` every 30s; after 3 consecutive misses broadcasts `{:dtu_unhealthy, reason}` on `Kiln.PubSub` topic `"dtu_health"` — Phase 7 consumes; P3 just emits `dtu_health_degraded` audit event) + `Kiln.Sandboxes.DTU.ContractTest` registration (worker registered on Oban `:dtu` queue, not started, cron nil). NO separate Bandit endpoint inside Kiln BEAM for DTU (D-123 rejects).
- **D-127:** **DTU audit integration = best-effort loopback callback.** On each request, DTU posts to `POST http://172.28.0.1:4001/internal/dtu/event` (host-gateway on sandbox bridge's host-facing interface; a small `Kiln.Sandboxes.DTU.CallbackRouter` on a second Bandit endpoint bound to loopback-only, separate from the dashboard port) with payload `{run_id, stage_id, method, path, status, chaos_mode, duration_ms, schema_valid}`. Kiln translates → `external_op_completed` audit event. **Callback failure is non-fatal** — DTU's local `priv/dtu/runs/<run_id>.jsonl` request log is authoritative; audit is best-effort. DTU never blocks on Kiln availability.
- **D-128:** **DTU DNS override mechanism** = dnsmasq baked into the sidecar image, responding to `api.github.com`, `*.github.com` with its own IP (`172.28.0.10`). Sandbox ContainerSpec sets `dns: ["172.28.0.10"]` + `extra_hosts: ["api.github.com:172.28.0.10"]` (belt-and-suspenders for IP-literal code paths). Any agent-generated code doing `curl https://api.github.com/...` hits DTU transparently.

### Secrets, Block Reasons & BudgetGuard (Gray Area 4)

- **D-131:** **Secret timing = Option C: hybrid eager + presence-map + stage-start typed block.** `config/runtime.exs` reads `System.get_env("ANTHROPIC_API_KEY")` etc. and calls `Kiln.Secrets.put/2` during app start; `persistent_term` is **write-once at boot** (no runtime mutation → no global-GC thrash). `Kiln.BootChecks` 7th invariant: ≥1 provider key present in `:prod` (fatal on zero), warn-only in `:dev`. Boot log line (structured): `[info] provider_keys_loaded=[:anthropic] provider_keys_missing=[:openai, :google, :ollama] database_url=present secret_key_base_bytes=64`. `Kiln.Runs.RunDirector.start_run/1` checks `Kiln.Secrets.present?/1` against the run's `model_profile_snapshot` required providers; absence raises typed `:missing_api_key` block **BEFORE any LLM call** (literal ROADMAP SC #4 wording).
- **D-132:** **Secret reference shape = Option A: `%Kiln.Secrets.Ref{name: atom}` struct.** `@derive {Inspect, except: [:name]}` renders as `#Secret<anthropic_api_key>`. Raw string **only** exists in the return value of `Kiln.Secrets.reveal!/1`, which is called inside one adapter-function stack frame at the HTTP-call boundary. Grep-audit for `reveal!` call sites finds exactly ~3 (one per live provider adapter's `call_http/2`). ANY struct anywhere in the app holding a raw provider secret is a type-system error.
- **D-133:** **Six redaction layers (ALL ship in P3):** (1) type-system boundary — `%Ref{}` struct, raw value never crosses function boundary; (2) `@derive {Inspect, except: [:api_key]}` on Ref + every adapter request struct; (3) Ecto schema `field :api_key_reference, :string, redact: true` wherever names persist (per Ecto 3.13 schema-level redaction: displays `**redacted**` in changeset inspect); (4) `LoggerJSON.Redactor` behaviour implementation `Kiln.Logging.SecretRedactor` — scrubs metadata keys matching `~r/(api_key|secret|token|authorization|bearer)/i` + stringified values matching known prefix shapes (`sk-ant-`, `sk-proj-`, `ghp_`, `gho_`, `AIza`); (5) `Ecto.Changeset.redact_fields/2` on auth-related changesets so validation errors never echo submitted value; (6) docker-inspect negative test (SC #6) — `test/integration/secrets_never_leak_test.exs` spawns a real stage container, runs `docker inspect --format '{{json .Config.Env}}' <id>`, asserts no env var name or value matches secret-shape regex + asserts Anthropix mock saw `Authorization: Bearer ...` header (proving secret reached the wire) while adapter GenServer state at emission held `%Ref{}` not string. BONUS 7th layer: `:telemetry` emission-boundary assertion that `[:kiln, :agent, :request, :start]` metadata contains `%Ref{}` (not string).
- **D-134:** **`Kiln.Sandboxes.EnvBuilder` sandbox env ALLOWLIST enforcement.** The per-stage envfile written to `priv/run/<stage_run_id>.env` is built from an EXPLICIT allowlist: `DTU_BASE_URL`, `DTU_TOKEN` (short-lived per-stage, valid <5 min, scoped to DTU mock access only per P21), `MIX_ENV=test`, `LANG=en_US.UTF-8`. Any env var whose NAME matches `~r/(api_key|secret|token|authorization|bearer)/i` (case-insensitive) fails the build with `{:error, :sandbox_env_contains_secret, key_name}` — sandbox launch aborts, run transitions `:blocked` with `:policy_violation`. SC #6 `docker inspect` assertion passes by construction.
- **D-135:** **Block reasons in P3 = all 9 atoms in `Kiln.Blockers.Reason` enum** (consumers pattern-match exhaustively from P3 forward). P3 playbook maturity:
  - **REAL playbooks (5):** `missing_api_key`, `invalid_api_key`, `rate_limit_exhausted`, `quota_exceeded`, `budget_exceeded`.
  - **STUB playbooks (4):** `gh_auth_expired` (owning_phase: 6), `gh_permissions_insufficient` (owning_phase: 6), `unrecoverable_stage_failure` (owning_phase: 5), `policy_violation` (owning_phase: 3 — has a live consumer via D-134 sandbox env allowlist, real playbook ships NOW, not stub).
  - **Revised:** 6 real + 3 stubs. The stubs explicitly carry `owning_phase: 6 | 5` frontmatter + "Contact maintainer — this playbook is being written in Phase N" body.
- **D-136:** **Playbook storage = Option A: markdown + YAML frontmatter under `priv/playbooks/v1/<reason>.md` + compile-time `Kiln.Blockers.PlaybookRegistry` via `@external_resource`.** Mirrors D-09 `Kiln.Audit.SchemaRegistry` + D-73 `Kiln.Stages.ContractRegistry` + `Kiln.Workflows.SchemaRegistry` pattern verbatim (4th instance of the pattern — architectural cohesion). Frontmatter validated against `priv/playbook_schemas/v1/playbook.json` JSV schema at compile time. Mix recompiles on edit. Body is markdown → renders to terminal (P3 notifications), LiveView (P8 unblock panel), Slack webhook (hypothetical v1.1+) without content rewrite.
- **D-137:** **Playbook frontmatter schema (validated fields):** `reason` (enum, 9 values), `severity` (`halt | warn | escalate`), `short_message` (≤120 chars, Mustache `{var}` allowed), `title` (Mustache allowed), `required_context` (list of atoms the renderer must receive), `remediation_commands` (list of `{label, command}`), `audit_kind_on_resolve` (atom, default `block_resolved`), `next_action_on_resolve` (`resume_run | restart_run | abort_run`), `owning_phase` (int 1-9). Rendering via `Kiln.Blockers.PlaybookRegistry.render(reason, context_map)` returns `%RenderedPlaybook{title, severity, short_message, commands, body_markdown}` consumed by `Kiln.Notifications` (short_message only) and Phase 8's unblock panel (full markdown).
- **D-138:** **BudgetGuard scope = Option C: per-call pre-flight ACTIVE + global circuit breaker SCAFFOLDED as supervised no-op.** `Kiln.Agents.BudgetGuard.check!/2` runs BEFORE every LLM call via an adapter-level `before_call` hook in the `Kiln.Agents.Adapter` behaviour. 7-step check order: (1) read `runs.caps_snapshot.max_tokens_usd`; (2) `SUM(stage_runs.tokens_used_usd) WHERE run_id = $1 AND state IN ('completed', 'failed')`; (3) compute `remaining_budget_usd`; (4) call provider adapter's `count_tokens/1` (Anthropic's free `/v1/messages/count_tokens` endpoint for P3's live adapter); (5) `Kiln.Pricing.estimate_usd(model, input_tokens, estimated_output_tokens)` — pricing table in `priv/pricing/v1/<provider>.exs`; (6) compare `estimated_usd` to `remaining_budget_usd`; (7) emit `budget_check_passed` OR raise `:budget_exceeded` + emit `budget_check_failed`. **NO `KILN_BUDGET_OVERRIDE` env var.** Playbook is strict: "Review spend in `/ops/dashboard`, edit workflow caps, restart run." All 7 steps in a single telemetry span `[:kiln, :agents, :budget_guard, :check]`.
- **D-139:** **`Kiln.Policies.FactoryCircuitBreaker` scaffolded** as supervised `GenServer` in `Kiln.Application` children; `check/1` body returns `:ok` in P3 with `# D-TODO(phase-5): implement sliding-window spend check` marker. Mirrors D-91 `StuckDetector` precedent exactly. **Audit kinds `factory_circuit_opened` + `factory_circuit_closed` declared in P3 `Kiln.Audit.EventKind` enum** (moves from 25 → 27 kinds) + ship `priv/audit_schemas/v1/{factory_circuit_opened,factory_circuit_closed}.json` with stub payload `{reason: string, spend_last_60min_usd: decimal, threshold_usd: decimal, scaffolded: true}` — **P5 fills the sliding-window body with ZERO schema migration**. Same pattern: scaffold now, fill later.
- **D-140:** **`Kiln.Notifications.desktop/2`** (`osascript` on macOS via `System.cmd("osascript", ["-e", ...])`, `notify-send` on Linux via `System.cmd("notify-send", [...])`). OS detection at runtime via `:os.type/0` (NOT `Mix.env()` — respects P15 ban). **ETS-backed dedup cache** keyed by `{run_id, reason}` with 5-minute TTL; identical `(run_id, reason)` within TTL is silently dropped; audit kind `notification_fired` vs `notification_suppressed` recorded either way. Notification format: `Kiln — {severity}\n{short_message}\nrun: {run_id_short}` (macOS sticky; Linux `notify-send -u critical -c kiln -h string:x-canonical-private-synchronous:{run_id}_{reason}` uses native last-write-wins tag coalescing). **Synchronous dispatch** inside the block-raising transaction via `external_operations` two-phase intent (`osascript_notify` kind already declared in P1 D-17).

### Supervision Tree & BootChecks Updates

- **D-141:** **Supervision tree 10 → 13 children** (D-42 re-lock). New children (in order, inserted BEFORE `RunDirector` per D-120 boot-ordering requirement for OrphanSweeper):
  1. `Kiln.Sandboxes.Supervisor` (`:one_for_one` — hosts `DockerDriver` + `OrphanSweeper` as first child before driver ready)
  2. `Kiln.Sandboxes.DTU.Supervisor` (`:one_for_one` — hosts `HealthPoll` + registers `ContractTest`)
  3. `Kiln.Agents.SessionSupervisor` (`:one_for_one` `DynamicSupervisor` — per-run agent session lifecycle; MVP empty in P3, P4 populates)
  4. `Kiln.Policies.FactoryCircuitBreaker` (`:permanent` GenServer, no-op body)
  5. Finch pools: `Kiln.Finch.{Anthropic, OpenAI, Google, Ollama}` (named per-provider; 4 supervised children — NOTE: these are 4 MORE children, total becomes 13 + 4 = 17? Reconsider: Finch itself runs as ONE supervisor with named pools; treat as 1 child. Final child count: **10 + 4 = 14**. Re-lock D-42 to 14.)
- **D-142:** **Corrected supervision tree = 14 children** (D-42 re-lock at 14). Existing 10: KilnWeb.Telemetry, Kiln.Repo, {Phoenix.PubSub, Kiln.PubSub}, {Finch, Kiln.Finch} (*existing P1 Finch; expanded per-provider in P3*), {Registry, Kiln.RunRegistry}, Oban, RunSupervisor, RunDirector, StuckDetector, KilnWeb.Endpoint. Phase 3 adds: `Kiln.Sandboxes.Supervisor`, `Kiln.Sandboxes.DTU.Supervisor`, `Kiln.Agents.SessionSupervisor`, `Kiln.Policies.FactoryCircuitBreaker`. **Finch pools per provider** consolidated INTO the existing `Kiln.Finch` child via named pools (`pools: %{"https://api.anthropic.com" => [size: 10], "https://api.openai.com" => ..., ...}`) — Finch supports this natively; does NOT add children. Final: **14 children**.
- **D-143:** **BootChecks 6 → 8 invariants** (D-32 re-lock at 8). Existing 6: contexts_compiled, audit_revoke_active, audit_trigger_active, oban_queue_budget, workflow_schema_loads, required_secrets. P3 adds: **7. secrets_presence_map_non_empty** (in `:prod` fatal if zero providers; in `:dev` warn-only; logs structured presence line). **8. no_prior_boot_sandbox_orphans** (runs `docker ps -a --filter label=kiln.boot_epoch!=<current>` via `ex_docker_engine_api`, force-removes survivors, emits `orphan_container_swept` audit event per; fatal only if `docker` CLI missing/unreachable).

### StageWorker Auto-Enqueue (Phase 2 deferred item, delivered here)

- **D-144:** **`Kiln.Stages.NextStageDispatcher`** — pure module called by `Kiln.Stages.StageWorker.perform/1` after successful stage completion, inside the stage-completion Postgres transaction. Reads `CompiledGraph.stages_by_id` from the run's pinned workflow, finds stages whose `depends_on` is satisfied by the current run's `StageRun.state` distribution, enqueues next `StageWorker` Oban job(s) with deterministic idempotency key `run:<run_id>:stage:<stage_id>` (D-70). Handles fan-out (N downstream stages → N jobs enqueued) and fan-in barrier (stage not enqueued until ALL parents have `StageRun.state = :completed`). No GenServer. Replaces Phase 2's test-level explicit for-loop at the end of the end-to-end integration test; that test now asserts auto-enqueue.

### Audit Event Kind Extensions

- **D-145:** **`Kiln.Audit.EventKind` extends 25 → 30 kinds** in P3. New kinds + `priv/audit_schemas/v1/<kind>.json` schemas:
  - `orphan_container_swept` (payload: container_id, run_id, stage_run_id, boot_epoch_found, age_seconds)
  - `dtu_contract_drift_detected` (payload: endpoint, method, drift_kind, diff_summary) — stub body in P3, P6 emits
  - `dtu_health_degraded` (payload: consecutive_misses, last_success_at)
  - `factory_circuit_opened` / `factory_circuit_closed` (payloads per D-139 — stubs with `scaffolded: true`)
  - `model_deprecated_resolved` (payload: model_id, deprecated_on, preset, role) — warning, still resolves
  - `notification_fired` / `notification_suppressed` (payload: reason, run_id, dedup_key, platform)
  - *Phase 2's plan shipped 25 kinds; verify exact number during planning.*

### Model Profile Pricing Table

- **D-146:** **`priv/pricing/v1/<provider>.exs`** runtime-loaded Elixir files mapping `{provider, model} → %{input_per_mtok_usd, output_per_mtok_usd, cache_write_per_mtok_usd, cache_read_per_mtok_usd}`. `Kiln.Pricing.estimate_usd(model, input_tokens, estimated_output_tokens)` is the single pricing surface. `mix kiln.pricing.check` Mix task scrapes provider pricing pages and flags pricing-table staleness in CI (WARN only in P3; Phase 9 hardening may make fatal).

### Spec Upgrades to Apply Inside Phase 3's Implementation

Mirror of D-50..D-53 (Phase 1) and D-97..D-100 (Phase 2) pattern. NOT new decisions — corrections/extensions to existing planning docs Phase 3 must apply before downstream phases inherit broken assumptions.

- **D-151:** Update **CLAUDE.md** Architecture section: append to "OTP supervision tree" paragraph the Phase 3 additions (Sandboxes.Supervisor, Sandboxes.DTU.Supervisor, Agents.SessionSupervisor, Policies.FactoryCircuitBreaker — tree at 14 children). Add to "Elixir-specific anti-patterns to avoid" line: "secrets stored outside `persistent_term`-backed `Kiln.Secrets`; raw API keys in struct fields; `System.cmd` for `docker` without `MuonTrap.cmd` crash-safety wrapper."
- **D-152:** Update **ARCHITECTURE.md** §4 `Kiln.Sandboxes` entry: replace "Phase 4 ships the Sandboxes.Driver behaviour..." (from the current stub moduledoc) with the D-115..D-117 decisions. Add §10 Sandbox Interface section updates: hardened option set from D-117; DNS-block layers from D-119; orphan-sweep from D-120; workspace mount policy from D-113; DTU sidecar topology from D-123. §11 Agent Orchestration updates: behaviour callback shapes from D-102; ModelRegistry preset layout from D-105; BudgetGuard order from D-138.
- **D-153:** Update **ARCHITECTURE.md** §15 Project Directory Structure: add `lib/kiln/secrets.ex` + `lib/kiln/secrets/`, `lib/kiln/blockers.ex` + `lib/kiln/blockers/`, `lib/kiln/notifications.ex`, `lib/kiln/model_registry.ex` + `lib/kiln/model_registry/`, `lib/kiln/pricing.ex`, `lib/kiln/agents/adapter*.ex`, `lib/kiln/agents/budget_guard.ex`, `lib/kiln/agents/structured_output.ex`, `lib/kiln/sandboxes/{driver.ex, docker_driver.ex, env_builder.ex, hydrator.ex, harvester.ex, image_resolver.ex, limits.ex, orphan_sweeper.ex, supervisor.ex}`, `lib/kiln/sandboxes/dtu/{supervisor.ex, health_poll.ex, contract_test.ex, callback_router.ex}`, `lib/kiln/policies/factory_circuit_breaker.ex`, `lib/kiln/stages/next_stage_dispatcher.ex`, `priv/sandbox/{base,elixir}.Dockerfile`, `priv/sandbox/{limits.yaml,images.lock}`, `priv/playbooks/v1/<reason>.md` (9 files), `priv/playbook_schemas/v1/playbook.json`, `priv/model_registry/<preset>.exs` (6 files), `priv/pricing/v1/<provider>.exs`, `priv/dtu/{mix.exs,Dockerfile,lib/kiln_dtu/…}`, `priv/dtu/contracts/github/api.github.com.2026-04.json`.
- **D-154:** Update **STACK.md** — add `muontrap ~> 1.7` to mix.exs deps (new dep, sole addition to the stack in P3; justified by D-115 crash-safe `docker run` wrapper). Note that Anthropix 0.6.2 + Req 0.5.17 + JSV 0.18 are already pinned; no version bumps. Add a "Sandbox dependencies" subsection documenting MuonTrap's role.
- **D-155:** Update **PITFALLS.md** — link P5 mitigation details back to D-117..D-120; link P21 mitigations to D-131..D-134; link P2 mitigations to D-138..D-139. These are not new pitfalls, just cross-references so downstream phases (P5 stuck-detector, P6 git, P8 cost intel, P9 dogfood) inherit the mitigation map.

### Claude's Discretion

The planner and executor have flexibility on:

- Exact module file names within each context's directory (follow ARCHITECTURE.md §15 layout extended per D-153).
- `Kiln.Agents.Prompt.t()` struct internal shape (role, content, tools, system_prompt, metadata, etc.) — shipped as opaque-ish struct with documented public API.
- `Kiln.Agents.Response.t()` struct internal shape — must expose `actual_model_used`, `tokens_in`, `tokens_out`, `cost_usd`, `stop_reason`, `content` at minimum.
- Exact pricing data in `priv/pricing/v1/<provider>.exs` (planner fetches from provider pricing pages during planning — flag `/gsd-research-phase 3` for this).
- Exact resource limit numbers in `priv/sandbox/limits.yaml` within the policy shape (planner + research validate against live Phoenix/Oban compile workload).
- `Kiln.Finch` named-pool sizing per provider within a budget (aggregate <= existing Finch pool budget).
- Test-fixture shapes under `test/fixtures/` (including DTU request/response fixtures).
- Exact structure of `priv/dtu/lib/kiln_dtu/handlers/github/*.ex` (one file per endpoint family: issues.ex, pulls.ex, checks.ex, contents.ex, branches.ex, tags.ex, etc.). Phase 3 ships the 6-10 handlers the stage-execution path actually touches.
- Whether `Kiln.Sandboxes.OrphanSweeper` runs as a GenServer or as a boot-time Task (D-120 specifies GenServer for telemetry visibility; functionally equivalent).
- Whether `Kiln.Blockers.PlaybookRegistry` resolves Mustache `{var}` substitution via a tiny inline function or via a micro-lib (e.g., `:bbmustache`) — no external dep if inline is <30 LOC.
- Playbook body copy/voice within the Kiln brand-book rules (precise, calm, grounded, restrained; no hype, no jargon).
- Specific test organization under `test/kiln/{agents,sandboxes,blockers,policies}/` beyond the mandatory adversarial `test/kiln/sandboxes/egress_blocking_test.exs` and `test/integration/secrets_never_leak_test.exs`.

### Folded Todos

None — `gsd-sdk query todo.match-phase 3` returned zero matches at discussion time. The sole pending todo (`2026-04-18-phase-10-slot-decision.md`) belongs to Phase 8/9 per its own `trigger:` frontmatter. Pending SEEDs (`SEED-001..005`) are v1.5+/v2 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Project spec & vision

- `CLAUDE.md` — project conventions, brand contract, tech stack, anti-patterns. **NOTE: Phase 3 implementation must apply spec-upgrade D-151 before downstream phases inherit the 13-children supervision-tree line.**
- `.planning/PROJECT.md` — vision, constraints, key decisions, out-of-scope list.
- `.planning/REQUIREMENTS.md` — Phase 3 maps to **AGENT-01, AGENT-02, AGENT-05, SAND-01, SAND-02, SAND-03, SAND-04, SEC-01, BLOCK-01, BLOCK-03, OPS-02, OPS-03**. Adjacent: BLOCK-02 (Phase 8 unblock panel — renders P3 playbooks), BLOCK-04 (Phase 8 onboarding wizard — gates on P3 BootChecks 7th invariant), OBS-02 (Phase 9 OTel completeness — validates P3 telemetry/spans), OPS-04 (Phase 8 cost intel — consumes P3 audit `model_routing_fallback` + `budget_check_*` events).
- `.planning/ROADMAP.md` Phase 3 entry — goal, 6 success criteria, artifacts, pitfalls addressed (**ALL FIVE HIGH** — P2 cost runaway, P5 sandbox escape, P8 prompt injection groundwork, P21 secrets in sandbox; plus P6 DTU drift, P10 model deprecation, P20 LLM JSON parse failure).
- `.planning/STATE.md` — session continuity.

### Prior phase context

- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — Phase 1 decisions still load-bearing:
  - **D-06** (UUID v7 via pg_uuidv7 — Phase 3 new tables use this)
  - **D-08** (audit event_kind taxonomy — Phase 3 extends 25 → 30 per D-145)
  - **D-09** (JSV per-kind at app boundary — D-73 stage contract registry pattern repeated by D-136 playbook registry)
  - **D-12** (three-layer audit INSERT-only enforcement — D-138 budget_check events written inside tx)
  - **D-14..D-21** (external_operations two-phase intent — Phase 3 lights up `llm_complete`, `llm_stream`, `docker_run`, `docker_kill`, `osascript_notify`, `secret_resolve` kinds declared but unused in P1-P2)
  - **D-22..D-26** (mix check gate — new `mix check_no_sandbox_env_secrets` task may land in P3 per D-134)
  - **D-32** (BootChecks.run!/0 — Phase 3 extends 6 → 8 invariants per D-143)
  - **D-42** (supervision-tree re-lock — Phase 3 moves 10 → 14 per D-142)
  - **D-44** (`Kiln.Oban.BaseWorker` with insert-time unique on `idempotency_key`)
  - **D-46** (mandatory metadata keys: correlation_id, causation_id, actor, actor_role, run_id, stage_id)
  - **D-48** (Postgres roles kiln_owner + kiln_app — unchanged)
  - **D-50..D-53** (spec-upgrade pattern — D-151..D-155 mirror it)
- `.planning/phases/02-workflow-engine-core/02-CONTEXT.md` — Phase 2 decisions still load-bearing:
  - **D-57** (6 model_profile presets — D-105 maps them all to real role→model resolution)
  - **D-58** (stage kinds + agent_roles + sandbox enum — D-114 clarifies sandbox semantics)
  - **D-67** (Oban 6-queue taxonomy — `:dtu` queue gets its first real worker registration in P3 per D-125)
  - **D-68** (pool_size 20 — unchanged; D-71 provider-split trigger armed)
  - **D-70** (idempotency-key canonical shape — D-144 auto-enqueue uses `"run:<id>:stage:<sid>"`)
  - **D-71** (provider-split defer trigger — evaluated in P3 planning; likely does NOT fire because only Anthropic is live)
  - **D-73..D-76** (stage input contracts — D-113 Hydrator reads declared `input_artifacts`, SC #6 uses contract shape)
  - **D-77..D-85** (Kiln.Artifacts 13th context — D-113 Harvester writes through `Kiln.Artifacts.put_stream`)
  - **D-86..D-90** (run state machine + `:blocked` wired — Phase 3 adds the PRODUCERS: `:blocked` transition drivers from `Kiln.Blockers`)
  - **D-91** (StuckDetector scaffold-now-fill-later — D-139 FactoryCircuitBreaker applies the same pattern 2nd time)
  - **D-92..D-96** (RunDirector rehydration — Phase 3 integrates missing-provider check at run start per D-131)
  - **D-97..D-100** (Phase 2 spec upgrades — template for D-151..D-155)

### Stack & architecture research

- `.planning/research/STACK.md` — locked versions. Phase 3 adds `muontrap ~> 1.7` (sole addition per D-154). Anthropix 0.6.2 + Req 0.5.17 + JSV 0.18 already pinned.
- `.planning/research/ARCHITECTURE.md` §4 `Kiln.Agents` + `Kiln.Sandboxes` entries (Phase 3 fills these); **§8 (Agent Orchestration — prompt-build + shared-notes pattern**, partial; Phase 4 fills the rest); **§10 (Sandbox Interface — extended per D-115..D-120)**; §11 (LiveView Patterns — Phase 7 context, but P3 `stream/2` shape must not conflict).
- `.planning/research/PITFALLS.md` — **P2 (cost runaway — D-138..D-139)**, **P5 (sandbox escape — D-117..D-120)**, **P8 (prompt injection — typed tool allowlist groundwork in P3, full in P4)**, **P10 (model deprecation — D-105..D-108)**, **P17 (OTel context across Oban — D-110)**, **P20 (LLM JSON parse — D-104 native structured output)**, **P21 (secrets in sandbox — D-131..D-134)**. P6 (DTU drift) and P9 (Oban max_attempts) are covered by Phase 1/2.
- `.planning/research/SUMMARY.md` — high-level architectural narrative.
- `.planning/research/FEATURES.md` — feature inventory.
- `.planning/research/BEADS.md` — work-unit-store rationale (informs Phase 4, not Phase 3).

### Best-practices reference (consumed during research, retain for executor cross-checks)

- `prompts/elixir-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/phoenix-live-view-best-practices-deep-research.md`
- `prompts/ecto-best-practices-deep-research.md`
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md`
- `prompts/kiln-brand-book.md` — brand contract (voice applies to playbook bodies, notification copy, error messages).

### External canonical references discovered during discussion

**Adapter + structured output + streaming:**
- [Anthropix 0.6.2 hexdocs](https://hexdocs.pm/anthropix/Anthropix.html) — streaming Enumerable + pid modes, tool_use, extended thinking, prompt caching
- [Anthropic `count_tokens` endpoint](https://docs.anthropic.com/en/api/messages-count-tokens) — free, rate-limited pre-flight used by D-138 BudgetGuard
- [Token Counting Explained 2025 guide (Propel)](https://www.propelcode.ai/blog/token-counting-tiktoken-anthropic-gemini-guide-2025) — Anthropic vs tiktoken vs Gemini
- [instructor_lite (martosaur)](https://github.com/martosaur/instructor_lite) — canonical Elixir minimal-adapter shape mirrored in D-101..D-102
- [instructor_ex](https://github.com/thmsmlr/instructor_ex) — broader Ecto-integrated structured-output pattern; P5 upgrade candidate
- [langchain_elixir `on_llm_new_delta`](https://hexdocs.pm/langchain/LangChain.ChatModels.LLMCallbacks.html) — P7 streaming consumer reference shape
- [Structured output comparison 2025 (Glukhov)](https://www.glukhov.org/post/2025/10/structured-output-comparison-popular-llm-providers) — native-modes-win thesis for D-104
- [Mastra MCP tool compatibility layer](https://mastra.ai/blog/mcp-tool-compatibility-layer) — native structured output 15% → 3% error reduction
- [OpenRouter model fallbacks](https://openrouter.ai/docs/guides/routing/model-fallbacks) — fallback array shape D-106
- [LiteLLM reliability error taxonomy](https://docs.litellm.ai/docs/proxy/reliability) — general/content-policy/context-window fallback categories
- [opentelemetry_process_propagator](https://hexdocs.pm/opentelemetry_process_propagator/OpentelemetryProcessPropagator.html) — `fetch_parent_ctx(1, :"$callers")` for D-110 trace propagation
- [Hex Shift: LiveView backpressure](https://hexshift.medium.com/websocket-backpressure-in-phoenix-liveview-how-to-handle-the-load-without-dropping-the-ball-bc16b058e7dd) — justifies D-103 PubSub deferral to P7
- [Vercel AI SDK](https://ai-sdk.dev/docs/introduction) — cautionary reference for what NOT to over-build in P3

**Sandbox:**
- [NIST SP 800-190 Application Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker seccomp profile docs](https://docs.docker.com/engine/security/seccomp/) (D-117 uses default)
- [Docker networking (bridge / internal)](https://docs.docker.com/engine/network/)
- [Docker Sandboxes 2026 microVM product](https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/) — cautionary overkill reference
- [Container isolation state-of-the-art 2026](https://emirb.github.io/blog/microvm-2026/)
- [MuonTrap 1.7 hexdocs](https://hexdocs.pm/muontrap/MuonTrap.html) + [`MuonTrap.Daemon`](https://hexdocs.pm/muontrap/MuonTrap.Daemon.html) — D-115 crash-safe wrapper
- [Excontainers (prior-art Resources Reaper)](https://github.com/dallagi/excontainers) — D-120 orphan-sweep inspiration
- [testcontainers-elixir](https://github.com/testcontainers/testcontainers-elixir) — test-only dep
- [Elixir 1.19 release notes](https://elixir-lang.org/blog/2025/10/16/elixir-v1-19-0-released/) — compile-perf baseline for D-112 limits
- [Elixir mix high nofile slowdown (elixir-lang#2571)](https://github.com/elixir-lang/elixir/issues/2571) — D-117 caps nofile at 4096:8192
- [Elixir ExUnit struct memory (elixir-lang#12141)](https://github.com/elixir-lang/elixir/issues/12141) — D-112 justifies 2g permissive profile
- [Official Elixir Docker image](https://hub.docker.com/_/elixir) — D-111 base image
- [Docker IPv6 moby#20559](https://github.com/moby/moby/issues/20559) — D-119 IPv6 sysctl belt-and-suspenders
- [Dagger content-addressed pipelines](https://docs.dagger.io/features/programmable-pipelines/) — D-113 artifact_ref handoff reference
- [Datadog container security capabilities deep-dive](https://securitylabs.datadoghq.com/articles/container-security-fundamentals-part-3/)
- [Docker container stop signal/timeout docs](https://docs.docker.com/reference/cli/docker/container/stop/)
- [OWASP Container Security Cheat Sheet](https://www.aquasec.com/cloud-native-academy/docker-container/docker-cis-benchmark/) — Rule #3 cap-drop ALL
- [Claude Code sandbox guide 2026](https://claudefa.st/blog/guide/sandboxing-guide)

**DTU:**
- [StrongDM Software Factory landing](https://factory.strongdm.ai/) + [DTU technique page](https://factory.strongdm.ai/techniques/dtu) — only public DTU prior art
- [Simon Willison writeup on StrongDM DTU](https://simonwillison.net/2026/Feb/7/software-factory/) — richest source on how they build DTU mocks
- [GitHub REST API OpenAPI description repo](https://github.com/github/rest-api-description) — D-122 JSV validation target
- [GitHub OpenAPI 3.1 compliance](https://github.blog/changelog/2021-12-16-openapi-description-of-rest-api-is-now-3-1-compliant/)
- [WireMock chaos engineering](https://www.wiremock.io/use-case/chaos-engineering) + [fault simulation](https://wiremock.org/docs/simulating-faults/) — D-125 chaos header pattern inspiration
- [Stoplight Prism (OpenAPI-driven mock)](https://stoplight.io/open-source/prism) — rejected per D-122 (random-examples fail SDK round-trip fidelity)
- [LocalStack DNS server](https://docs.localstack.cloud/aws/tooling/dns-server/) + [transparent endpoint injection](https://docs.localstack.cloud/references/network-troubleshooting/transparent-endpoint-injection/) — D-128 DNS-override pattern
- [Shopify Toxiproxy](https://github.com/Shopify/toxiproxy) — chaos sidecar pattern reference
- [JSV hexdocs](https://hexdocs.pm/jsv) — D-122 response-send validation
- [Req.Test](https://hexdocs.pm/req/Req.Test.html) + [Dashbit article](https://dashbit.co/blog/req-api-client-testing) — unit-test LLM adapter layer
- [ExVCR](https://github.com/parroty/exvcr) — rejected per D-122 (PAT-capture SEC-01 risk)
- [MSW `onUnhandledRequest=error`](https://mswjs.io/docs/api/setup-server/listen/) — "fail loudly" cross-ecosystem inspiration
- [OpenAPI Generator Elixir (alpha, client-only — server stubs unavailable)](https://openapi-generator.tech/docs/generators/elixir/) — justifies D-122 hand-written handlers
- [Bandit](https://github.com/mtrudel/bandit) — DTU HTTP server

**Secrets + blocks + budget:**
- [Erlang persistent_term docs](https://www.erlang.org/doc/apps/erts/persistent_term.html) + [blog on patterns](https://www.erlang.org/blog/persistent_term/) — D-131 write-once-at-boot rationale
- [Ecto.Schema `redact: true`](https://hexdocs.pm/ecto/Ecto.Schema.html) — D-133 Layer 3
- [Ecto.Changeset `redact_fields/2`](https://hexdocs.pm/ecto/Ecto.Changeset.html) — D-133 Layer 5
- [LoggerJSON 7.0.4 + Redactor](https://hexdocs.pm/logger_json/LoggerJSON.html) — D-133 Layer 4
- [Fuse (Erlang circuit breaker)](https://github.com/jlouis/fuse) + [external_service](https://github.com/jvoegele/external_service) — D-139 FactoryCircuitBreaker reference (P5 may adopt fuse-style sliding-window)
- [Google SRE Workbook](https://sre.google/workbook/table-of-contents/) + [On-Call](https://sre.google/workbook/on-call/) + [Incident Response](https://sre.google/workbook/incident-response/) — D-136..D-137 playbook-pattern inspiration
- [Stripe error codes + handling](https://docs.stripe.com/error-codes) + [advanced error handling](https://docs.stripe.com/error-low-level) + [Stripity Stripe's Stripe.Error](https://hexdocs.pm/stripity_stripe/Stripe.Error.html) — typed-block-reason + remediation pattern
- [LiteLLM budget enforcement](https://docs.litellm.ai/docs/proxy/users) + [Budget Manager](https://docs.litellm.ai/docs/budget_manager) + [Agent Iteration Budgets](https://docs.litellm.ai/docs/a2a_iteration_budgets) — D-138 pre-flight pattern
- [AI agent cost-blowup prevention](https://dev.to/sapph1re/how-to-stop-ai-agent-cost-blowups-before-they-happen-1ehp) + [MindStudio token budget](https://www.mindstudio.ai/blog/ai-agent-token-budget-management-claude-code) — P2 prevention pattern
- [macOS Notifications CLI patterns](https://smallsharpsoftwaretools.com/tutorials/macos-notifications/) + [swissmacuser guide](https://swissmacuser.ch/native-macos-notifications-from-terminal-scripts/) — D-140 `osascript`/`notify-send` dispatch
- [Plausible SECRET_KEY_BASE boot validation](https://github.com/plausible/analytics/issues/1105) — D-131 BootChecks pattern (already referenced in P1 D-32)
- [SecretVault usage](https://hexdocs.pm/secret_vault/usage.html) — persistent_term pattern reference
- [Phoenix Security](https://hexdocs.pm/phoenix/security.html) + [mix phx.gen.secret](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Secret.html)

</canonical_refs>

<code_context>
## Existing Code Insights

Phase 1 shipped the durability floor; Phase 2 shipped the workflow engine + run state machine + artifacts CAS. Phase 3's integration points are all live.

### Reusable Assets (live, ready to plug into Phase 3)

- **`Kiln.Oban.BaseWorker`** (`lib/kiln/oban/base_worker.ex`) — `max_attempts: 3` default, insert-time unique on `idempotency_key`. Phase 3 Oban workers (ContractTest stub, NextStageDispatcher-triggered StageWorker re-enqueue, NotificationWorker if we go async — D-140 stays sync) use this.
- **`Kiln.ExternalOperations`** (`lib/kiln/external_operations/operation.ex`) — two-phase intent table. Phase 3 lights up the DECLARED kinds `llm_complete`, `llm_stream`, `docker_run`, `docker_kill`, `osascript_notify`, `secret_resolve` (all declared in P1 D-17; zero writers until now).
- **`Kiln.Audit`** + `Kiln.Audit.EventKind` + `Kiln.Audit.SchemaRegistry` + `priv/audit_schemas/v1/` — JSV-validated at `Kiln.Audit.append/1` boundary. Phase 3 extends 25 → 30 kinds per D-145.
- **`Kiln.BootChecks`** (`lib/kiln/boot_checks.ex`) — staged supervisor boot with 6 current invariants. Phase 3 extends 6 → 8 per D-143.
- **`Kiln.Artifacts`** (`lib/kiln/artifacts.ex` + `lib/kiln/artifacts/{artifact.ex, cas.ex, gc_worker.ex, scrub_worker.ex}`) — CAS + `artifact_ref{sha256, size_bytes, content_type}` + `put_stream/4` streaming SHA. Phase 3 Harvester (D-113) writes through this exact API.
- **`Kiln.Runs.Transitions`** (`lib/kiln/runs/transitions.ex`) — D-86..D-90 command module; `:blocked` matrix edge already wired. Phase 3 adds the PRODUCERS (blockers, notifications) against this already-complete matrix — no transition-matrix churn.
- **`Kiln.Runs.RunDirector`** (`lib/kiln/runs/run_director.ex`) — :permanent GenServer + boot-scan + 30s periodic. Phase 3 extends `start_run/1` with D-131 missing-provider check.
- **`Kiln.Stages.StageWorker`** (`lib/kiln/stages/stage_worker.ex`) from Plan 02-08 — the `Oban` worker that drives stage execution. Phase 3 wires in: pre-stage sandbox hydration (D-113 Hydrator), adapter invocation (D-102 behaviour), post-stage harvest (D-113 Harvester), NextStageDispatcher (D-144 — takes over the P2-deferred role).
- **`Kiln.Stages.ContractRegistry`** + `priv/stage_contracts/v1/` — Phase 3 Hydrator reads `stage.input_contract.artifacts` from this.
- **`Kiln.Workflows.SchemaRegistry`** + `priv/workflow_schemas/v1/workflow.json` — `model_profile` enum (D-57 six presets) already const-validated here; D-105 ModelRegistry makes those strings resolvable to actual models.
- **`Kiln.Logger.Metadata`** + **`Kiln.Telemetry.{pack_ctx, unpack_ctx}`** — six-key metadata threading across Oban boundaries (P1 D-46). Phase 3 adapter `call/2` MUST `unpack_ctx` at telemetry-emit boundary so `[:kiln, :agent, :call, :stop]` carries `run_id`, `stage_id`, `correlation_id`.
- **`Kiln.Scope`** — unchanged from P1.
- **UUID v7** via `pg_uuidv7` — already installed. No new tables in P3 (decisions table-less — configs live in `priv/`).
- **`kiln_owner` / `kiln_app` roles** — unchanged. Phase 3 adds no new tables.
- **Oban 6-queue taxonomy** (`:default, :stages, :github, :audit_async, :dtu, :maintenance`) — `:dtu` queue gets its first real worker registration in P3 (D-125 ContractTest stub).

### Established Patterns

- **Compile-time registries from priv/<thing>/v1/<name>.<ext>** — Phase 3 adds the 4th instance via D-136 `Kiln.Blockers.PlaybookRegistry`. The pattern is: `@external_resource <file>`, parse at compile, JSV-validate frontmatter (or top-level schema) against sibling schemas registry, build a compile-time map. Mirror of D-09 (audit) + D-73 (stage) + workflow.
- **Scaffold-now-fill-later supervised no-op** — Phase 3 adds 2nd instance via D-139 `FactoryCircuitBreaker`. Mirrors D-91 `StuckDetector`. Audit kinds declared now, body filled in later phase with zero schema migration.
- **Staged supervisor boot** (P1 D-42) — Phase 3 inserts 4 new infra children BEFORE `BootChecks.run!/0` per D-142.
- **`mix check_*` grep invariant tasks** (D-26 pattern) — Phase 3 may add `mix check_no_sandbox_env_secrets` if the regex-based denylist in D-134 can be lint-verified at source level (grep `Kiln.Sandboxes.EnvBuilder.put/3` callers for `~r/(api_key|secret|token)/i` arg).
- **Sandbox-env allowlist instead of denylist** (D-134) — NEW pattern this phase introduces. Future sandboxes extend the allowlist explicitly.
- **`MuonTrap.cmd/3` for long-running OS-proc wrapping** — NEW pattern this phase introduces. Future shell-out workers (Phase 6 git, Phase 8 diagnostic snapshot zipper) follow suit.

### Integration Points

- `lib/kiln/agents.ex` — currently stub with Phase-3-forward TODO moduledoc. Phase 3 fills this: behaviour, 4 adapters, BudgetGuard, StructuredOutput.
- `lib/kiln/sandboxes.ex` — currently stub with INCORRECT "Phase 4" moduledoc (pre-dates ROADMAP re-ordering). Phase 3 REWRITES the moduledoc to match D-111..D-120 and fills the module.
- `lib/kiln/policies/stuck_detector.ex` — P2 scaffold unchanged; Phase 3 adds sibling `lib/kiln/policies/factory_circuit_breaker.ex` following exact same pattern.
- NEW: `lib/kiln/secrets.ex` + `lib/kiln/secrets/ref.ex`.
- NEW: `lib/kiln/blockers.ex` + `lib/kiln/blockers/{reason.ex, playbook.ex, playbook_registry.ex}`.
- NEW: `lib/kiln/notifications.ex`.
- NEW: `lib/kiln/model_registry.ex` + `lib/kiln/model_registry/preset.ex` + `lib/kiln/pricing.ex`.
- NEW: `lib/kiln/agents/{adapter.ex, prompt.ex, response.ex, structured_output.ex, budget_guard.ex, session_supervisor.ex}` + `lib/kiln/agents/adapter/{anthropic.ex, openai.ex, google.ex, ollama.ex}`.
- NEW: `lib/kiln/sandboxes/{driver.ex, docker_driver.ex, env_builder.ex, hydrator.ex, harvester.ex, image_resolver.ex, limits.ex, container_spec.ex, orphan_sweeper.ex, supervisor.ex}`.
- NEW: `lib/kiln/sandboxes/dtu/{supervisor.ex, health_poll.ex, contract_test.ex, callback_router.ex}`.
- NEW: `lib/kiln/policies/factory_circuit_breaker.ex`.
- NEW: `lib/kiln/stages/next_stage_dispatcher.ex`.
- NEW: `lib/kiln/logging/secret_redactor.ex` (LoggerJSON.Redactor impl).
- NEW under priv: `priv/sandbox/{base,elixir}.Dockerfile`, `priv/sandbox/{limits.yaml, images.lock}`, `priv/playbooks/v1/<9 reasons>.md`, `priv/playbook_schemas/v1/playbook.json`, `priv/model_registry/<6 presets>.exs`, `priv/pricing/v1/{anthropic, openai, google, ollama}.exs`, `priv/dtu/{mix.exs, Dockerfile, lib/kiln_dtu/…}`, `priv/dtu/contracts/github/api.github.com.2026-04.json`.
- NEW audit schemas: `priv/audit_schemas/v1/{orphan_container_swept, dtu_contract_drift_detected, dtu_health_degraded, factory_circuit_opened, factory_circuit_closed, model_deprecated_resolved, notification_fired, notification_suppressed}.json`.
- `compose.yaml` — add `dtu` service with static IP 172.28.0.10 on `kiln-sandbox` IPAM subnet; declare subnet range (e.g., `172.28.0.0/24`). `sandbox-net-anchor` service stays for adversarial egress test.
- `config/runtime.exs` — add provider API key env reads + `Kiln.Secrets.put/2` calls at startup.
- `config/config.exs` — register `Kiln.Logging.SecretRedactor` in `logger_json` config; add `:oban` `:dtu` queue's ContractTest worker registration (no cron).
- `Kiln.Application.start/2` — insert 4 new infra children per D-141..D-142 (net: 14-child supervision tree).
- NEW tests: `test/kiln/agents/*_test.exs` (behaviour + 4 adapter contract tests), `test/kiln/sandboxes/docker_driver_test.exs`, `test/kiln/sandboxes/egress_blocking_test.exs` (adversarial suite), `test/integration/secrets_never_leak_test.exs` (docker-inspect assertion + Anthropix mock header assertion), `test/kiln/blockers/playbook_registry_test.exs`, `test/kiln/policies/factory_circuit_breaker_test.exs` (no-op assertion + supervision-tree presence), `test/kiln/sandboxes/dtu/router_test.exs` (JSV validation + chaos headers + 501-on-unknown).
- `.credo.exs` — consider adding a `NoRawSecretInStruct` custom check (banned; likely defer to Claude's discretion or Phase 9 hardening).
- `.github/workflows/ci.yml` — no structural changes; Postgres 16 service already running; new `:docker` test tag required per-test skip-able for non-Docker-enabled CI workers.

</code_context>

<specifics>
## Specific Ideas

- **"Think deeply, one-shot a coherent recommendation"** — the user's explicit instruction during discussion. All 16 sub-decisions across the 4 gray areas were synthesized into ONE coherent design (see cross-area cohesion block in 03-DISCUSSION-LOG.md). Downstream agents should NOT revisit sub-decisions unless research explicitly invalidates one; the design hangs together.
- **"All five HIGH-cost pitfalls are engineered-against as architectural invariants"** — ROADMAP Phase 3 language. D-117..D-120 structurally prevent P5 sandbox escape; D-131..D-134 structurally prevent P21 secrets leak (type system + env allowlist + 6 redaction layers + docker-inspect test); D-138..D-139 structurally cap P2 cost runaway (per-call pre-flight + scaffolded global breaker); D-104 + "typed tool allowlist groundwork" defend P8 prompt injection; D-18 + `external_operations` + `git ls-remote` precondition (P6 land) defend P3 idempotency.
- **"Principle of least surprise + great DX for a 2am operator"** — the user's explicit priority. DX surfaces: `mix kiln.registry.show <preset>` dumps role→model resolution; `mix kiln.sandbox.build` rebuilds the sandbox image idempotently; `mix kiln.dtu.regen_contract` diffs OpenAPI + emits drift report; `docker inspect .State.OOMKilled` surfaces into `external_operations.result_payload` so "OOM at 2g" is explicit; telemetry emits the exact `docker run` command vector so operator repros locally. Playbook body is plain-English markdown, not YAML.
- **"Fail loudly, never silently"** — consistent with CLAUDE.md ethos. DTU returns 501 on unknown endpoint (no echo-sink); BudgetGuard raises typed block (no warn-and-continue); Hydrator fails stage if any declared `input_artifact` is missing from CAS; sandbox env allowlist fails launch on secret-shaped key name; BootChecks halt in `:prod` on zero providers (warn in `:dev` only).
- **"Stage I/O ONLY via artifact_ref — no bytes cross stage boundaries"** — D-113 structurally enforces D-75 by making the sandbox's `/workspace` a tmpfs + CAS hydration/harvest. No shared mutable filesystem between stages (P19 drift eliminated).
- **"No `git` inside the container, EVER"** — D-113 + D-117 defense-in-depth against P5 + P21. Git ops (init/add/commit/push) happen on the BEAM host against harvested CAS artifacts; sandbox is content-generation only.
- **"Scaffold-now-fill-later for deferred behavior"** — D-91 StuckDetector precedent applied 2nd time via D-139 FactoryCircuitBreaker; all audit kinds declared in P3 so Phase 5 has zero schema migration. Mirrors Phase 2's coherent approach to cross-phase engineering.
- **"Audit is append-only Postgres — DTU log is best-effort local JSONL"** — D-127. DTU never blocks on Kiln availability; its request log is authoritative for its own behavior, audit is best-effort correlation. Prevents DTU outage from cascading into stage failure.
- **"No `KILN_BUDGET_OVERRIDE` escape hatch — force the edit-caps-restart loop"** — D-138 explicit choice. Least-surprise for solo operator at 2am: "I want to be stopped, not to have to remember I set an override". If operator wants more budget, they edit workflow YAML caps and restart the run.
- **"Desktop notifications use OS-native coalescing"** — D-140. macOS `osascript` sticky notifications + ETS `{run_id, reason}` 5-minute TTL dedup on Kiln side; Linux `notify-send -h string:x-canonical-private-synchronous:<tag>` uses native last-write-wins. Operator doesn't get spammed.
- **"Phase 3 supervision tree is 14 children — last lock before Phase 4 adds agent roles"** — D-142. Phase 4 ships Mayor/Planner/Coder/Tester/Reviewer/UIUX/QAVerifier agents under `Kiln.Agents.SessionSupervisor` (which P3 ships empty). Ignoring the per-agent supervision at the TOP level, Phase 4 does NOT add to `Kiln.Application` children — only populates the DynamicSupervisor P3 ships.
- **"All 9 block reasons in the enum at P3 — consumers pattern-match exhaustively from here forward"** — D-135. Prevents "new atom at phase boundary" breakage that would otherwise force consumers to re-match.
- **"Anthropic `count_tokens` is free but rate-limited"** — D-138. Per Anthropic docs the endpoint is free and has "separate and independent rate limits" from message creation. BudgetGuard's pre-flight call is therefore a budget-free safety check, BUT Kiln must track its own rate against count_tokens so a stage burst doesn't cause a second 429 surface.
- **"Fallback chain exhaustion = stage failure with diagnostic artifact"** — D-106. Never silently loop; when every model in the fallback chain fails, stage transitions `:failed`, diagnostic artifact captured (prompt + errors + full trace) via `Kiln.Artifacts`, typed block `:model_unavailable_all_tiers` (or reuse `:unrecoverable_stage_failure`). Operator can inspect the exhaustion story.

</specifics>

<deferred>
## Deferred Ideas

### From this discussion (out-of-scope for Phase 3)

- **LLM-provider mocks in the DTU** — Phase 5 (OPS-02 adaptive routing + 429 fallback tests are the natural consumers). P3 DTU is GitHub-only per D-121.
- **Generic HTTP sink in the DTU** — explicitly rejected. Unknown endpoints return HTTP 501 (fail loudly).
- **Full chaos-mode taxonomy** (timeout_30s, slow_5s, malformed_json, schema_drift) — Phase 5 expands beyond P3's 429+503 per D-125.
- **Weekly `Kiln.Sandboxes.DTU.ContractTest` cron schedule** — Phase 6 toggles the cron; worker is stub-registered in P3 per D-125.
- **Desktop notification on tier-crossing model fallback** — Phase 7 wires `Kiln.Notifications` into the `model_routing_fallback` audit event stream; P3 emits audit event only (D-106 tier_crossed flag makes P7 wiring trivial).
- **Full streaming SSE → PubSub → LiveView backpressure pattern** — Phase 7 (LiveView consumer). P3 ships `stream/2` as Enumerable passthrough + telemetry per D-103.
- **Cross-provider fallback (Anthropic → OpenAI)** — data-level ready via `fallback_policy: :cross_provider` field on each preset (D-107), but never EXERCISED until Phase 5 makes OpenAI adapter live.
- **`Kiln.Policies.FactoryCircuitBreaker` sliding-window body** — Phase 5 fills the no-op stub per D-139 (D-91 StuckDetector precedent).
- **`KILN_BUDGET_OVERRIDE` escape hatch** — explicitly rejected (D-138).
- **Rootless Docker / userns-remap / Kata Containers / gVisor / Firecracker / Docker Sandboxes microVM** — Phase 9 hardening per D-118. P3 ships `runc` with the hardened flag set.
- **Custom seccomp profile** — explicitly rejected in P3 (D-118). Default profile + `--cap-drop=ALL` covers the dangerous 44 syscalls. Revisit only if adversarial suite finds a gap.
- **AppArmor integration** — Linux-only; Phase 9 hardening per D-118 (Kiln dogfoods on Docker Desktop macOS first).
- **Per-language sandbox images beyond Elixir** (TypeScript, Python, Rust) — P3 ships Elixir only per D-111. Phase 9 dogfood validates Elixir path; subsequent phases/milestones add languages as specs demand.
- **OpenAPI-driven server-stub generation for DTU** — Phase 6+ once Elixir OpenAPI server-stub tooling matures (currently alpha per OpenAPI Generator Elixir). P3 hand-writes handlers + JSV-validates responses per D-122.
- **Record-and-replay DTU fixtures (ExVCR-style)** — explicitly rejected per D-122 (PAT-leak risk violates SEC-01). Hand-written handlers ship with controlled test data.
- **GraphQL GitHub mocks** — P3 ships REST only (most agent-generated GitHub code uses REST). GraphQL mocks added when first workflow demands them.
- **Loopback callback from DTU to Kiln — retry queue if Kiln is down** — P3 accepts best-effort callback (D-127). Local JSONL is authoritative; missing audit events are acceptable forensic gap.
- **`Kiln.Pricing.check` Mix task as CI-fatal** — P3 ships as WARN-only (D-146); Phase 9 hardening may make fatal.
- **Provider-split Oban queue (`:stages_anthropic/openai/google/ollama`)** — D-71 trigger evaluated in P3 planning; likely does NOT fire (only Anthropic live). Phase 5 likely triggers.
- **`Kiln.Agents.Prompt.t()` + `Response.t()` rich struct surface** (advanced field set) — P3 ships minimum viable shapes; subsequent phases extend as needed.
- **Typed tool allowlist (BANNED `run_shell/1`)** — P3 ships "groundwork" per ROADMAP pitfalls. Phase 4 per-agent-role enforcement fills it in. P3 just defines the tool-call shape in adapter behaviour.
- **Untrusted-content markers in prompts** (`<untrusted_content source="...">` wrappers) — Phase 4 (agent-role-specific prompt building). P3 adapter layer doesn't wrap content; that's an agent concern.
- **OTel metrics + logs** — "still marked development in Erlang SDK as of April 2026" per STACK.md. P3 ships OTel traces + telemetry events. Phase 9 reverifies SDK status before wiring metrics.
- **Diagnostic snapshot bundle** (OPS-05 — "bundle last 60 minutes") — Phase 8.
- **Operator-configurable FactoryCircuitBreaker threshold** — Phase 5/8 exposes via LiveView + config. P3 hardcodes no threshold because the body is no-op.
- **`:paused` run state / mid-run soft steering** (FEEDBACK-01) — v1.5 per SEED-001; Phase 3 does not add transition matrix edges.
- **`Kiln.Agents.Mayor` / agent-role GenServers / BEADS work-unit store** — Phase 4 (AGENT-03, AGENT-04).
- **Deterministic scenario runner + LLM-explain split** — Phase 5 (SPEC-03, SPEC-04).
- **Holdout scenarios + Verifier-role-only access** — Phase 5 (SPEC-04).
- **Real `git`/`gh` shell-outs** — Phase 6 (GIT-01..03).
- **LiveView run board + cost dashboard + audit ledger view** — Phase 7.
- **BLOCK-02 unblock panel UI + BLOCK-04 onboarding wizard** — Phase 8. P3 provides the playbook content + typed block reasons they render.
- **INTAKE-01..03 intake/inbox + `File as follow-up`** — Phase 8.
- **OPS-04 cost intel + switching advisories** — Phase 8.
- **OBS-02 OpenTelemetry traces full coverage** — Phase 9.

### Reviewed Todos (not folded)

None — `gsd-sdk query todo.match-phase 3` returned 0 matches. Pending SEED-001..005 are v1.5+/v2 scope and correctly excluded. Pending todo `2026-04-18-phase-10-slot-decision.md` triggers at late-Phase-8/early-Phase-9 per its own frontmatter.

</deferred>

---

*Phase: 03-agent-adapter-sandbox-dtu-safety*
*Context gathered: 2026-04-20*
