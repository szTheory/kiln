# Phase 3: Agent Adapter, Sandbox, DTU & Safety — Research

**Researched:** 2026-04-20
**Domain:** Elixir/Phoenix LLM adapter behaviour, Docker sandbox hardening, GitHub API mock (DTU), secrets management, typed-block reasoning, budget pre-flight
**Overall confidence:** HIGH for stack/architecture (all decisions locked in 03-CONTEXT.md); HIGH for Docker hardening and secrets discipline (CIS/OWASP/NIST-grounded); MEDIUM for DTU mock pattern (only StrongDM + LocalStack prior art) and streaming backpressure (deferred to P7 consumer shape); HIGH for Anthropic API (native `output_config` is a 2026 update the planner must adopt over the older `tool_use`-only pattern).

---

## Summary

Phase 3 stands up four load-bearing systems on top of Phase 2's workflow engine: the provider-agnostic agent adapter (Anthropic live + OpenAI/Google/Ollama scaffolded), the ephemeral Docker sandbox with egress blocked at the Docker bridge layer, the Digital Twin Unit (DTU) sidecar that mocks the GitHub REST API inside the sandbox network, and the secrets + typed-block-reasons + per-call BudgetGuard safety envelope. Context engineering is complete: **46 numbered decisions (D-101 through D-155) are locked in `.planning/phases/03-agent-adapter-sandbox-dtu-safety/03-CONTEXT.md`** and stack versions are pinned in `.planning/research/STACK.md`. The planner does not re-litigate library choices or policy shapes; this research validates concrete values, surfaces one 2026 Anthropic API update the CONTEXT didn't catch, and frames the four HIGH-research areas with sources.

**Primary recommendation:** Execute the CONTEXT design as written with four research-derived updates:

1. **Adopt Anthropic's native `output_config: {format: {type: "json_schema", schema: ...}}` as primary structured-output mechanism** for Claude, with `tool_use` demoted to fallback (D-104 assumed `tool_use` was primary — 2026 API update makes `output_config` the preferred path per [Anthropic Structured Outputs docs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)). This is a *non-invasive* refinement: the `Kiln.Agents.Adapter` behaviour shape does not change; only the `Kiln.Agents.StructuredOutput` Anthropic-branch implementation chooses the newer API surface. `[CITED: platform.claude.com]`

2. **Use concrete hardened-sandbox values grounded in CIS Docker Benchmark + Docker Bench for Security:** `--memory=2g --memory-swap=2g --cpus=2 --pids-limit=512 --ulimit nofile=4096:8192 --ulimit nproc=256` for coding/testing/merge stages; `--memory=768m --cpus=1 --pids-limit=256` for planning/verifying. The BEAM baseline (mix compile at ~2GB RSS inside container) justifies the 2g ceiling for Elixir dogfood; CIS recommends `--pids-limit` as primary fork-bomb defense. `[CITED: CIS Docker Benchmark, Docker Bench for Security, elixirforum.com/t/57251]`

3. **Ship `Anthropic.count_tokens` as a pre-flight via direct Req call against `POST https://api.anthropic.com/v1/messages/count_tokens`** — Anthropix 0.6.2 does NOT currently wrap this endpoint (verified against [hexdocs.pm/anthropix](https://hexdocs.pm/anthropix/Anthropix.html)), so Kiln builds ~30 LOC in the Anthropic adapter directly. Response shape is `{"input_tokens": <number>}`; endpoint is free and has separate rate limits from Messages API. `[VERIFIED: platform.claude.com/docs/en/api/messages-count-tokens]`

4. **Use the `port-close + SIGTERM` subprocess kill semantic on macOS** (dev platform) via MuonTrap's C-level parent-watch mechanism; cgroup-v2 containment is Linux-only but the basic "parent dies → children die" guarantee works cross-platform. For Kiln's dev-on-Docker-Desktop-macOS + prod-on-Linux posture this is sufficient — the hardened Docker options (`--rm --init --stop-timeout=10`) provide defense-in-depth against Docker-level orphan containers regardless of BEAM-level subprocess reaping. `[CITED: hexdocs.pm/muontrap]`

---

## User Constraints (from CONTEXT.md)

### Locked Decisions

**All 46 D-numbered decisions in `.planning/phases/03-agent-adapter-sandbox-dtu-safety/03-CONTEXT.md` are locked. This RESEARCH.md does NOT re-open them.** Summary of the structural decisions by gray area:

- **Adapter, ModelRegistry & Streaming (D-101 .. D-110):** `Kiln.Agents.Adapter` behaviour with `complete/2`, `stream/2`, `count_tokens/1`, `capabilities/0` callbacks; Anthropic LIVE via Anthropix 0.6.2 wrap; OpenAI/Google/Ollama SCAFFOLDED on Req ~200 LOC each with `@tag :live_*` gating; `stream/2` returns `{:ok, Enumerable.t()}` with telemetry on every chunk — **NO PubSub in P3**; ModelRegistry loads all 6 D-57 presets from `priv/model_registry/<preset>.exs` with `fallback_policy: :same_provider | :cross_provider` field reserved; fallback policy `:same_provider` only in P3 (only Anthropic live); native structured output per-provider behind `Kiln.Agents.StructuredOutput.request/2` facade with JSV Draft 2020-12 defense-in-depth; Finch named pools per provider; exhaustive fallback triggers (429, 5xx, conn errors, timeouts, context_length_exceeded, content_policy_violation); one `model_routing_fallback` audit event per fallback attempt with `tier_crossed: boolean` flag.

- **Sandbox (D-111 .. D-120):** Per-language Dockerfile pattern, Elixir-first (`hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21` base); adaptive per-stage-kind resource limits in `priv/sandbox/limits.yaml`; workspace = tmpfs RO-in + WO-out via CAS `artifact_ref` handoff (`Kiln.Sandboxes.Hydrator` → stage start; `Kiln.Sandboxes.Harvester` → stage end streaming through `Kiln.Artifacts.put_stream/4`); **no `git` command inside container, ever**; `Kiln.Sandboxes.Driver` behaviour with `DockerDriver` live impl invoking `docker run` via `MuonTrap.cmd/3`; full hardened option set per D-117 (cap-drop=ALL, no-new-privileges, default seccomp, read-only, non-root, memory+pids+ulimit caps, tmpfs, internal-only network, DNS override to DTU, disabled IPv6); **REJECTED in P3**: rootless Docker, userns-remap, custom seccomp, Kata/gVisor microVMs, AppArmor; five-layer DNS block enforcement with adversarial test suite verifying all 5 egress vectors (TCP/UDP/DNS/ICMP/IPv6) fail.

- **DTU (D-121 .. D-128):** GitHub REST API ONLY in P3 (LLM-provider mocks defer to P5); HYBRID generation = hand-written Plug handlers + JSV response validation against pinned `priv/dtu/contracts/github/api.github.com.2026-04.json`; hosted as Docker Compose SIDECAR service at static IP `172.28.0.10` on `kiln-sandbox` IPAM-declared subnet; implemented as separate mini-mix-project at `priv/dtu/` (NOT umbrella — D-97 preserved); chaos LIMITED to `X-DTU-Chaos: rate_limit_429` + `X-DTU-Chaos: outage_503` in P3; unknown endpoint returns `HTTP 501` with `{error, path, method}` body (fail loudly, no echo-sink); DTU posts best-effort audit callback to host-loopback (local JSONL log authoritative); dnsmasq baked into DTU image for `api.github.com` → sidecar IP resolution.

- **Secrets, Block Reasons, Budget (D-131 .. D-140):** HYBRID eager secret loading from `config/runtime.exs` into `persistent_term` at boot (write-once) + presence-map logged structurally + stage-start `:missing_api_key` typed block; `%Kiln.Secrets.Ref{name: atom}` struct with `@derive {Inspect, except: [:name]}`; `Kiln.Secrets.reveal!/1` is the ONLY unboxing surface (grep-audit finds ~3 call sites, one per live adapter); **SIX redaction layers** all ship in P3 (type boundary, Inspect derive, Ecto `redact: true`, `LoggerJSON.Redactor` impl, `Ecto.Changeset.redact_fields`, docker-inspect negative test); sandbox env builder enforces ALLOWLIST + name-regex denial on secret-shaped keys; all 9 BLOCK-01 atoms declared in enum (`missing_api_key`, `invalid_api_key`, `rate_limit_exhausted`, `quota_exceeded`, `gh_auth_expired`, `gh_permissions_insufficient`, `budget_exceeded`, `unrecoverable_stage_failure`, `policy_violation`); 6 REAL playbooks + 3 STUB playbooks with `owning_phase` frontmatter under `priv/playbooks/v1/<reason>.md`; compile-time registry via `@external_resource` (4th instance of the pattern); BudgetGuard = **per-call pre-flight ACTIVE + global `FactoryCircuitBreaker` SCAFFOLDED no-op** (D-91 StuckDetector precedent re-applied); 7-step budget check (read caps → sum spend → count_tokens pre-flight → pricing estimate → compare → pass OR raise); **no `KILN_BUDGET_OVERRIDE` escape hatch**; desktop notifications via `osascript`/`notify-send` shell-out with ETS 5-min dedup; `notification_fired`/`notification_suppressed` audit kinds.

- **Supervision tree, BootChecks, NextStageDispatcher, Audit extensions, Pricing (D-141 .. D-146):** 10 → 14 children (+ `Sandboxes.Supervisor`, `Sandboxes.DTU.Supervisor`, `Agents.SessionSupervisor`, `Policies.FactoryCircuitBreaker`); BootChecks 6 → 8 (+ `secrets_presence_map_non_empty`, `no_prior_boot_sandbox_orphans`); `Kiln.Stages.NextStageDispatcher` picks up Phase 2's deferred auto-enqueue; 25 → 30 audit kinds; `priv/pricing/v1/<provider>.exs` with `Kiln.Pricing.estimate_usd/3` single surface.

- **Spec upgrades in P3 (D-151 .. D-155):** Update CLAUDE.md (supervision tree line 14 children, add 3 Elixir anti-patterns), ARCHITECTURE.md §4+§10+§11+§15, STACK.md (+ `muontrap ~> 1.7`), PITFALLS.md (cross-refs to P2/P5/P17/P21 mitigations). Zero new dependencies beyond MuonTrap.

### Claude's Discretion

Per D-143..D-155 and <deferred> in CONTEXT.md, the planner and executor have flexibility on: exact module filenames within each context dir; `Prompt.t()` + `Response.t()` internal struct shapes (public API fields documented); pricing data in `priv/pricing/v1/<provider>.exs` (planner fetches from provider pages during planning — FLAGGED here for research validation); resource-limit NUMBERS in `priv/sandbox/limits.yaml` within the POLICY SHAPE; Finch named-pool sizing per provider within aggregate budget; test fixture shapes; exact handler file organization under `priv/dtu/lib/kiln_dtu/handlers/github/*.ex`; whether `OrphanSweeper` is GenServer vs boot-time Task; whether Mustache is inline <30 LOC or `:bbmustache` dep; playbook body copy within brand voice; test organization under `test/kiln/{agents,sandboxes,blockers,policies}/`.

### Deferred Ideas (OUT OF SCOPE)

Per CONTEXT.md <deferred> section, out of scope for P3: LLM-provider mocks in DTU (→ P5); generic HTTP sink in DTU (rejected); full chaos taxonomy beyond 429+503 (→ P5); weekly contract-test cron (→ P6); desktop notification on tier-crossing fallback (→ P7); full SSE → PubSub → LiveView backpressure (→ P7); cross-provider fallback execution (→ P5); `FactoryCircuitBreaker` sliding-window body (→ P5); `KILN_BUDGET_OVERRIDE` (rejected); rootless Docker / userns-remap / Kata / gVisor / microVMs (→ P9); custom seccomp (rejected in P3); AppArmor (→ P9); non-Elixir sandbox images (→ per-adoption after P9); OpenAPI-driven server stubs (→ P6+); ExVCR record-and-replay (rejected — PAT leak risk); GraphQL GitHub mocks (on-demand); loopback audit retry queue (accepted best-effort); `mix kiln.pricing.check` as CI-fatal (→ P9); provider-split Oban queue (→ P5 trigger); rich Prompt/Response struct surfaces (iterative); typed tool allowlist enforcement (→ P4); untrusted-content markers (→ P4); OTel metrics + logs (→ P9 SDK re-check); diagnostic snapshot bundle (→ P8); operator-configurable FactoryCircuitBreaker threshold (→ P5/P8); `:paused` state / mid-run steering (→ v1.5); Mayor + agent-role GenServers (→ P4); scenario runner (→ P5); real git/gh (→ P6); LiveView UI (→ P7); unblock panel + onboarding wizard (→ P8); intake/inbox (→ P8); OPS-04 cost intel (→ P8); OBS-02 OTel coverage (→ P9).

---

## Phase Requirements

| ID | Description (from REQUIREMENTS.md) | Research Support |
|----|-----------------------------------|------------------|
| AGENT-01 | Provider-agnostic LLM adapter; Anthropic live (anthropix), OpenAI/Google/Ollama rolled-own (~200 LOC each) | `Standard Stack` (Anthropix 0.6.2 API shape), `Architecture Patterns → Pattern 1` (Adapter behaviour callback set); Anthropix does NOT wrap `count_tokens` — implement direct Req call, ~30 LOC. |
| AGENT-02 | Per-stage model selection via workflow YAML; ModelRegistry resolves role → model with fallback chain | `Architecture Patterns → Pattern 2` (ModelRegistry preset → role → fallback resolution) |
| AGENT-05 | Token + cost telemetry per call; `requested_model` + `actual_model_used` recorded per stage | `Architecture Patterns → Pattern 3` (Telemetry contract), `Common Pitfalls → Silent Model Fallback` |
| SAND-01 | Every stage in ephemeral Docker container, auto-cleaned on completion or crash | `Sandbox Resource Limits` table + `Architecture Patterns → Pattern 4` (MuonTrap + `--rm` + OrphanSweeper) |
| SAND-02 | Network egress blocked at Docker bridge (`internal: true`) except to DTU mock network; adversarial test verifies TCP/UDP/DNS/ICMP/IPv6 blocked | `Adversarial Negative-Test Suite` section |
| SAND-03 | DTU — local HTTP mocks for GitHub API; contract-tested weekly | `DTU Mock Generation Pipeline` section |
| SAND-04 | Workspace read-write into sandbox; diff captured at stage end; stored in content-addressed artifact store | `Architecture Patterns → Pattern 5` (Hydrator/Harvester via `Kiln.Artifacts.put_stream/4`); note D-113 CLARIFIES as tmpfs-RW + CAS hydration, NOT host bind-mount |
| SEC-01 | Secrets = references only; values from `persistent_term` at point-of-use; `@derive {Inspect, except: [:api_key]}`; never persist to workspace or logs | `Code Examples → Secret reveal boundary` + `Common Pitfalls → Secret Leak Paths` |
| BLOCK-01 | Typed block reasons mapped to remediation playbooks | `Architecture Patterns → Pattern 6` (compile-time PlaybookRegistry, 4th instance of the `@external_resource` pattern) |
| BLOCK-03 | Desktop notification on blocked/escalated via `osascript`/`notify-send` | `Code Examples → Desktop notification dispatch` |
| OPS-02 | Adaptive model routing on 429/5xx with fallback; tier-crossing operator notification | `Architecture Patterns → Pattern 2` + `Common Pitfalls → Silent Model Fallback`; DTU `X-DTU-Chaos: rate_limit_429` header is the test affordance |
| OPS-03 | Model-profile presets keyed to software type (6 presets); per-role {role → model} | Covered by ModelRegistry preset pattern + D-105 resolution algorithm |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| LLM API call (HTTP) | API/Backend (Adapter) | — | Provider-agnostic HTTP over Finch named pools; secrets live here only. |
| Token counting + cost estimate | API/Backend (BudgetGuard) | — | Must run BEFORE the LLM call; pure function over pricing table + count_tokens response. |
| Budget enforcement | API/Backend (BudgetGuard) | Database (runs.caps_snapshot + SUM(stage_runs.tokens_used_usd)) | 7-step check reads run-scoped caps from Postgres; raise-on-breach is in-memory but ledger is durable. |
| Model fallback chain | API/Backend (ModelRegistry resolver) | Audit ledger | Resolver is pure; every attempt writes `model_routing_fallback` audit event. |
| Docker container lifecycle | OS subprocess (MuonTrap-wrapped docker CLI) | Database (external_operations two-phase intent) | `docker run` is a side effect; intent row opens a tx, completion closes. |
| Workspace I/O | Tmpfs (in-container) + CAS (out) | Database (artifact rows + `artifact_written` audit) | Hydrator reads artifact_refs from CAS; Harvester streams tmpfs `/workspace/out/` → CAS. |
| Network egress blocking | Docker networking layer (`internal: true` bridge + DNS override) | OS sysctl (IPv6 disabled per-container) | Enforced at infra, not code; adversarial test verifies all 5 egress vectors. |
| DTU HTTP serving | Separate BEAM release in Docker sidecar | Local JSONL log (authoritative) + best-effort callback to Kiln host-loopback | DTU cannot run in main Kiln BEAM — `internal: true` bridge reachability test would fail. |
| Secret reveal | `persistent_term` → `reveal!/1` → HTTP Authorization header | Type system enforcement (%Ref{} struct; raw string never crosses function boundary) | 6 redaction layers; grep-audit for `reveal!` finds ~3 call sites. |
| Typed block reason | `Kiln.Blockers.PlaybookRegistry` compile-time registry | Audit ledger (block_raised kind) + Notifications (desktop shell-out) | Pattern-match exhaustive from P3 forward; rendering is markdown → terminal/LiveView/Slack. |
| Streaming chunk passthrough | Adapter (Enumerable wrapper) | Telemetry event per chunk | **NO PubSub in P3** — consumer shape (work units in P4, LiveView in P7) decides backpressure policy when there is a consumer to calibrate against. |

---

## Standard Stack

All versions pre-pinned in `.planning/research/STACK.md`. P3 adds **one** dep.

### Core (already pinned in P2)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Anthropix | 0.6.2 | Anthropic API client (unofficial; actively maintained; single maintainer) | Only full-featured Elixir Anthropic SDK; supports `tool_use`, streaming (Enumerable + pid modes), extended thinking, prompt caching, message batching. `[VERIFIED: hexdocs.pm/anthropix/Anthropix.html]` — note: does **NOT** wrap `count_tokens` endpoint. |
| Req | 0.5.17 | Sole HTTP client | Built on Finch; step-plugin model is ideal for LLM adapter retry/log/telemetry layer; Elixir-core maintainer. |
| Finch | ~> 0.19 (transitive) | Mint-based connection pool | Named pools per provider prevent one provider's 429 storm from starving another. |
| Oban | 2.21 OSS | Durable jobs | `:dtu` queue gets its first real worker registration in P3 (ContractTest stub, cron unscheduled). |
| JSV | 0.18.1 | JSON Schema Draft 2020-12 validator | Response-send-time validation against pinned `priv/dtu/contracts/github/api.github.com.2026-04.json`; defense-in-depth for structured output. |
| yaml_elixir | 2.12.1 | Limits config parsing | Parses `priv/sandbox/limits.yaml`. |
| logger_json | 7.0.4 | Structured JSON logging | `Kiln.Logging.SecretRedactor` registered as `LoggerJSON.Redactor` impl. |
| Bandit | 1.10.4 | HTTP server for DTU sidecar | Works standalone outside Phoenix — `{Bandit, plug: MyApp.MyPlug}` is the minimum startup. `[CITED: github.com/mtrudel/bandit]` |
| `opentelemetry_process_propagator` | ~> 0.3 | Trace context propagation across Oban → LLM call | Use `fetch_parent_ctx(1, :"$callers")` inside StageWorker to link LLM spans to enqueueing transition (P17 PITFALLS mitigation). |

### New in P3

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **muontrap** | **~> 1.7** | Crash-safe OS subprocess wrapper for `docker run` | "If the Erlang process that runs the command dies, the OS processes die as well" — solves port-hygiene + cgroup-v2 resource containment on Linux; port-close/signal semantics on macOS. Nerves-ecosystem maintained. `[CITED: hexdocs.pm/muontrap]` |

**Version verification commands:**

```bash
mix hex.info muontrap            # expect ~> 1.7
mix hex.info anthropix           # expect 0.6.2
mix hex.info jsv                 # expect 0.18.1
curl -s https://hex.pm/api/packages/muontrap | jq .latest_stable_version
```

### Alternatives Considered (all rejected per D-101..D-155)

| Instead of | Could Use | Tradeoff | Why Rejected for P3 |
|------------|-----------|----------|---------------------|
| Anthropix (for Anthropic) | Roll own on Req | More control; no single-maintainer risk | Anthropix ships working streaming + tool_use today; wrapping behind behaviour is the escape hatch. |
| MuonTrap | Raw `System.cmd` + Port + trap_exit | 1 fewer dep; more code to maintain | MuonTrap's C-binary parent-watch is the exact primitive Kiln needs; ~500 LOC saved. |
| Hand-written DTU handlers | OpenAPI server stub generation | Less code | OpenAPI Generator Elixir is *alpha and client-only* as of 2026; server stubs not viable. StrongDM's success metric is "SDK compatibility" which requires behavioral realism hand-written handlers give. `[CITED: openapi-generator.tech/docs/generators/elixir]` |
| JSV response validation | Prism (Stoplight OpenAPI mock) | Less code | Prism's random-examples strategy fails SDK round-trip fidelity (StrongDM's metric); also no custom chaos injection. |
| ExVCR record-replay for DTU | Hand-written fixtures | Easy recording | Rejected per D-122 — PAT-leak risk into fixtures violates SEC-01. |
| Fuse/external_service for BudgetGuard | Build circuit breaker | Battle-tested circuit breaker | P3 BudgetGuard is PRE-FLIGHT per-call (not circuit-style) + `FactoryCircuitBreaker` is scaffolded no-op; Fuse-style sliding-window is P5's concern. |
| Custom seccomp JSON | Default seccomp profile | Finer-grained syscall control | Docker's default seccomp blocks ~44 syscalls (`[CITED: docs.docker.com/engine/security/seccomp]`); combined with `--cap-drop=ALL` covers Kiln's threat model. Custom profiles are a tuning pit per D-118. |

**Installation:**

Add to `mix.exs` deps:
```elixir
{:muontrap, "~> 1.7"}
```

---

## Architecture Patterns

### System Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                     Kiln BEAM (host, asdf-managed)                     │
│                                                                        │
│  config/runtime.exs                                                    │
│   └── System.get_env("ANTHROPIC_API_KEY") ──► Kiln.Secrets.put/2       │
│                                               (persistent_term @ boot) │
│                                                                        │
│  Kiln.Application children (14):                                       │
│    ... P1/P2 children ...                                              │
│    ├── Kiln.Sandboxes.Supervisor                                       │
│    │    ├── Kiln.Sandboxes.OrphanSweeper (boot-first)                  │
│    │    └── Kiln.Sandboxes.DockerDriver                                │
│    ├── Kiln.Sandboxes.DTU.Supervisor                                   │
│    │    └── Kiln.Sandboxes.DTU.HealthPoll                              │
│    │    (+ ContractTest registered on :dtu queue, unscheduled)         │
│    ├── Kiln.Agents.SessionSupervisor (DynamicSupervisor; P4 populates) │
│    ├── Kiln.Policies.FactoryCircuitBreaker (no-op body)                │
│    └── KilnWeb.Endpoint                                                │
│                                                                        │
│  Stage execution path (Kiln.Stages.StageWorker Oban job):              │
│    1. BudgetGuard.check!/2  ──► Anthropix.count_tokens (free endpoint) │
│    2. Hydrator.hydrate/2    ──► tmpfs /workspace ◄── CAS.read_stream/2 │
│    3. DockerDriver.run_stage/1 ──► MuonTrap.cmd("docker", ["run", ...])│
│    4. (inside container) agent executes                                │
│    5. Harvester.harvest/2   ──► tmpfs /workspace/out ──► CAS.put_stream│
│    6. NextStageDispatcher.enqueue_next/2 (same tx as stage completion) │
│                                                                        │
│  Adapter call path (inside container scope):                           │
│    StageWorker ─► Adapter.Anthropic.complete/2                         │
│                     │                                                  │
│                     ├─► Req.post! + Finch pool Kiln.Finch.Anthropic    │
│                     │    Authorization: Bearer #{Secrets.reveal!(...)} │
│                     │   (reveal! is the ONLY unboxing site; ~3 total)  │
│                     │                                                  │
│                     ├─► Response.t() → telemetry                       │
│                     │   [:kiln, :agent, :call, :stop]                  │
│                     │     metadata: requested_model, actual_model_used │
│                     │                                                  │
│                     └─► fallback on 429/5xx → ModelRegistry.next/2     │
│                          (same_provider in P3) → audit event           │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│    Docker bridge network "kiln-sandbox" (internal: true, no gateway)   │
│                                                                        │
│  ┌─────────────────────────────────┐    ┌──────────────────────────┐   │
│  │ Stage container                 │    │ DTU sidecar (172.28.0.10)│   │
│  │ (ephemeral, kiln/sandbox-elixir)│    │                          │   │
│  │                                 │    │ Bandit + Plug.Router     │   │
│  │ user: 1000:1000 (kiln)          │    │ dnsmasq → api.github.com │   │
│  │ cap-drop=ALL                    │    │                          │   │
│  │ no-new-privileges               │ ─► │ hand-written handlers    │   │
│  │ seccomp=default                 │    │ JSV-validated responses  │   │
│  │ read-only root FS               │    │                          │   │
│  │ tmpfs: /tmp /workspace /.cache  │    │ chaos: X-DTU-Chaos        │   │
│  │ --memory=2g --pids=512          │    │  = rate_limit_429 | 503  │   │
│  │ --ulimit nofile=4096:8192       │    │                          │   │
│  │ --dns 172.28.0.10               │    │ unknown → HTTP 501       │   │
│  │ --add-host api.github.com:10    │    │                          │   │
│  │ --sysctl ipv6.disable=1         │    │ JSONL log @ priv/dtu/runs│   │
│  │ --label kiln.boot_epoch=<mono>  │    │ (authoritative)          │   │
│  │                                 │    │                          │   │
│  │ curl api.github.com  ──────────►│    │ best-effort callback ──► │   │
│  │ curl 8.8.8.8         ✗ blocked  │    │  http://172.28.0.1:4001/ │   │
│  │ ping 8.8.8.8         ✗ blocked  │    │   internal/dtu/event     │   │
│  │ IPv6 curl            ✗ disabled │    │                          │   │
│  │ DNS public           ✗ NXDOMAIN │    └──────────────────────────┘   │
│  └─────────────────────────────────┘                                   │
└────────────────────────────────────────────────────────────────────────┘
```

### Recommended Directory Structure (extends ARCHITECTURE.md §15 per D-153)

```
lib/kiln/
├── agents.ex                    # context façade
├── agents/
│   ├── adapter.ex               # @behaviour callbacks (D-102)
│   ├── prompt.ex                # Prompt.t() opaque-ish struct
│   ├── response.ex              # Response.t() with actual_model_used etc.
│   ├── structured_output.ex     # per-provider native mode dispatch (D-104)
│   ├── budget_guard.ex          # check!/2 (D-138, 7 steps)
│   ├── session_supervisor.ex    # DynamicSupervisor — P4 populates
│   └── adapter/
│       ├── anthropic.ex         # Anthropix wrap + direct Req for count_tokens
│       ├── openai.ex            # ~200 LOC Req-based scaffold
│       ├── google.ex            # ~200 LOC Req-based scaffold
│       └── ollama.ex            # ~200 LOC Req-based scaffold
├── secrets.ex                   # put/2, get!/1, reveal!/1, present?/1
├── secrets/ref.ex               # %Ref{name: atom} + @derive Inspect
├── blockers.ex                  # raise_block/2 wrapper; typed reason guards
├── blockers/
│   ├── reason.ex                # 9-atom enum (D-135)
│   ├── playbook.ex              # %Playbook{} + %RenderedPlaybook{}
│   └── playbook_registry.ex     # @external_resource compile-time registry
├── notifications.ex             # desktop/2 + ETS dedup
├── model_registry.ex            # resolve/2 + preset loader
├── model_registry/preset.ex     # %Preset{} struct
├── pricing.ex                   # estimate_usd/3
├── policies/
│   └── factory_circuit_breaker.ex   # scaffolded no-op GenServer
├── sandboxes.ex                 # context façade (REWRITE stale moduledoc)
├── sandboxes/
│   ├── supervisor.ex
│   ├── driver.ex                # @behaviour (D-115)
│   ├── docker_driver.ex         # MuonTrap.cmd/3 live impl
│   ├── container_spec.ex        # %ContainerSpec{} struct (D-116)
│   ├── env_builder.ex           # allowlist enforcement (D-134)
│   ├── hydrator.ex              # CAS → /workspace (pure)
│   ├── harvester.ex             # /workspace/out → CAS (pure)
│   ├── image_resolver.ex        # language → image_ref (pure)
│   ├── limits.ex                # YAML → persistent_term loader
│   ├── orphan_sweeper.ex        # boot-first; docker ps --filter label
│   └── dtu/
│       ├── supervisor.ex
│       ├── health_poll.ex
│       ├── contract_test.ex     # Oban worker, unscheduled in P3
│       └── callback_router.ex   # separate Bandit endpoint, loopback-only
├── stages/
│   └── next_stage_dispatcher.ex     # D-144 auto-enqueue
└── logging/
    └── secret_redactor.ex       # LoggerJSON.Redactor impl

priv/
├── sandbox/
│   ├── base.Dockerfile
│   ├── elixir.Dockerfile
│   ├── limits.yaml              # per-stage-kind resource numbers
│   └── images.lock              # pinned digests
├── playbooks/v1/
│   ├── missing_api_key.md       # REAL
│   ├── invalid_api_key.md       # REAL
│   ├── rate_limit_exhausted.md  # REAL
│   ├── quota_exceeded.md        # REAL
│   ├── budget_exceeded.md       # REAL
│   ├── policy_violation.md      # REAL (has live consumer via D-134)
│   ├── gh_auth_expired.md       # STUB, owning_phase: 6
│   ├── gh_permissions_insufficient.md  # STUB, owning_phase: 6
│   └── unrecoverable_stage_failure.md  # STUB, owning_phase: 5
├── playbook_schemas/v1/playbook.json
├── model_registry/
│   ├── elixir_lib.exs
│   ├── phoenix_saas_feature.exs
│   ├── typescript_web_feature.exs
│   ├── python_cli.exs
│   ├── bugfix_critical.exs
│   └── docs_update.exs
├── pricing/v1/
│   ├── anthropic.exs
│   ├── openai.exs
│   ├── google.exs
│   └── ollama.exs
├── dtu/
│   ├── mix.exs                  # separate mini-project
│   ├── Dockerfile               # multi-stage: Elixir release → Alpine + BEAM + dnsmasq
│   ├── lib/kiln_dtu/
│   │   ├── application.ex
│   │   ├── router.ex
│   │   ├── validation.ex        # JSV send-time check
│   │   ├── chaos.ex             # X-DTU-Chaos header parsing
│   │   └── handlers/github/     # one file per endpoint family
│   │       ├── issues.ex
│   │       ├── pulls.ex
│   │       ├── checks.ex
│   │       ├── contents.ex
│   │       ├── branches.ex
│   │       └── tags.ex
│   └── contracts/github/
│       └── api.github.com.2026-04.json   # bundled-dereferenced from github/rest-api-description
└── audit_schemas/v1/
    ├── orphan_container_swept.json           # NEW
    ├── dtu_contract_drift_detected.json      # NEW (body stub)
    ├── dtu_health_degraded.json              # NEW
    ├── factory_circuit_opened.json           # NEW (stub: scaffolded: true)
    ├── factory_circuit_closed.json           # NEW (stub: scaffolded: true)
    ├── model_deprecated_resolved.json        # NEW
    ├── notification_fired.json               # NEW
    └── notification_suppressed.json          # NEW
```

### Pattern 1: Adapter Behaviour (D-101 .. D-102)

**What:** Provider-agnostic LLM interface. Mirrors `instructor_lite`'s minimal shape. The behaviour is exercised by swapping between Anthropic live + Mox fakes for Openai/Google/Ollama, preventing Anthropic-specific idioms from leaking into the contract.

**When to use:** Every LLM call in Kiln goes through this behaviour. The `Kiln.Agents` context never bypasses it.

**Example:**

```elixir
# Source: D-102 + verified against hexdocs.pm/anthropix/Anthropix.html
defmodule Kiln.Agents.Adapter do
  @type capabilities :: %{
          streaming: boolean(),
          tools: boolean(),
          thinking: boolean(),
          vision: boolean(),
          json_schema_mode: boolean()
        }

  @callback complete(prompt :: Kiln.Agents.Prompt.t(), opts :: keyword()) ::
              {:ok, Kiln.Agents.Response.t()} | {:error, term()}

  @callback stream(prompt :: Kiln.Agents.Prompt.t(), opts :: keyword()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @callback count_tokens(prompt :: Kiln.Agents.Prompt.t()) ::
              {:ok, non_neg_integer()} | {:error, term()}

  @callback capabilities() :: capabilities()
end

defmodule Kiln.Agents.Adapter.Anthropic do
  @behaviour Kiln.Agents.Adapter

  @impl true
  def capabilities,
    do: %{streaming: true, tools: true, thinking: true, vision: true, json_schema_mode: true}

  @impl true
  def complete(%Kiln.Agents.Prompt{} = prompt, opts) do
    api_key = Kiln.Secrets.reveal!(:anthropic_api_key)
    client = Anthropix.init(api_key, receive_timeout: 120_000)

    # NOTE: Anthropix 0.6.2 supports :tool_use for structured output today.
    # 2026 API update: prefer output_config.format.json_schema when caller
    # passes a :schema opt (StructuredOutput facade handles the dispatch).
    case Anthropix.chat(client, prompt_to_keyword(prompt, opts)) do
      {:ok, raw_response} -> {:ok, to_response_struct(raw_response)}
      {:error, reason}    -> {:error, classify_error(reason)}
    end
  end

  @impl true
  def count_tokens(%Kiln.Agents.Prompt{} = prompt) do
    # Anthropix 0.6.2 does NOT wrap count_tokens — direct Req call (~30 LOC).
    # [VERIFIED: hexdocs.pm/anthropix does not list count_tokens API]
    api_key = Kiln.Secrets.reveal!(:anthropic_api_key)

    Req.post(
      "https://api.anthropic.com/v1/messages/count_tokens",
      finch: Kiln.Finch.Anthropic,
      headers: [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ],
      json: prompt_to_count_tokens_body(prompt)
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"input_tokens" => n}}} -> {:ok, n}
      {:ok, %Req.Response{status: s, body: b}} -> {:error, {:http, s, b}}
      {:error, err} -> {:error, err}
    end
  end

  # ...
end
```

**Source:** Adapter behaviour shape verified against D-102 (CONTEXT.md). `count_tokens` response shape `{"input_tokens": <number>}` `[VERIFIED: platform.claude.com/docs/en/api/messages-count-tokens]`. Anthropix `count_tokens` omission `[VERIFIED: hexdocs.pm/anthropix/Anthropix.html]`.

### Pattern 2: ModelRegistry preset → role → fallback resolution (D-105 .. D-108)

**What:** Pure function `Kiln.ModelRegistry.resolve(preset_name, stage_overrides)` returns `%{agent_role => %{model, fallback, tier_crossing_alerts_on, fallback_policy}}` loaded from `priv/model_registry/<preset>.exs`. When a call fails with a fallback trigger (429, 5xx, context_length_exceeded, content_policy_violation), `Kiln.ModelRegistry.next/2` returns the next model in the chain, emits `model_routing_fallback` audit event, and the adapter re-tries.

**When to use:** Every stage-level model selection. Overrides flow bottom-up: workflow YAML per-stage > run `model_profile` preset > registry default.

**Example:**

```elixir
# priv/model_registry/phoenix_saas_feature.exs
%{
  planner: %{
    model: "claude-opus-4-5",
    fallback: ["claude-sonnet-4-5", "claude-haiku-4-5"],
    tier_crossing_alerts_on: ["claude-haiku-4-5"],  # Sonnet→Haiku warns
    fallback_policy: :same_provider  # P3: Anthropic-only; P5 flips to :cross_provider
  },
  coder: %{
    model: "claude-sonnet-4-5",
    fallback: ["claude-haiku-4-5"],
    tier_crossing_alerts_on: ["claude-haiku-4-5"],
    fallback_policy: :same_provider
  },
  verifier: %{
    model: "claude-haiku-4-5",
    fallback: [],
    tier_crossing_alerts_on: [],
    fallback_policy: :same_provider
  }
  # ... router, ui_ux, tester, reviewer, mayor
}
```

**Fallback taxonomy (D-106, verified against [LiteLLM reliability docs](https://docs.litellm.ai/docs/proxy/reliability)):**

| Trigger | Audit `fallback_reason` atom | HTTP status |
|---------|------------------------------|-------------|
| Rate limit | `:rate_limit_429` | 429 |
| Server error | `:provider_5xx` | 500-599 |
| Connection error | `:connection_error` | n/a |
| Timeout | `:timeout` | n/a |
| Context length | `:context_length_exceeded` | 400 (message shape) |
| Content policy | `:content_policy_violation` | 400 (message shape) |

**Audit event payload** (per fallback attempt):

```json
{
  "stage_run_id": "uuid-v7",
  "run_id": "uuid-v7",
  "role": "coder",
  "requested_model": "claude-sonnet-4-5",
  "actual_model_used": "claude-haiku-4-5",
  "fallback_reason": "rate_limit_429",
  "tier_crossed": true,
  "attempt_number": 2,
  "provider_http_status": 429,
  "wall_clock_ms": 1843
}
```

### Pattern 3: Telemetry Contract (D-110)

**What:** Every LLM call emits a span pair; every chunk emits a lightweight event. Metadata includes `requested_model`, `actual_model_used`, `fallback?`, plus `opentelemetry_process_propagator.fetch_parent_ctx(1, :"$callers")` to link back to the enqueueing transition.

**Example:**

```elixir
# Adapter.call wrapper
:telemetry.span(
  [:kiln, :agent, :call],
  %{
    run_id: run_id,
    stage_id: stage_id,
    requested_model: requested,
    actual_model_used: actual,
    provider: :anthropic,
    role: :coder,
    fallback?: requested != actual
  },
  fn ->
    result = Adapter.Anthropic.complete(prompt, opts)
    {result, %{duration_native: ..., tokens_in: ..., tokens_out: ..., cost_usd: ...}}
  end
)

# Per-chunk streaming telemetry (no PubSub in P3 per D-103)
Stream.each(anthropix_stream, fn chunk ->
  :telemetry.execute(
    [:kiln, :agent, :stream, :chunk],
    %{byte_size: byte_size(chunk), elapsed_since_start: ...},
    %{run_id: run_id, stage_id: stage_id, actual_model_used: actual}
  )
end)
```

### Pattern 4: Docker subprocess wrap via MuonTrap (D-115)

**What:** `Kiln.Sandboxes.DockerDriver` invokes `docker run <hardened flags>` via `MuonTrap.cmd/3` (not `System.cmd/3` directly) so that a BEAM crash mid-container tears down the Docker client subprocess-tree.

**Cross-platform behavior:** On Linux, MuonTrap uses cgroup-v2 for containment. On macOS (Kiln's dev platform — Docker Desktop), MuonTrap uses parent-watch + signal handling; the basic "parent dies → children die" guarantee works cross-platform per MuonTrap's core promise. `[CITED: hexdocs.pm/muontrap]`

**Defense-in-depth (macOS doesn't get cgroups):**
- `docker run --rm` — first-line orphan prevention (Docker side)
- `docker run --init` — tini reaps zombie children in container
- `docker run --stop-timeout 10` — SIGTERM grace for Elixir shutdown hooks
- `Kiln.Sandboxes.OrphanSweeper` at boot — enumerates `kiln.boot_epoch != current` containers, force-removes

**Example:**

```elixir
defmodule Kiln.Sandboxes.DockerDriver do
  @behaviour Kiln.Sandboxes.Driver

  @impl true
  def run_stage(%Kiln.Sandboxes.ContainerSpec{} = spec) do
    args = build_docker_run_args(spec)

    :telemetry.execute(
      [:kiln, :sandbox, :docker, :run, :start],
      %{},
      %{run_id: spec.labels.run_id, stage_run_id: spec.labels.stage_run_id, cmd: ["docker" | args]}
    )

    # MuonTrap.cmd/3: "If the Erlang process dies, the OS process dies too."
    case MuonTrap.cmd("docker", args,
           stderr_to_stdout: true,
           timeout: spec.wall_clock_timeout_ms,
           # Linux only; ignored on macOS:
           cgroup_controllers: ["memory", "pids"],
           cgroup_path: "muontrap/kiln/#{spec.labels.stage_run_id}"
         ) do
      {output, 0}          -> {:ok, parse_run_result(output, spec)}
      {output, :timeout}   -> {:error, {:timeout, output}}
      {output, exit_code}  -> {:error, {:docker_exit, exit_code, output}}
    end
  end
end
```

### Pattern 5: CAS Hydrator / Harvester (D-113)

**What:** Stage I/O is by `artifact_ref` only — no shared mutable filesystem between stages. `Hydrator` reads the stage input contract's declared `input_artifacts`, pulls from CAS, materializes into `/workspace/<artifact_name>` on tmpfs before container start. `Harvester` walks `/workspace/out/` after container exit, streams each file through `Kiln.Artifacts.put_stream/4` (streaming SHA-256; never holds full bytes in memory), emits one `artifact_written` audit event per output — **all inside the stage-completion Postgres transaction**.

**Example:**

```elixir
defmodule Kiln.Sandboxes.Hydrator do
  @spec hydrate(Kiln.Stages.StageRun.t(), Path.t()) :: {:ok, [Path.t()]} | {:error, term()}
  def hydrate(stage_run, workspace_path) do
    contract = Kiln.Stages.ContractRegistry.lookup(stage_run.stage_id)

    # Declared input_artifacts are the only things the stage can read.
    Enum.reduce_while(contract.input_artifacts, {:ok, []}, fn artifact_decl, {:ok, acc} ->
      case Kiln.Artifacts.read_stream(artifact_decl.ref) do
        {:ok, stream} ->
          target = Path.join(workspace_path, artifact_decl.logical_name)
          :ok = stream_to_file(stream, target)
          {:cont, {:ok, [target | acc]}}

        {:error, :not_found} ->
          # Fail loudly — stage input contract lying is a BUG.
          {:halt, {:error, {:missing_artifact, artifact_decl.ref}}}
      end
    end)
  end
end

defmodule Kiln.Sandboxes.Harvester do
  @spec harvest(Kiln.Stages.StageRun.t(), Path.t()) :: {:ok, [artifact_ref]} | {:error, term()}
  def harvest(stage_run, workspace_path) do
    out_dir = Path.join(workspace_path, "out")

    File.ls!(out_dir)
    |> Enum.reduce_while({:ok, []}, fn filename, {:ok, acc} ->
      full = Path.join(out_dir, filename)
      stream = File.stream!(full, [], 64 * 1024)  # 64KiB chunks

      # put_stream/4 does streaming SHA-256; no full-bytes in memory
      case Kiln.Artifacts.put_stream(stream, filename, detect_content_type(filename), %{
             stage_run_id: stage_run.id,
             run_id: stage_run.run_id
           }) do
        {:ok, ref} ->
          # Write audit event INSIDE the stage-completion tx
          Kiln.Audit.append!(%{
            kind: :artifact_written,
            payload: %{ref: ref, logical_name: filename, stage_run_id: stage_run.id}
          })

          {:cont, {:ok, [ref | acc]}}

        err ->
          {:halt, err}
      end
    end)
  end
end
```

### Pattern 6: Compile-time Playbook Registry (D-136 — 4th instance of the pattern)

**What:** `priv/playbooks/v1/<reason>.md` — markdown body with YAML frontmatter. At compile time, `Kiln.Blockers.PlaybookRegistry` declares `@external_resource` for each file, parses frontmatter, validates against `priv/playbook_schemas/v1/playbook.json` using JSV, and builds a compile-time map. Mustache-style `{var}` substitution from block context map at render time. **Pattern mirrors `Kiln.Audit.SchemaRegistry` (P1 D-09), `Kiln.Stages.ContractRegistry` (P2 D-73), and `Kiln.Workflows.SchemaRegistry` (P2 D-100).**

**Example:**

```elixir
defmodule Kiln.Blockers.PlaybookRegistry do
  @playbook_dir "priv/playbooks/v1"
  @playbook_files @playbook_dir |> Path.join("*.md") |> Path.wildcard()

  for f <- @playbook_files, do: @external_resource(f)

  @playbooks (for f <- @playbook_files, into: %{} do
    {frontmatter, body} = Kiln.Blockers.Playbook.parse!(File.read!(f))
    :ok = Kiln.Blockers.Playbook.validate_frontmatter!(frontmatter)
    reason = String.to_atom(Path.basename(f, ".md"))
    {reason, %Kiln.Blockers.Playbook{frontmatter: frontmatter, body: body}}
  end)

  @spec render(reason :: atom, context :: map) :: Kiln.Blockers.RenderedPlaybook.t()
  def render(reason, context) do
    pb = Map.fetch!(@playbooks, reason)
    %Kiln.Blockers.RenderedPlaybook{
      title: mustache(pb.frontmatter.title, context),
      severity: pb.frontmatter.severity,
      short_message: mustache(pb.frontmatter.short_message, context),
      commands: pb.frontmatter.remediation_commands,
      body_markdown: mustache(pb.body, context)
    }
  end

  defp mustache(template, context), do: # ~25 LOC inline per Claude's discretion
end
```

### Anti-Patterns to Avoid

- **Wrapping Anthropix behind our behaviour but then leaking Anthropic-shaped types into `Prompt.t()`/`Response.t()`.** The behaviour's reason for existing is to keep those shapes provider-neutral. Validate by making OpenAI/Google/Ollama adapters round-trip the *same* `Prompt.t()`.
- **Using `System.cmd("docker", ...)` without MuonTrap.** Port hygiene is load-bearing for crash safety on long-running `docker run` invocations. Banned per D-151 CLAUDE.md anti-pattern addition.
- **Mounting the host workspace (`-v /path:/workspace:rw`).** D-113 explicitly replaces this with tmpfs + CAS hydration. Host bind-mounts mean untrusted agent-generated code can `rm -rf` the repo.
- **Calling `reveal!/1` outside an adapter HTTP-boundary stack frame.** The grep audit that finds ~3 sites is a structural invariant. Every new `reveal!` site is a security review.
- **`PubSub.broadcast` on stream chunks in P3.** D-103 explicitly defers this to P7 where there is a LiveView consumer to calibrate backpressure policy against.
- **`git init/add/commit/push` inside the sandbox container.** Banned in D-113 — all git ops happen on the BEAM host against harvested CAS artifacts. Prevents P5 (sandbox escape) and P21 (secrets leaked to commit).
- **Custom `seccomp.json` profile in P3.** Rejected in D-118 — default + cap-drop=ALL covers the threat model; custom profiles are a tuning pit. Revisit only if adversarial suite finds a gap.
- **Re-matching on block reasons as new atoms are added at phase boundaries.** D-135 declares all 9 atoms in P3 so consumers pattern-match exhaustively from here forward. New atoms post-P3 would be breaking changes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Subprocess cleanup on BEAM crash | Custom Port + trap_exit + SIGKILL | **MuonTrap 1.7** | Nerves-maintained; C-binary parent-watch is exact primitive Kiln needs. ~500 LOC saved. |
| Docker CLI structured output parsing | `String.split` on `docker ps` output | **ex_docker_engine_api** for introspection only | JSON-over-Engine-API is stable; string-parsing breaks on Docker CLI version updates. D-120 OrphanSweeper uses this. |
| HTTP connection pooling across providers | Raw Finch or per-call TCP | **Req + named Finch pools per provider** (D-109) | 429-storm on Anthropic cannot starve OpenAI. |
| JSON Schema validation of DTU responses | Build partial validator | **JSV 0.18.1 Draft 2020-12** | Kiln already depends on JSV for workflow + audit schemas; 4th use site. |
| Anthropic API client | Direct Req for all Anthropic calls | **Anthropix 0.6.2** for chat + streaming + tool_use; **Direct Req only for `count_tokens`** (Anthropix gap) | Anthropix handles streaming + tool_use + extended thinking + prompt caching; rolling it costs weeks. |
| YAML parsing for `limits.yaml` | Regex | **yaml_elixir 2.12** | Already pinned; battle-tested. |
| Markdown frontmatter parsing for playbooks | Regex | Inline ~40 LOC (Claude's discretion) OR `:yaml_elixir` + pattern | Frontmatter is dead-simple `---\n<yaml>\n---\n<body>`. |
| Mustache `{var}` substitution in playbooks | Regex | Inline ~25 LOC OR `:bbmustache` | Trivially inline; dep only if planner estimates >30 LOC. |
| Circuit breaker sliding window (when P5 fills it) | Build circuit breaker | **`:fuse`** or **`:external_service`** | P3 ships no-op body; P5 picks library. |
| OpenAPI contract validation | Custom schema checker | **JSV** with bundled-dereferenced `github/rest-api-description` | Direct consumption of GitHub's own contract repo. |
| DTU HTTP server | GenServer-and-gen_tcp | **Bandit + Plug.Router** (standalone) | Minimum startup is `{Bandit, plug: MyApp.MyPlug}` per `[CITED: github.com/mtrudel/bandit]`. |
| DNS override inside DTU image | `/etc/hosts` tricks | **dnsmasq** baked into sidecar image | Resolves `api.github.com` + wildcard `*.github.com` → sidecar IP. LocalStack uses the same approach. |
| Desktop notification cross-platform | Shell-out by hand | `osascript` (macOS) + `notify-send` (Linux) wrapped in `Kiln.Notifications.desktop/2` | Native OS coalescing; ETS dedup layer is <50 LOC. |
| Structured JSON logs | logger_json alternatives | **logger_json 7.0.4** | Already pinned (P1); add `Kiln.Logging.SecretRedactor` impl. |

**Key insight:** Phase 3 adds muontrap as the SOLE new dep. Every other capability reuses pins from P1/P2 STACK.md. Custom solutions would regress the "no umbrella app, strict contexts, minimal deps" stance.

---

## Common Pitfalls

### Pitfall 1: Secret Leak via Unexpected Code Path

**What goes wrong:** Raw `"sk-ant-..."` string ends up in a log line, changeset error, or `docker inspect` output. SC #6 fails.

**Why it happens:**
- A struct field holds raw string instead of `%Kiln.Secrets.Ref{}` — Inspect derive is applied to Ref, not to the containing struct
- `Ecto.Changeset.cast/3` echoes submitted value on validation error (if field isn't `redact: true`)
- LoggerJSON metadata key named `:authorization` passes the raw header value to JSON serialization
- An env var is passed to `docker run` via `--env KEY=value` (not `--env-file` + allowlist)

**How to avoid:**
- 6-layer defense (D-133): type boundary + Inspect derive + Ecto `redact: true` + LoggerJSON.Redactor + Changeset `redact_fields` + docker-inspect negative test
- `Kiln.Sandboxes.EnvBuilder` ALLOWLIST (D-134): `~r/(api_key|secret|token|authorization|bearer)/i` on key NAME fails sandbox launch with `:sandbox_env_contains_secret`
- Grep audit for `reveal!` call sites in CI — ~3 expected (one per live adapter's HTTP call boundary); anomalies flagged for review
- Static check `mix check_no_sandbox_env_secrets` (optional per D-26 pattern; Claude's discretion whether to ship in P3)

**Warning signs:**
- `test/integration/secrets_never_leak_test.exs` (docker-inspect + Anthropix mock header assertion) fails
- Any struct in the app holds a field whose type is `String.t()` and whose name matches `api_key|token|secret`
- Log lines contain base64-ish content in metadata
- Crash dump contains raw provider-key-prefix strings

**Phase to address:** Phase 3 — structural invariants.

### Pitfall 2: Sandbox Escape Vector

**What goes wrong:** Untrusted agent-generated code escapes the container: exfiltrates data, modifies host, contacts public internet, escalates privileges.

**Why it happens:**
- `-v /var/run/docker.sock` mounted → container is root on host (explicitly banned CLAUDE.md + D-118)
- `--network` not `internal: true` → public DNS resolves, egress works
- IPv6 not disabled → `[2606:4700::]:443` routes out
- `--cap-add` SYS_ADMIN/NET_ADMIN/SYS_MODULE → kernel manipulation
- `--privileged` → all caps + devices exposed
- Running as root inside container + setuid binary → privilege escalation

**How to avoid:**
- `--cap-drop=ALL` (D-117; OWASP Container Rule #3; CIS 5.3) — verified: Elixir `mix compile/test/git-as-non-root` works with zero caps
- `--security-opt=no-new-privileges` (CIS 5.25) — blocks setuid escalation
- `--security-opt=seccomp=default` — Docker's default ~44-syscall profile `[CITED: docs.docker.com/engine/security/seccomp]`
- `--network kiln-sandbox` where `kiln-sandbox` is `internal: true` bridge (Layer 1 egress block)
- `--sysctl net.ipv6.conf.all.disable_ipv6=1` — belt-and-suspenders IPv6 kill per moby#20559
- `--dns <DTU_IP>` override — Docker embedded DNS only resolves bridge names (NXDOMAIN on public); DTU override is belt-and-suspenders for IP-literal paths
- `--read-only` + tmpfs for writable paths — immutable root FS
- `--user 1000:1000` non-root — baked into image
- Adversarial test suite verifies all 5 egress vectors fail (see `Adversarial Negative-Test Suite` below)

**Warning signs:**
- `test/kiln/sandboxes/egress_blocking_test.exs` fails on ANY vector
- `docker inspect <sandbox_id>` shows any capability, `NetworkMode != "kiln-sandbox"`, or `ReadonlyRootfs: false`
- OrphanSweeper finds containers with missing `kiln.boot_epoch` label (label-stripping attempt?)

**Phase to address:** Phase 3 — structural invariants.

### Pitfall 3: Silent Model Fallback (a.k.a. "we thought we were calling Opus")

**What goes wrong:** Workflow declares `coder: opus`; after 429s, ModelRegistry silently falls back to `haiku`; the stage completes "successfully" but the output is lower-quality; operator has no visibility until the cost-intel panel shows weird distribution.

**Why it happens:**
- Only `requested_model` is recorded; `actual_model_used` is missed
- Fallback happens in adapter internals without an audit event
- Tier-crossing (Opus → Haiku skipping Sonnet) is not differentiated from in-tier fallback

**How to avoid:**
- D-106: EVERY fallback attempt writes one `model_routing_fallback` audit event with full payload (requested, actual, reason, tier_crossed, attempt_number, provider_http_status, wall_clock_ms)
- Both `requested_model` AND `actual_model_used` written to `stage_runs` on every call (SC #1)
- `tier_crossing_alerts_on` preset field makes tier-crossing explicit per-preset; `tier_crossed: true` flag surfaces via audit (P3) + desktop notification (P7)
- Exhaustion → `model_routing_fallback_exhausted` → stage `:failed` with diagnostic artifact (prompt + errors + trace)

**Warning signs:**
- Audit ledger query `WHERE kind = 'model_routing_fallback' AND tier_crossed = true` returns unexpected rows
- Cost intel panel shows run totals deviating >2x from workflow-declared model's cost expectation
- `requested_model != actual_model_used` frequency exceeds expected rate-limit rate

**Phase to address:** Phase 3 — structural recording; Phase 7 — operator-visible notification.

### Pitfall 4: Cost Runaway (P2 from PITFALLS.md)

**What goes wrong:** Stuck retry loop burns thousands of dollars in tokens before operator notices.

**Why it happens:**
- Budget checked at run start only, not per-call
- Oban default `max_attempts: 20` + exponential backoff = hours of unsupervised spend
- Fallback to cheaper model masks the "this is looping" signal

**How to avoid (D-138):**
- BudgetGuard per-call PRE-FLIGHT (runs BEFORE every LLM call):
  1. Read `runs.caps_snapshot.max_tokens_usd`
  2. `SUM(stage_runs.tokens_used_usd) WHERE run_id = $1 AND state IN ('completed', 'failed')`
  3. `remaining_budget_usd = caps - spent`
  4. `Anthropix.count_tokens/1` (free Anthropic endpoint; separate rate limits from Messages API)
  5. `Kiln.Pricing.estimate_usd(model, input_tokens, estimated_output_tokens)`
  6. Compare `estimated_usd` vs `remaining_budget_usd`
  7. Emit `budget_check_passed` OR raise `:budget_exceeded` + emit `budget_check_failed`
- NO `KILN_BUDGET_OVERRIDE` escape hatch (D-138) — edit caps + restart run is the prescribed loop
- `Kiln.Policies.FactoryCircuitBreaker` scaffolded no-op in P3; P5 fills sliding-window body without schema migration (D-91 precedent)

**Warning signs:**
- Audit ledger: `budget_check_failed` without `budget_check_passed` preceding it in same stage_run
- Oban Web shows job `attempt > 3` on stage whose worker does LLM calls
- Single run USD spend > caps (should be unreachable)

**Phase to address:** Phase 3.

### Pitfall 5: DTU Drift (P6 from PITFALLS.md)

**What goes wrong:** GitHub changes API response shape; DTU mock keeps returning old shape; agent-generated code works in Kiln runs but fails against real GitHub.

**Why it happens:**
- Mock responses are hand-written with no validation
- No automated comparison between mock and real API
- Record-and-replay fixtures become stale silently

**How to avoid (D-122 + D-125):**
- JSV-validate every DTU response at send-time against pinned `priv/dtu/contracts/github/api.github.com.2026-04.json` (bundled-dereferenced from `github/rest-api-description`)
- `Kiln.Sandboxes.DTU.ContractTest` Oban worker (stubbed + unscheduled in P3; P6 toggles cron) runs weekly: fetch current schema from GitHub, diff against pinned, emit `dtu_contract_drift_detected` on mismatch
- Hand-written handlers (NOT OpenAPI-generated random-examples) so behavioral realism is preserved per StrongDM's SDK-compatibility target
- `HTTP 501` on unknown endpoint = fail loudly; NO echo-sink

**Warning signs:**
- `dtu_contract_drift_detected` audit events in ledger
- Integration tests flaky against DTU but pass against real GitHub (or vice-versa)
- New GitHub API endpoint used by workflow returns 501

**Phase to address:** Phase 3 (JSV scaffold) + Phase 6 (cron toggle).

### Pitfall 6: MuonTrap/cgroups gap on macOS

**What goes wrong:** Developer runs Kiln on Docker Desktop macOS; BEAM crashes mid-stage; Docker CLI subprocess is killed (port-close), but CONTAINER keeps running because Docker daemon doesn't know its client died.

**Why it happens:**
- cgroup-v2 containment is Linux-only
- macOS relies on port-close + SIGTERM to kill the docker CLI
- But `docker run` has already forked off a detached daemon-managed container; killing the CLI doesn't reach the container

**How to avoid (defense-in-depth per D-117 + D-120):**
- `docker run --rm` — container auto-removes on exit (first line)
- `docker run --init` — tini reaps zombies inside container
- `docker run --stop-timeout 10` — SIGTERM grace
- `Kiln.Sandboxes.OrphanSweeper` at boot — BootChecks 8th invariant; enumerates `kiln.boot_epoch != <current>` via `ex_docker_engine_api`, force-removes
- Audit event `orphan_container_swept` per removal

**Warning signs:**
- OrphanSweeper boot log shows non-zero sweep count in normal development
- `docker ps | grep kiln` shows zombie containers older than current BEAM epoch

**Phase to address:** Phase 3.

### Pitfall 7: Streaming deadlock (P7 precondition)

**What goes wrong:** Adapter streams 10,000 chunks; if a consumer (LiveView socket) can't keep up, the Enumerable materializes fully in BEAM memory, OOM kills the run's process.

**Why it happens:**
- LiveView has no built-in backpressure (Hex Shift article)
- `Phoenix.PubSub.broadcast` is fire-and-forget
- Stream chunk producer and consumer don't share a credit-based flow control
- Committing PubSub shape in P3 commits backpressure *policy* without a consumer to calibrate against

**How to avoid (D-103):**
- P3 ships `stream/2 → {:ok, Enumerable.t()}` PASSTHROUGH — NO PubSub, NO GenServer consumer
- Per-chunk telemetry only: `[:kiln, :agent, :stream, :chunk]`
- Phase 4 (work units) and Phase 7 (LiveView `stream_async/4`) each name their consumer shape
- The `langchain_elixir` `on_llm_new_delta` shape is our reference for P7 `[CITED: hexdocs.pm/langchain]`

**Warning signs:**
- P3 attempts to ship PubSub broadcast in adapter (architectural regression)
- BEAM heap grows unboundedly during a streaming stage

**Phase to address:** Phase 3 (defer) + Phase 7 (implement backpressure).

---

## Code Examples

### Secret reveal boundary (D-132)

```elixir
# lib/kiln/secrets.ex
defmodule Kiln.Secrets do
  defmodule Ref do
    @derive {Inspect, except: [:name]}
    defstruct [:name]
    @type t :: %__MODULE__{name: atom}
  end

  # Called ONLY from config/runtime.exs during boot.
  @spec put(atom, String.t()) :: :ok
  def put(name, value) when is_atom(name) and is_binary(value) do
    :persistent_term.put({__MODULE__, name}, value)
    :ok
  end

  # Returns the Ref — safe to cross function boundaries.
  @spec get!(atom) :: Ref.t()
  def get!(name) when is_atom(name) do
    unless present?(name) do
      raise Kiln.Blockers.Block, reason: :missing_api_key, context: %{name: name}
    end

    %Ref{name: name}
  end

  @spec present?(atom) :: boolean
  def present?(name), do: :persistent_term.get({__MODULE__, name}, nil) != nil

  # DANGER: returns the raw string. Only call inside an adapter HTTP-call stack frame.
  # Grep audit: total call sites should be ~3 (one per live provider adapter).
  @spec reveal!(atom | Ref.t()) :: String.t()
  def reveal!(%Ref{name: name}), do: reveal!(name)
  def reveal!(name) when is_atom(name) do
    case :persistent_term.get({__MODULE__, name}, nil) do
      nil -> raise Kiln.Blockers.Block, reason: :missing_api_key, context: %{name: name}
      value -> value
    end
  end
end

# Inside Kiln.Agents.Adapter.Anthropic:
def complete(prompt, opts) do
  api_key = Kiln.Secrets.reveal!(:anthropic_api_key)  # <-- ONE of ~3 call sites
  # api_key is in the function's local variable scope — never crosses a boundary
  client = Anthropix.init(api_key, receive_timeout: 120_000)
  # ... (api_key dies when this function returns)
end
```

### BudgetGuard 7-step pre-flight (D-138)

```elixir
defmodule Kiln.Agents.BudgetGuard do
  @spec check!(Kiln.Runs.Run.t(), Kiln.Agents.Prompt.t()) :: :ok | no_return
  def check!(%Kiln.Runs.Run{id: run_id, caps_snapshot: caps}, %Kiln.Agents.Prompt{} = prompt) do
    :telemetry.span([:kiln, :agents, :budget_guard, :check], %{run_id: run_id}, fn ->
      # Step 1: read cap
      max_usd = Decimal.new(caps.max_tokens_usd)

      # Step 2: sum spend to date
      spent_usd =
        Kiln.Repo.one(
          from sr in Kiln.Stages.StageRun,
            where: sr.run_id == ^run_id and sr.state in [:completed, :failed],
            select: coalesce(sum(sr.tokens_used_usd), 0)
        )

      # Step 3: compute remaining
      remaining = Decimal.sub(max_usd, spent_usd)

      # Step 4: pre-flight count_tokens (Anthropic free endpoint)
      adapter = prompt.adapter
      {:ok, input_tokens} = adapter.count_tokens(prompt)

      # Step 5: pricing estimate
      estimated_output = Kiln.Pricing.estimated_output_for(prompt.role)
      estimated_cost = Kiln.Pricing.estimate_usd(prompt.model, input_tokens, estimated_output)

      # Step 6: compare
      metadata = %{
        run_id: run_id,
        model: prompt.model,
        input_tokens: input_tokens,
        estimated_output_tokens: estimated_output,
        estimated_cost_usd: Decimal.to_string(estimated_cost),
        remaining_budget_usd: Decimal.to_string(remaining)
      }

      # Step 7: emit + return/raise
      if Decimal.lt?(estimated_cost, remaining) do
        Kiln.Audit.append!(%{kind: :budget_check_passed, payload: metadata})
        {:ok, metadata}
      else
        Kiln.Audit.append!(%{kind: :budget_check_failed, payload: metadata})
        raise Kiln.Blockers.Block,
          reason: :budget_exceeded,
          context: metadata
      end
    end)
  end
end
```

### Desktop notification dispatch (D-140)

```elixir
defmodule Kiln.Notifications do
  @dedup_ttl_ms 5 * 60 * 1000

  @spec desktop(Kiln.Blockers.RenderedPlaybook.t(), Keyword.t()) :: :ok
  def desktop(%Kiln.Blockers.RenderedPlaybook{} = pb, opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    reason = Keyword.fetch!(opts, :reason)
    dedup_key = {run_id, reason}

    if recently_fired?(dedup_key) do
      Kiln.Audit.append!(%{
        kind: :notification_suppressed,
        payload: %{reason: reason, run_id: run_id, dedup_key: inspect(dedup_key)}
      })
      :ok
    else
      remember_fired(dedup_key)

      case :os.type() do
        {:unix, :darwin} ->
          body = "Kiln — #{pb.severity}\n#{pb.short_message}\nrun: #{String.slice(run_id, 0..7)}"
          MuonTrap.cmd("osascript", ["-e", ~s|display notification "#{body}" with title "Kiln"|])

        {:unix, _linux} ->
          MuonTrap.cmd("notify-send", [
            "-u", "critical", "-c", "kiln",
            "-h", "string:x-canonical-private-synchronous:#{run_id}_#{reason}",
            "Kiln — #{pb.severity}",
            pb.short_message
          ])
      end

      Kiln.Audit.append!(%{
        kind: :notification_fired,
        payload: %{reason: reason, run_id: run_id, platform: :os.type() |> elem(1)}
      })

      :ok
    end
  end

  defp recently_fired?(key), do: # ETS lookup with TTL expiry
  defp remember_fired(key),  do: # ETS insert with timestamp
end
```

### Docker run command assembly (D-116 + D-117)

```elixir
defmodule Kiln.Sandboxes.DockerDriver do
  defp build_docker_run_args(%Kiln.Sandboxes.ContainerSpec{} = spec) do
    [
      "run", "--rm",
      "--network", spec.network,                                       # kiln-sandbox (internal: true)
      "--cap-drop=ALL",                                                # OWASP Rule #3
      "--security-opt", "no-new-privileges",                           # CIS 5.25
      "--security-opt", "seccomp=default",                             # Docker default ~44 syscalls blocked
      "--read-only",                                                   # immutable root FS
      "--tmpfs", "/tmp:rw,noexec,nosuid,size=#{spec.tmpfs_mounts[:tmp]}",
      "--tmpfs", "/workspace:rw,nosuid,size=#{spec.tmpfs_mounts[:workspace]}",
      "--tmpfs", "/home/kiln/.cache:rw,nosuid,size=#{spec.tmpfs_mounts[:cache]}",
      "--user", spec.user,                                             # 1000:1000
      "--memory=#{spec.limits.memory}",                                # e.g., 2g
      "--memory-swap=#{spec.limits.memory_swap}",                      # same as memory (no swap thrash)
      "--cpus=#{spec.limits.cpus}",                                    # e.g., 2
      "--pids-limit=#{spec.limits.pids_limit}",                        # fork-bomb defense
      "--ulimit", "nofile=#{spec.limits.ulimit_nofile}",               # e.g., 4096:8192
      "--ulimit", "nproc=#{spec.limits.ulimit_nproc}",                 # e.g., 256
      "--stop-timeout", Integer.to_string(spec.stop_timeout),
      "--label", "kiln.run_id=#{spec.labels.run_id}",
      "--label", "kiln.stage_run_id=#{spec.labels.stage_run_id}",
      "--label", "kiln.boot_epoch=#{spec.labels.boot_epoch}",
      "--label", "kiln.stage_kind=#{spec.labels.stage_kind}",
      "--env-file", spec.env_file_path,                                # allowlist-enforced
      "--hostname", "kiln-stage-#{String.slice(spec.labels.stage_run_id, 0..7)}",
      "--workdir", spec.workdir,                                       # /workspace
      "--init",                                                        # tini reaps zombies
      "--dns", spec.dns |> Enum.at(0),                                 # DTU IP
      "--add-host", "api.github.com:#{spec.dns |> Enum.at(0)}",        # IP-literal escape hatch
      "--sysctl", "net.ipv6.conf.all.disable_ipv6=1"                   # moby#20559
    ] ++ ["#{spec.image_ref}@#{spec.image_digest}"] ++ spec.cmd
  end
end
```

---

## DTU Mock Generation Pipeline

**Only public prior art:** StrongDM DTU ([Simon Willison writeup 2026-02](https://simonwillison.net/2026/Feb/7/software-factory/)).

### StrongDM's approach (what they published)

- **Generation:** Coding agents fed the full public API docs of target services; agents constructed self-contained Go binaries replicating the APIs. `[CITED: simonwillison.net/2026/Feb/7]`
- **Fidelity target:** "Use the top popular publicly available reference SDK client libraries as compatibility targets, with the goal always being 100% compatibility." (Jay Taylor, DTU creator) `[CITED: simonwillison.net/2026/Feb/7]`
- **Hosting:** Self-contained binaries with simplified UI overlays.
- **Chaos:** Mentioned benefit — "test failure modes that would be dangerous or impossible against live services" — but no concrete chaos-injection pattern published.

### Kiln's adaptation for P3 (D-121 .. D-128)

| StrongDM property | Kiln translation | Rationale |
|-------------------|------------------|-----------|
| Agent-generated Go binaries | Hand-written Elixir Plug handlers | Elixir-native; inspection + reuse of existing `Kiln.GitHub` tooling; CLAUDE.md "No application code had been written yet" rules out agent self-authoring in P3 |
| SDK compatibility as fidelity target | JSV Draft 2020-12 validation at response-send time against pinned `priv/dtu/contracts/github/api.github.com.2026-04.json` | Schema validation is the mechanical form of "SDK compatibility" for a typed API |
| Self-contained binary | Docker Compose sidecar service on `kiln-sandbox` bridge at static IP `172.28.0.10` | BEAM-hosted DTU is impossible — would defeat `internal: true` egress block |
| Simplified UI overlay | (N/A for v1 — skip) | No operator needs to "see" DTU state in P3; JSONL log + audit ledger are the debug surface |
| Chaos: mentioned benefit | `X-DTU-Chaos: rate_limit_429` + `X-DTU-Chaos: outage_503` (P3); `timeout_30s`, `slow_5s`, `malformed_json`, `schema_drift` reserved for P5 | OPS-02 adaptive-routing tests need 429 + 503 in P3; full chaos taxonomy is P5's concern |
| Record-and-replay (ExVCR-style) | **REJECTED** — PAT leak risk into fixtures violates SEC-01 | D-122 rejection |
| Prism / OpenAPI-server-stub | **REJECTED** — random-examples fail SDK round-trip fidelity; server-stub tooling alpha-only for Elixir | D-122 rejection |

### Contract-test harness design (for Phase 6 cron toggle)

```elixir
# priv/dtu/lib/kiln_dtu/... is the DTU app; this worker lives in Kiln.
defmodule Kiln.Sandboxes.DTU.ContractTest do
  use Oban.Worker, queue: :dtu, max_attempts: 1

  @impl true
  def perform(%Oban.Job{args: %{"endpoints" => endpoints}}) do
    # P3: stub body. Body filled in P6.
    # P6 implementation shape:
    #   1. Fetch current GitHub OpenAPI schema via `gh api /` or direct curl
    #   2. Diff against priv/dtu/contracts/github/api.github.com.2026-04.json
    #   3. For each endpoint, emit `dtu_contract_drift_detected` if response
    #      schema differs in backward-incompatible way
    #   4. Emit weekly summary audit event
    :ok
  end
end

# Contract regeneration Mix task (P3 ships this):
defmodule Mix.Tasks.Kiln.Dtu.RegenContract do
  @moduledoc """
  Re-bundles the GitHub REST API OpenAPI description into a self-contained JSON
  schema Kiln validates DTU responses against. Run when GitHub publishes a new
  OpenAPI description version.
  """
  use Mix.Task

  def run(_args) do
    # 1. Pull github/rest-api-description @ current ref
    # 2. Bundle + dereference via JSV-compatible OpenAPI → JSON Schema tool
    # 3. Write to priv/dtu/contracts/github/api.github.com.<YYYY-MM>.json
    # 4. Emit diff summary for operator review
  end
end
```

**Handler coverage in P3:** `issues.ex`, `pulls.ex`, `checks.ex`, `contents.ex`, `branches.ex`, `tags.ex` — 6 endpoint families, ~6-10 total handlers that the stage-execution path actually touches. Claude's discretion on exact split.

**Confidence:** **MEDIUM** — only one public DTU prior art exists; Kiln's adaptation is sound but will need empirical tuning during P9 dogfood when real workflows exercise more GitHub endpoints.

---

## SSE Streaming → PubSub → LiveView Backpressure

### The challenge (P7's problem, scoped in P3)

LiveView has **no built-in backpressure**. A producer (LLM streaming chunks at token-level rate) and a consumer (LiveView socket) without credit-based flow control means the Enumerable materializes fully in BEAM memory → OOM.

Explicit backpressure can take many forms `[CITED: hexshift.medium.com/websocket-backpressure-in-phoenix-liveview]`:
- Rejecting events when busy
- Ignoring events that arrive too quickly
- Coalescing multiple events into one state update
- Delaying non-critical work

### P3's decision: NO PubSub, NO consumer shape committed

Per **D-103**, P3 ships `stream/2 → {:ok, Enumerable.t()}` as a passthrough wrapping Anthropix's lazy Enumerable, with `Stream.each` emitting per-chunk telemetry:

```elixir
def stream(%Kiln.Agents.Prompt{} = prompt, opts) do
  api_key = Kiln.Secrets.reveal!(:anthropic_api_key)
  client = Anthropix.init(api_key, receive_timeout: 120_000)

  {:ok, anthropix_stream} =
    Anthropix.chat(client, Keyword.merge(prompt_to_keyword(prompt, opts), stream: true))

  start_time = System.monotonic_time(:millisecond)
  run_id = opts[:run_id]
  stage_id = opts[:stage_id]
  actual_model = opts[:actual_model_used]

  instrumented_stream =
    Stream.each(anthropix_stream, fn chunk ->
      :telemetry.execute(
        [:kiln, :agent, :stream, :chunk],
        %{byte_size: byte_size(inspect(chunk)), elapsed_since_start: System.monotonic_time(:millisecond) - start_time},
        %{run_id: run_id, stage_id: stage_id, actual_model_used: actual_model}
      )
    end)

  {:ok, instrumented_stream}
end
```

**Rationale:** Committing PubSub topology now commits backpressure POLICY without a consumer to calibrate against. The consumer shapes are:
- **Phase 4 (work units):** Chunks may accumulate into a `work_unit_events` append-only ledger entry at coarser granularity — backpressure = coalescing.
- **Phase 7 (LiveView):** `stream_async/4` (LiveView 1.1) is the idiomatic consumer; backpressure = LiveView socket flow + explicit coalescing per `[CITED: hexshift.medium.com]`.

### P3's responsibility envelope

| Concern | P3 ships | P4/P7 fills |
|---------|----------|-------------|
| Adapter stream shape | `{:ok, Enumerable.t()}` passthrough | (unchanged) |
| Chunk-level telemetry | `[:kiln, :agent, :stream, :chunk]` | (consumed by LiveView hooks in P7) |
| Work-unit accumulation | (not in scope) | P4 work units |
| LiveView update flow | (not in scope) | P7 `stream_async/4` |
| Backpressure policy | **explicitly deferred** | P4 coalescing + P7 socket flow |

**Reference implementations to study (for P7):**
- `langchain_elixir`'s `on_llm_new_delta` callback shape — canonical Elixir LLM-streaming consumer contract `[CITED: hexdocs.pm/langchain]`
- LiveView 1.1 `stream_async/4` — async streaming into LiveView streams `[CITED: hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]`
- Hex Shift article — backpressure patterns catalog `[CITED: hexshift.medium.com/websocket-backpressure-in-phoenix-liveview]`

**Confidence:** **MEDIUM-HIGH** for the P3 deferral rationale (source-grounded); **N/A** for the P7 implementation (not P3's concern).

---

## Sandbox Resource Limits (Concrete Values)

### Starter values (D-112 — validated; planner tunes during Phase 3 execution)

| Stage kind | `--memory` | `--memory-swap` | `--cpus` | `--pids-limit` | `--ulimit nofile` | `--ulimit nproc` | tmpfs /workspace | tmpfs /tmp | tmpfs /.cache |
|------------|-----------|-----------------|----------|----------------|-------------------|------------------|------------------|------------|---------------|
| **Default** (planning, verifying) | `768m` | `768m` | `1` | `256` | `4096:8192` | `128` | `512m` | `128m` | `256m` |
| **Coding / Testing / Merge** | `2g` | `2g` | `2` | `512` | `4096:8192` | `256` | `1024m` | `256m` | `512m` |

### Sources + rationale

| Value | Source | Rationale |
|-------|--------|-----------|
| `--memory=2g` (coding/testing) | `[CITED: elixirforum.com/t/57251]` — "Starting an Elixir/Erlang container can take up 2GB of physical memory" | BEAM + mix compile at startup is the worst case; 2GB avoids OOM during first compile |
| `--memory=768m` (planning/verifying) | Empirical Phoenix baseline (Elixir best practices) | Pure LLM-call + CAS I/O workload; no mix compile; 768MB generous |
| `--memory-swap=<same>` | D-117 | Hard cap, no swap thrash — prevents "container appears to work but swaps to death" |
| `--cpus=2` (coding) | CIS Docker Benchmark §5.11 | Reasonable ceiling for test parallelism; BEAM can use both schedulers |
| `--cpus=1` (planning) | CIS Docker Benchmark §5.11 | Planner/verifier are IO-bound on LLM calls |
| `--pids-limit=512` (coding) | CIS Docker Benchmark §5.28 — "Ensure container PIDs cgroup limit is used" | Fork-bomb defense; BEAM spawns many schedulers + processes; 512 covers test runs spawning processes |
| `--pids-limit=256` (planning) | Same | Half of coding; planning stages don't spawn subprocesses |
| `--ulimit nofile=4096:8192` | `[CITED: github.com/elixir-lang/elixir/issues/2571]` — "high nofile causes mix slowdown" | High nofile (65535 default) slows mix; cap at 4096:8192 |
| `--ulimit nproc=256` (coding) | CIS Docker Benchmark §5.11 | Per-user process limit; must accommodate BEAM schedulers + test processes |
| tmpfs sizes | D-112 | Fits test compile output + workspace artifacts; auto-scrubs secrets on container exit (P21 defense) |

### CIS Docker Benchmark mapping

| CIS control | Kiln flag | 
|-------------|-----------|
| 5.3 Restrict Linux Kernel Capabilities | `--cap-drop=ALL` |
| 5.9 Ensure the host's network namespace is not shared | `--network kiln-sandbox` (internal bridge) |
| 5.10 Limit memory usage for container | `--memory=<K> --memory-swap=<same>` |
| 5.11 Set container CPU priority appropriately | `--cpus=<K>` |
| 5.12 Mount container's root filesystem as read only | `--read-only` |
| 5.24 Ensure that the default seccomp profile is not disabled | `--security-opt=seccomp=default` |
| 5.25 Ensure that the container is restricted from acquiring additional privileges | `--security-opt=no-new-privileges` |
| 5.28 Ensure that the PIDs cgroup limit is used | `--pids-limit=<K>` |

`[CITED: cisecurity.org/benchmark/docker, oneuptime.com/blog/2026-02-08-how-to-use-docker-bench-security]`

### Planner action during Phase 3 execution

**Required:** measure BEAM baseline inside `hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21` running representative `mix compile + mix test` workload; if measured RSS > 1.5GB consistently, bump `--memory=2g` to `--memory=3g` and re-evaluate `--cpus`.

**Confidence:** **HIGH** for policy shape + CIS-grounded values; **MEDIUM** for exact numbers — they're sound starting points but Phase 3 execution should validate via live measurement against the real Phoenix/Oban compile workload.

---

## Structured Output Enforcement Per Provider

**D-104 Facade:** `Kiln.Agents.StructuredOutput.request(schema, adapter: atom, model: binary, prompt: Prompt.t())` dispatches to each provider's native mode. JSV Draft 2020-12 validation is applied post-call as defense-in-depth regardless of provider.

### Anthropic (PRIMARY path — 2026 native structured outputs)

**Update to CONTEXT D-104:** Anthropic launched native `output_config.format.json_schema` in 2026, and it is the **preferred** approach over `tool_use` hijacking. `[VERIFIED: platform.claude.com/docs/en/api/messages-count-tokens (output_config appears in request body docs); CITED: platform.claude.com/docs/en/build-with-claude/structured-outputs]`

```elixir
# Source: platform.claude.com/docs/en/build-with-claude/structured-outputs (2026)
# Adapter.Anthropic — new primary path
Req.post("https://api.anthropic.com/v1/messages",
  finch: Kiln.Finch.Anthropic,
  headers: auth_headers(),
  json: %{
    model: "claude-sonnet-4-5",
    max_tokens: 4096,
    messages: messages,
    # NEW in 2026: native structured output
    output_config: %{
      format: %{
        type: "json_schema",
        schema: json_schema_map
      }
    }
  }
)
# Response content is guaranteed-valid JSON in response.content[0].text
```

**Fallback (if 2026 endpoint returns 4xx for unsupported model):** use `tool_use` with `strict: true` per Anthropix 0.6.2 today.

### OpenAI

```elixir
# Adapter.OpenAI — per OpenAI docs for response_format
Req.post("https://api.openai.com/v1/chat/completions",
  finch: Kiln.Finch.OpenAI,
  json: %{
    model: "gpt-5",
    messages: messages,
    response_format: %{
      type: "json_schema",
      json_schema: %{
        name: "kiln_response",
        strict: true,
        schema: json_schema_map
      }
    }
  }
)
```

### Google (Gemini)

```elixir
# Adapter.Google — function_calling / responseSchema pattern
Req.post("https://generativelanguage.googleapis.com/v1/models/gemini-2.5-pro:generateContent",
  finch: Kiln.Finch.Google,
  json: %{
    contents: contents,
    generationConfig: %{
      responseMimeType: "application/json",
      responseSchema: json_schema_map
    }
  }
)
```

### Ollama

```elixir
# Adapter.Ollama — capabilities().json_schema_mode == false for most models
# → falls back to prompted JSON + JSV post-validation + 1 retry per D-104
Req.post("#{ollama_url}/api/chat",
  finch: Kiln.Finch.Ollama,
  json: %{
    model: "llama3.1:8b",
    messages: messages,
    format: "json",          # Ollama's JSON mode (best-effort)
    stream: false
  }
)
# After response: JSV.validate!(json_schema, parsed_body); on failure, retry once.
```

### Industry consensus

- "Native modes cut error rates 15% → 3%" vs prompted-JSON per `[CITED: mastra.ai/blog/mcp-tool-compatibility-layer]`
- "Structured output is strictly better — the moment OpenAI and Anthropic shipped constrained decoding, the old JSON mode became a footnote." `[CITED: Towards Data Science 2026]`
- Combining `tool_use` with `output_config` is valid — tools get guaranteed-valid parameters AND final response is structured `[CITED: platform.claude.com/docs/en/build-with-claude/structured-outputs]`

**Confidence:** **HIGH** for Anthropic (native mode verified in 2026 API docs); **HIGH** for OpenAI (response_format is GA); **MEDIUM** for Google (API evolves quarterly); **MEDIUM** for Ollama (model-dependent). The `json_schema_mode` adapter capability flag is the load-bearing switch — set it honestly per-model and StructuredOutput facade picks the right branch.

---

## Adversarial Negative-Test Suite

Per D-119, the adversarial suite `test/kiln/sandboxes/egress_blocking_test.exs` verifies all 5 egress vectors fail inside a production-hardened sandbox container. Plus the positive test that DTU reachability succeeds.

### Required test cases (MUST all PASS in CI)

| # | Test | Command inside sandbox | Expected outcome |
|---|------|------------------------|-------------------|
| 1 | TCP egress to public IP | `curl -m 5 --connect-timeout 3 https://1.1.1.1` | FAIL — `Could not resolve host` OR `Couldn't connect` (bridge has no external gateway) |
| 2 | UDP egress | `nc -u -w 3 8.8.8.8 53 < /dev/null; echo $?` | FAIL — non-zero exit (no UDP route out) |
| 3 | DNS public name | `getent hosts google.com; echo $?` | FAIL — non-zero exit (DNS resolves only `kiln-sandbox` bridge + DTU override) |
| 4 | ICMP | `ping -c 1 -W 3 8.8.8.8; echo $?` | FAIL — non-zero exit (ICMP dropped by bridge) |
| 5 | IPv6 | `curl -m 5 -6 "https://[2606:4700::]:443"; echo $?` | FAIL — IPv6 disabled per-container via `--sysctl net.ipv6.conf.all.disable_ipv6=1` |
| 6 | **Positive:** DTU reachability | `curl -m 5 https://api.github.com/` | PASS — response from DTU at 172.28.0.10 (via dnsmasq + `--add-host`) |

### Secondary test cases (SEC-01 docker-inspect negative assertion)

Per SC #6, `test/integration/secrets_never_leak_test.exs` spawns a real stage container and asserts:

| # | Assertion | Method |
|---|-----------|--------|
| 1 | `docker inspect --format '{{json .Config.Env}}' <id>` contains NO env var whose NAME matches `~r/(api_key\|secret\|token\|authorization\|bearer)/i` | JSON parse + regex |
| 2 | `docker inspect ... Env` contains NO value matching known provider-secret prefixes (`sk-ant-`, `sk-proj-`, `ghp_`, `gho_`, `AIza`) | JSON parse + regex |
| 3 | Anthropix mock saw `Authorization: Bearer ...` header at the wire (proving secret reached HTTP call) | Mox capture + header inspection |
| 4 | Adapter GenServer state during emission holds `%Kiln.Secrets.Ref{}` not raw string | `:telemetry` handler trap on `[:kiln, :agent, :request, :start]` metadata inspection |
| 5 | Audit ledger for the run contains NO payload field with raw-secret-shaped value | SQL scan `audit_events WHERE payload::text ~ 'sk-(ant|proj)-'` — expect 0 rows |
| 6 | `/workspace` tmpfs after stage exit contains NO file with secret-shaped content | (inherent — tmpfs auto-scrubs on container exit) |

### CapDrop / privilege-escalation negative tests

| # | Test | Expected |
|---|------|----------|
| 7 | `docker inspect --format '{{.HostConfig.CapAdd}}' <id>` | `[]` — empty |
| 8 | `docker inspect --format '{{.HostConfig.CapDrop}}' <id>` | Contains `ALL` |
| 9 | `docker inspect --format '{{.HostConfig.SecurityOpt}}' <id>` | Contains `no-new-privileges`, `seccomp=default` |
| 10 | `docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' <id>` | `true` |
| 11 | `docker inspect --format '{{.Config.User}}' <id>` | `1000:1000` (non-root) |
| 12 | `docker inspect --format '{{.HostConfig.PidsLimit}}' <id>` | Matches limits.yaml value for that stage kind |
| 13 | `mount \| grep /var/run/docker.sock` (inside container) | FAIL — no output (socket NOT mounted; CLAUDE.md forbids) |

### Orphan-sweep test

| # | Test | Expected |
|---|------|----------|
| 14 | After BEAM restart, OrphanSweeper enumerates containers with `kiln.boot_epoch != current` | All prior-boot containers force-removed; `orphan_container_swept` audit event per |

**Confidence:** **HIGH** — every test case maps to a specific D-117 flag or D-119 DNS layer or D-133 redaction layer; test implementation is mechanical.

---

## Runtime State Inventory

Phase 3 is **greenfield** for its scope — it adds new contexts (`Kiln.Agents`, `Kiln.Sandboxes`, `Kiln.Secrets`, `Kiln.Blockers`, `Kiln.Notifications`, `Kiln.ModelRegistry`, `Kiln.Pricing`, `Kiln.Policies.FactoryCircuitBreaker`) and extends three existing ones (`Kiln.Stages.StageWorker` gets NextStageDispatcher hook; `Kiln.Audit.EventKind` extends 25 → 30; `Kiln.BootChecks` extends 6 → 8). No rename/refactor/migration. No orphan state to clean up.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — zero new tables in P3. All new state lives in compile-time registries or `persistent_term`. Audit ledger gets 5 new kinds + matching schemas. | None (only audit schema additions, which are pure source additions). |
| Live service config | Docker Compose — new `dtu` service with static IP 172.28.0.10 on `kiln-sandbox` IPAM-declared subnet (subnet `172.28.0.0/24`). The `sandbox-net-anchor` service from Phase 1 CONTEXT.md retains its role for adversarial tests. | Add `dtu` service to `compose.yaml`; declare subnet range. |
| OS-registered state | None — P3 does not register any OS daemons, scheduled tasks, or systemd units. MuonTrap-wrapped `docker run` is subprocess-scoped, lifecycle tied to BEAM. | None. |
| Secrets/env vars | New provider keys: `ANTHROPIC_API_KEY` (required in prod), `OPENAI_API_KEY` (optional P3), `GOOGLE_API_KEY` (optional P3), `OLLAMA_URL` (optional P3). Handled by `config/runtime.exs` reading env → `Kiln.Secrets.put/2`. | Add to `.env.example`; document in README per Phase 8 onboarding wizard; zero new secret *references* required. |
| Build artifacts | `kiln/sandbox-elixir:<digest>` Docker image rebuilt idempotently via `mix kiln.sandbox.build` (reads `priv/sandbox/elixir.Dockerfile`, writes digest to `priv/sandbox/images.lock`). `kiln/dtu:<git-sha>` DTU image. | `mix kiln.sandbox.build` on first setup + when `elixir.Dockerfile` changes; `docker compose build dtu` for DTU. |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker CLI | `MuonTrap.cmd("docker", ...)` in DockerDriver | Must be available (P3 blocker if missing) | 24+ (Docker Desktop macOS / Docker Engine Linux) | None — P3 cannot ship without Docker. BootChecks 8th invariant fails fatally if `docker ps` is unreachable. |
| Docker Engine API socket (read access) | `ex_docker_engine_api` for OrphanSweeper introspection | Must be available | API v1.43+ | None — socket read-only access is required for orphan enumeration |
| `osascript` (macOS) | `Kiln.Notifications.desktop/2` on dev | Available on macOS (ships with OS) | System | `notify-send` (Linux), text log fallback (dev-only) |
| `notify-send` (Linux) | `Kiln.Notifications.desktop/2` on Linux | Package `libnotify-bin` | System | `osascript` (macOS), text log fallback |
| Anthropic API access | Live adapter tests `@tag :live_anthropic` | Requires `ANTHROPIC_API_KEY` | API v2023-06-01 | Mox fake used by default; live tests skip when key absent |
| Elixir/OTP in sandbox base image | `hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21` for stage containers | Pullable from Docker Hub | Pinned via digest in `priv/sandbox/images.lock` | None — required for Elixir dogfood |
| GitHub REST OpenAPI description | `mix kiln.dtu.regen_contract` task | Fetch from `github/rest-api-description` public repo | 2026-04 snapshot pinned | None for P3 (contract is bundled-in) |

**Missing dependencies with no fallback:** Docker CLI + Engine API socket — BootChecks 8th invariant halts app startup if absent.

**Missing dependencies with fallback:** Anthropic API key (dev/test run with Mox; live tests skip); `notify-send` on Linux (dev-only impact; test path uses capture).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19 stdlib) + LiveViewTest (P7 unused here) + Mox 1.2 + StreamData 1.3 + testcontainers 1.13 |
| Config file | `test/test_helper.exs` (P1-shipped) |
| Quick run command | `mix test --max-failures=1 --color` |
| Full suite command | `mix test && mix check` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AGENT-01 | Adapter behaviour compiles & contract tests pass for all 4 providers | unit (contract) | `mix test test/kiln/agents/adapter_anthropic_test.exs test/kiln/agents/adapter_openai_test.exs test/kiln/agents/adapter_google_test.exs test/kiln/agents/adapter_ollama_test.exs` | ❌ Wave 0 |
| AGENT-02 | ModelRegistry resolves presets → role → model | unit | `mix test test/kiln/model_registry_test.exs` | ❌ Wave 0 |
| AGENT-05 | Telemetry emits `[:kiln, :agent, :call, :stop]` with `requested_model` + `actual_model_used` | unit (telemetry handler) | `mix test test/kiln/agents/telemetry_test.exs` | ❌ Wave 0 |
| SAND-01 | Container created and `--rm`'d on successful stage; OrphanSweeper reaps on crash | integration (docker) | `mix test test/kiln/sandboxes/docker_driver_test.exs --only docker` | ❌ Wave 0 |
| SAND-02 | All 5 egress vectors blocked; DTU reachable | integration (docker adversarial) | `mix test test/kiln/sandboxes/egress_blocking_test.exs --only docker` | ❌ Wave 0 |
| SAND-03 | DTU returns validated responses; chaos headers trigger; unknown → 501 | integration (docker) | `mix test test/kiln/sandboxes/dtu/router_test.exs` | ❌ Wave 0 |
| SAND-04 | Hydrator + Harvester round-trip `/workspace/out` → CAS | integration | `mix test test/kiln/sandboxes/harvester_test.exs test/kiln/sandboxes/hydrator_test.exs` | ❌ Wave 0 |
| SEC-01 | `docker inspect` sees no secret-shaped env; Anthropix mock sees auth header; adapter state holds Ref not string | integration (docker) | `mix test test/integration/secrets_never_leak_test.exs --only docker` | ❌ Wave 0 |
| BLOCK-01 | PlaybookRegistry compile-time load + render with context | unit | `mix test test/kiln/blockers/playbook_registry_test.exs` | ❌ Wave 0 |
| BLOCK-03 | `Kiln.Notifications.desktop/2` shells out and deduplicates | unit (with `MuonTrap.cmd` mock) | `mix test test/kiln/notifications_test.exs` | ❌ Wave 0 |
| OPS-02 | Fallback triggers correctly on 429; `actual_model_used` differs from `requested_model` | unit (DTU 429 chaos) | `mix test test/kiln/agents/fallback_test.exs --only docker` | ❌ Wave 0 |
| OPS-03 | All 6 presets load and resolve every role | unit | `mix test test/kiln/model_registry/presets_test.exs` | ❌ Wave 0 |
| — | FactoryCircuitBreaker supervised & no-op returns :ok | unit | `mix test test/kiln/policies/factory_circuit_breaker_test.exs` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test --max-failures=1 --color --exclude docker` (Dockerless quick suite; <30s expected)
- **Per wave merge:** `mix test && mix check` (full suite including docker integration tests; ~5 min expected)
- **Phase gate:** Full suite green + adversarial egress_blocking suite green + secrets_never_leak suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/kiln/agents/adapter_anthropic_test.exs` — Mox contract + `@tag :live_anthropic` gate
- [ ] `test/kiln/agents/adapter_openai_test.exs` — Mox contract + `@tag :live_openai`
- [ ] `test/kiln/agents/adapter_google_test.exs` — Mox contract + `@tag :live_google`
- [ ] `test/kiln/agents/adapter_ollama_test.exs` — Mox contract + `@tag :live_ollama`
- [ ] `test/kiln/agents/telemetry_test.exs` — telemetry handler asserts on event metadata
- [ ] `test/kiln/agents/fallback_test.exs` — ModelRegistry.next/2 chain + audit event
- [ ] `test/kiln/agents/budget_guard_test.exs` — 7-step check; raise path + pass path
- [ ] `test/kiln/agents/structured_output_test.exs` — per-provider native dispatch + JSV validation
- [ ] `test/kiln/model_registry_test.exs` — resolve + override matrix
- [ ] `test/kiln/model_registry/presets_test.exs` — all 6 presets parse + validate
- [ ] `test/kiln/pricing_test.exs` — estimate_usd/3 per provider
- [ ] `test/kiln/sandboxes/docker_driver_test.exs` — real `docker run` with all hardened flags
- [ ] `test/kiln/sandboxes/egress_blocking_test.exs` — **adversarial 6 vectors**
- [ ] `test/kiln/sandboxes/hydrator_test.exs` — CAS → tmpfs round-trip
- [ ] `test/kiln/sandboxes/harvester_test.exs` — tmpfs → CAS + audit event round-trip
- [ ] `test/kiln/sandboxes/env_builder_test.exs` — allowlist enforcement + regex denial
- [ ] `test/kiln/sandboxes/orphan_sweeper_test.exs` — prior-boot-epoch containers swept
- [ ] `test/kiln/sandboxes/dtu/router_test.exs` — 6+ GitHub handlers + JSV validation + chaos headers + 501 on unknown
- [ ] `test/kiln/sandboxes/dtu/health_poll_test.exs` — 3-consecutive-miss broadcast
- [ ] `test/kiln/secrets_test.exs` — put/get!/reveal!/present? with Inspect assertion
- [ ] `test/kiln/blockers_test.exs` — raise_block flow + audit event
- [ ] `test/kiln/blockers/playbook_registry_test.exs` — compile-time load + render + Mustache
- [ ] `test/kiln/notifications_test.exs` — MuonTrap mock + ETS dedup
- [ ] `test/kiln/policies/factory_circuit_breaker_test.exs` — no-op body + tree presence
- [ ] `test/integration/secrets_never_leak_test.exs` — **docker-inspect negative assertion (SEC-01 SC #6)**
- [ ] `test/integration/stage_end_to_end_test.exs` — full stage: Hydrate → DockerDriver.run_stage → Adapter.complete → Harvest → NextStageDispatcher
- [ ] `test/support/docker_helper.ex` — helpers for live-docker tests (skip if Docker absent)
- [ ] Mox definitions in `test/test_helper.exs`: `Kiln.Agents.MockAdapter`, `Kiln.Sandboxes.MockDriver`

**Total: ~28 test files + supporting fixtures.**

*(No existing test infrastructure covers these — Wave 0 must establish it all.)*

---

## Security Domain

`security_enforcement: true` + ASVS Level 1 + block_on: high (from `.planning/config.json`).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | API keys to LLM providers handled via `Kiln.Secrets` (references only). No end-user auth in P3 (that's Phase 7 LiveView). |
| V3 Session Management | no | No user sessions in P3 scope. |
| V4 Access Control | yes | Sandbox non-root user (1000:1000), cap-drop=ALL, read-only FS, seccomp default — enforces least privilege on agent-generated code. |
| V5 Input Validation | yes | **JSV Draft 2020-12** on DTU response send + on LLM structured output responses (defense-in-depth). Workflow YAML + audit events already validated (P1/P2). |
| V6 Cryptography | yes | Secrets never hand-encrypted; `persistent_term` is the store; TLS via Finch (battle-tested). |
| V7 Error Handling & Logging | yes | 6-layer redaction (D-133) ensures no secret leakage through error paths + structured logging (logger_json). |
| V10 Malicious Code | **YES — HIGH risk** | Untrusted LLM-generated code executes in sandbox. `--cap-drop=ALL`, `no-new-privileges`, `seccomp=default`, `--network internal`, `--read-only`, non-root user, DNS override, IPv6 kill — all defense-in-depth layers. |
| V11 Business Logic | yes | Budget pre-flight prevents runaway cost-exploit. |
| V14 Configuration | yes | Hardened Docker option set enforced by `ContainerSpec` struct — not ad-hoc. Env allowlist prevents secret leakage through config. |

### Known Threat Patterns for Kiln's P3 stack

| Pattern | STRIDE | Standard Mitigation | P3 Status |
|---------|--------|---------------------|-----------|
| Sandbox escape via Docker socket mount | E (Elevation) | Never mount `/var/run/docker.sock` | CLAUDE.md + D-118 FORBID; test 13 asserts no socket in container |
| Sandbox escape via capability abuse | E | `--cap-drop=ALL` + `no-new-privileges` | D-117; tests 7-9 assert |
| Sandbox escape via seccomp gap | E | Docker default seccomp profile (~44 syscalls blocked) | D-117; test 9 asserts |
| Container-level privilege escalation | E | `--user 1000:1000`, read-only root FS | D-117; tests 10, 11 assert |
| Network egress (data exfiltration) | I (Info Disclosure) | 5-layer DNS/bridge/IPv6 block | D-119; adversarial suite tests 1-5 assert |
| Fork-bomb DoS inside sandbox | D (Denial of Service) | `--pids-limit=N` | D-117; test 12 asserts |
| Memory exhaustion DoS | D | `--memory=K --memory-swap=same` | D-117 |
| Secret leak via env var | I | Env allowlist (D-134) + name-regex denial | Test file `test/kiln/sandboxes/env_builder_test.exs` |
| Secret leak via log line | I | 6-layer redaction (D-133) | `test/integration/secrets_never_leak_test.exs` |
| Secret leak via crash dump | I | `@derive {Inspect, except: [...]}` on Ref + adapter structs | Type system enforcement |
| Secret leak via changeset error | I | `Ecto.Changeset.redact_fields/2` | D-133 Layer 5 |
| Secret leak to workspace | I | Tmpfs auto-scrubs on exit; `--read-only` root FS | D-117; test 6 asserts |
| Cost-runaway via stuck retry | D / E | BudgetGuard per-call pre-flight; Oban `max_attempts: 3` | D-138; test `budget_guard_test.exs` |
| DTU drift (false positive sandbox behavior) | Spoofing | JSV Draft 2020-12 response-send validation + weekly contract test | D-122, D-125 |
| LLM-generated code attempts shell escape | T (Tampering) | Sandbox isolation (above stack) | All D-117 flags |
| Prompt injection → tool call abuse | T | Typed tool allowlist (groundwork P3; full enforcement P4) | `tools: []` default in Prompt.t() |
| Model silently downgraded (tier-crossing fallback) | Repudiation | `requested_model` + `actual_model_used` both recorded; `tier_crossed` audit flag | D-106 |

**Confidence:** **HIGH** — every mitigation maps to a specific decision + test; threat model is stack-specific (Elixir + Docker-CLI + LLM adapters).

---

## Project Constraints (from CLAUDE.md)

- **Postgres is source of truth.** All P3 new state lives either in `persistent_term` (secrets — write-once at boot) or compile-time registries (playbooks, model presets, pricing). No new DB tables in P3; BudgetGuard reads from existing `runs.caps_snapshot` + `stage_runs.tokens_used_usd`.
- **Append-only audit ledger is non-negotiable.** 5 new `EventKind` values in P3 (orphan_container_swept, dtu_contract_drift_detected, dtu_health_degraded, factory_circuit_opened/closed, model_deprecated_resolved, notification_fired/suppressed); each gets a JSV schema under `priv/audit_schemas/v1/`. Writes go through `Kiln.Audit.append!/1` inside transactions.
- **Idempotency everywhere.** NextStageDispatcher uses canonical idempotency key `run:<run_id>:stage:<stage_id>` (D-70, D-144). Every `docker run` is paired with `external_operations.docker_run` intent row (kind declared P1 D-17; first writer in P3).
- **No Docker socket mounts.** D-118 + CLAUDE.md forbid. Test 13 asserts.
- **Secrets are references, not values.** D-131 .. D-134 structurally enforce with 6 redaction layers + env allowlist + docker-inspect negative test.
- **Bounded autonomy.** BudgetGuard per-call + `FactoryCircuitBreaker` scaffolded. Oban `max_attempts: 3` default on BaseWorker (P1 D-44).
- **Scenario runner is sole acceptance oracle.** (P5 concern; P3 just ships the adapter + sandbox stack the runner will use.)
- **Typed block reasons, not chat.** D-135 all 9 atoms in enum. 6 REAL + 3 STUB playbooks.
- **Adaptive model routing.** D-105 .. D-108 ModelRegistry + audit event + tier_crossed flag.
- **Run state is Ecto field + command module.** (P2 D-86 existing; P3 adds producers of `:blocked` transitions.)
- **No umbrella app.** D-97 preserved — DTU is `priv/dtu/` mini-project with separate release, NOT umbrella sibling.
- **No GenServer-per-work-unit.** (P4 concern; not P3.)
- **Elixir anti-patterns.** P3 adds to CLAUDE.md list (per D-151): "secrets stored outside `persistent_term`-backed `Kiln.Secrets`; raw API keys in struct fields; `System.cmd` for `docker` without `MuonTrap.cmd` crash-safety wrapper."

---

## State of the Art

| Old Approach | Current (2026) Approach | When Changed | Impact |
|--------------|-------------------------|--------------|--------|
| Anthropic structured output via `tool_use` hijacking | **Native `output_config.format.json_schema`** | 2026 Q1 | D-104 adopts native as primary with `tool_use` as fallback. Error rate 15% → 3% per industry benchmarks. `[CITED: platform.claude.com/docs/en/build-with-claude/structured-outputs]` |
| OpenAPI server-stub generation for mocks | Hand-written handlers + JSV response validation | 2024+ (StrongDM pattern) | Alpha-only server-stub tooling for Elixir; SDK compatibility requires behavioral realism hand-written handlers provide. |
| Record-and-replay HTTP fixtures (ExVCR) | Content-bundled OpenAPI description + JSV schema validation | — | PAT-leak risk in recorded fixtures violates SEC-01; also captures stale shapes. |
| `System.cmd/3` for docker | **`MuonTrap.cmd/3` for docker** | 2023 Nerves ecosystem | Subprocess-tree kill on BEAM crash; cgroup containment on Linux. |
| Floki in LiveViewTest | LazyHTML (LiveView 1.1) | 2024 Q4 | P3 not affected (no LiveView work); flagged for P7. |
| Ecto `Repo.transaction/2` | `Repo.transact/2` | Ecto 3.13 | P3 uses `transact/2` in Harvester/stage-completion tx. |
| Custom seccomp profiles | **Docker default seccomp profile** + cap-drop=ALL | Long-standing; 2026 still prevailing | Default blocks ~44 syscalls; combined with cap-drop=ALL covers the threat model. D-118 rejects custom as tuning pit. |
| `Timex` for date math | Elixir stdlib `Calendar`, `DateTime`, `Duration` | Elixir 1.17+ | No `Timex` in P3 code. |
| Cowboy HTTP server | **Bandit** | Phoenix 1.7.11+ default | DTU sidecar uses Bandit directly (standalone). |
| `Phoenix.PubSub.broadcast` on stream chunks | **Deferred — no PubSub in P3** | 2025 Hex Shift writeups + LiveView backpressure observations | D-103 defers to P4/P7 where consumer exists. |

**Deprecated / outdated:**
- `ex_json_schema` (Draft 4 only; dormant) — use JSV Draft 2020-12. (Already deprecated in P1 STACK.md.)
- `Poison` JSON — use `JSON` stdlib (Elixir 1.19) or `Jason`.
- `HTTPoison` — use Req.
- `meck` / `mock` — use Mox.
- Rootless Docker on Docker Desktop macOS — networking caveats; revisit P9.
- Custom seccomp JSON in P3 scope — revisit only on adversarial suite gap.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `--pids-limit=512` is sufficient for BEAM + `mix test` in coding stages | Sandbox Resource Limits | Process spawn failure during test runs; bump to 1024 |
| A2 | `--memory=2g` is sufficient for BEAM `mix compile` | Sandbox Resource Limits | OOM on first compile; bump to 3g per `[CITED: elixirforum.com/t/57251]` |
| A3 | Anthropix 0.6.2 returns Enumerable.t() from streaming chat (verified in docs, not tested against live API) | Pattern 1 | Stream wrapping breaks; fallback to pid-mode per Anthropix docs |
| A4 | `count_tokens` endpoint rate limits are "separate and independent" from Messages API | Pattern — BudgetGuard pre-flight | Anthropic docs state this but published rate-limit tiers not yet validated; worst case: add client-side rate limiter on `count_tokens` calls |
| A5 | Docker embedded DNS at 127.0.0.11 on `internal: true` bridge NXDOMAINs public names | Pitfall 2 | Egress test fails; add explicit `--dns-opt=ndots:0` per D-119 Layer 3 (already planned) |
| A6 | `--sysctl net.ipv6.conf.all.disable_ipv6=1` per-container works reliably across Docker 24+ | Pattern 4 | moby#20559 inconsistencies; fallback: declare `kiln-sandbox` as IPv4-only in IPAM (D-119 Layer 5) |
| A7 | MuonTrap's port-close semantic on macOS kills docker CLI subprocess (but NOT the detached container) | Pitfall 6 | Already assumed in D-120; OrphanSweeper + `--rm` + `--init` cover the gap |
| A8 | JSV Draft 2020-12 can validate the bundled-dereferenced GitHub OpenAPI description in a reasonable time budget (<100ms per response) | Pattern — DTU | If too slow: cache validators per-endpoint; skip validation on high-volume endpoints in `:prod`-profile DTU |
| A9 | Anthropic native `output_config.format.json_schema` endpoint is available on `claude-sonnet-4-5` in April 2026 | Structured Output Enforcement | Fallback to `tool_use` + `strict: true` per D-104 original plan |
| A10 | 6 GitHub endpoint families (`issues`, `pulls`, `checks`, `contents`, `branches`, `tags`) cover the stage-execution path P3 tests | DTU | Gaps surface as 501 responses in tests; add handlers incrementally |
| A11 | Elixir/OTP subprocess kills propagate through Docker Desktop's VM → CLI → daemon chain on macOS | Pitfall 6 | OrphanSweeper catches anything missed; BootChecks 8 makes this visible not silent |

**All A# claims need validation during Phase 3 execution — they are reasonable defaults, not certainties.** Planner should route these as integration-test assertions where possible (A1-A6, A9-A10 are testable; A7-A8, A11 require runtime observation).

---

## Open Questions

1. **Should `output_config` (2026 native) or `tool_use` be the default in `Kiln.Agents.StructuredOutput` for Anthropic?**
   - What we know: Native `output_config` is preferred per 2026 Anthropic docs + industry sources; `tool_use` is what Anthropix 0.6.2 wraps today.
   - What's unclear: Whether Anthropix 0.6.2 exposes `output_config` passthrough or if Kiln needs a direct-Req bypass for structured output.
   - Recommendation: Implement `StructuredOutput.Anthropic` as a direct-Req call (bypassing Anthropix for this one path) when `capabilities().json_schema_mode == true` and the model is known to support `output_config`; fall back to `tool_use` via Anthropix for older models. Verify Anthropix roadmap during Phase 3 execution — if 0.7.x exposes `output_config`, consolidate.

2. **Do we ship `mix check_no_sandbox_env_secrets` in P3 or defer?**
   - What we know: D-26 pattern (grep-based static check) is established.
   - What's unclear: Whether the regex-based denylist in D-134 can be source-level verified with high signal (few false positives).
   - Recommendation: Claude's discretion per CONTEXT.md; likely defer to Phase 9 hardening unless source-level signal is high.

3. **Where does `Kiln.Pricing` fetch pricing tables from?**
   - What we know: `priv/pricing/v1/<provider>.exs` is the storage; `mix kiln.pricing.check` is WARN-only in P3.
   - What's unclear: Do we ship initial pricing data hand-curated from April 2026 provider pages, or do we scrape during planning?
   - Recommendation: Hand-curate during Phase 3 planning (planner fetches prices from `https://www.anthropic.com/pricing`, `https://openai.com/api/pricing`, `https://ai.google.dev/pricing`, `https://ollama.com/library` — note Ollama is free, input/output `0.00`). These are the anchor values in `priv/pricing/v1/<provider>.exs`. `mix kiln.pricing.check` flags staleness.

4. **Do OpenAI/Google/Ollama scaffolds need to ship a Mox contract test proving the behaviour shape, even though they're not LIVE in P3?**
   - What we know: D-101 says scaffolded ~200 LOC each with Mox contract tests + `@tag :live_*` gates.
   - What's unclear: Whether "contract test" means (a) the compiled behaviour compiles, or (b) a Mox-backed functional test that exercises `complete/2` + `stream/2`.
   - Recommendation: (b) — every adapter ships a Mox contract test in P3. `@tag :live_openai` etc. is the skip-by-default for real-wire tests; Mox versions run always.

5. **Should `Kiln.Notifications.desktop/2` use `MuonTrap.cmd` or raw `System.cmd`?**
   - What we know: D-140 says `System.cmd`; but CLAUDE.md P3 anti-pattern addition says "`System.cmd` for `docker` without `MuonTrap.cmd` crash-safety wrapper."
   - What's unclear: Whether the anti-pattern applies to `osascript`/`notify-send` (fast, <100ms calls) or only to long-running `docker run`.
   - Recommendation: Use MuonTrap for consistency; the wrapper overhead is negligible. This keeps the "MuonTrap for all shell-outs" pattern clean.

---

## Sources

### Primary (HIGH confidence)

- [Anthropix 0.6.2 hexdocs](https://hexdocs.pm/anthropix/Anthropix.html) — API shape, streaming, tool_use. **Confirmed gap: no `count_tokens` wrapper.**
- [Anthropic `count_tokens` endpoint](https://platform.claude.com/docs/en/api/messages-count-tokens) — `POST /v1/messages/count_tokens`; response `{"input_tokens": <number>}`; free + separate rate limits.
- [Anthropic Structured Outputs docs (2026)](https://platform.claude.com/docs/en/build-with-claude/structured-outputs) — native `output_config.format.json_schema`.
- [MuonTrap hexdocs](https://hexdocs.pm/muontrap/MuonTrap.html) — `cmd/3`, cgroup controllers, "parent dies → children die" guarantee.
- [MuonTrap.Daemon](https://hexdocs.pm/muontrap/MuonTrap.Daemon.html) — supervised OS process wrapping.
- [Docker seccomp profile docs](https://docs.docker.com/engine/security/seccomp/) — default blocks ~44 syscalls.
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) — §5.3, §5.10, §5.11, §5.12, §5.24, §5.25, §5.28.
- [Bandit (standalone usage)](https://github.com/mtrudel/bandit) — `{Bandit, plug: MyApp.MyPlug}` minimum.
- [JSV hexdocs](https://hexdocs.pm/jsv) — Draft 2020-12 validation.
- [Docker networking docs](https://docs.docker.com/engine/network/) — bridge `internal: true` semantics.
- [LiteLLM reliability error taxonomy](https://docs.litellm.ai/docs/proxy/reliability) — fallback trigger categories.
- [OpenAPI Generator Elixir](https://openapi-generator.tech/docs/generators/elixir/) — alpha, client-only (justifies hand-written DTU handlers).
- [erlang persistent_term](https://www.erlang.org/doc/apps/erts/persistent_term.html) — write-once-at-boot rationale.

### Secondary (MEDIUM confidence — WebSearch verified against official sources)

- [Simon Willison DTU writeup 2026-02-07](https://simonwillison.net/2026/Feb/7/software-factory/) — only public StrongDM DTU prior art.
- [Hex Shift: LiveView backpressure](https://hexshift.medium.com/websocket-backpressure-in-phoenix-liveview-how-to-handle-the-load-without-dropping-the-ball-bc16b058e7dd) — justifies D-103 PubSub deferral.
- [Elixir 1.19 Docker 2GB memory note (Elixir Forum)](https://elixirforum.com/t/elixir-erlang-docker-containers-ram-usage-on-different-oss-kernels/57251) — justifies `--memory=2g` for coding stages.
- [elixir-lang#2571 high nofile slowdown](https://github.com/elixir-lang/elixir/issues/2571) — justifies `--ulimit nofile=4096:8192` cap.
- [moby#20559 IPv6 inconsistencies](https://github.com/moby/moby/issues/20559) — justifies `--sysctl net.ipv6.conf.all.disable_ipv6=1` belt-and-suspenders.
- [Structured Output Comparison (Glukhov 2025)](https://medium.com/@rosgluk/structured-output-comparison-across-popular-llm-providers-openai-gemini-anthropic-mistral-and-1a5d42fa612a) — native modes > prompted.
- [Mastra native-modes claim](https://mastra.ai/blog/mcp-tool-compatibility-layer) — 15% → 3% error rate reduction.
- [Docker Bench for Security (OneUptime 2026-02)](https://oneuptime.com/blog/post/2026-02-08-how-to-use-docker-bench-security-to-harden-your-installation/view) — concrete production values `--memory=512m --pids-limit 100`.
- [Towards Data Science: Anthropic Structured Outputs 2026](https://towardsdatascience.com/hands-on-with-anthropics-new-structured-output-capabilities/) — practical guide.
- [Tessl blog: Anthropic Structured Outputs](https://tessl.io/blog/anthropic-brings-structured-outputs-to-claude-developer-platform-making-api-responses-more-reliable/).

### Tertiary (LOW confidence — single source)

- [buildmvpfast: JSON Mode vs Function Calling vs Structured Output 2026](https://www.buildmvpfast.com/blog/structured-output-llm-json-mode-function-calling-production-guide-2026) — industry comparison.
- [langchain_elixir hexdocs](https://hexdocs.pm/langchain/LangChain.ChatModels.LLMCallbacks.html) — reference shape for P7 streaming consumer.

### Internal references (consumed, not re-derived)

- `/Users/jon/projects/kiln/CLAUDE.md` — project conventions.
- `/Users/jon/projects/kiln/.planning/phases/03-agent-adapter-sandbox-dtu-safety/03-CONTEXT.md` — 46 locked decisions.
- `/Users/jon/projects/kiln/.planning/phases/03-agent-adapter-sandbox-dtu-safety/03-DISCUSSION-LOG.md` — Socratic Q&A log.
- `/Users/jon/projects/kiln/.planning/research/STACK.md` — pinned versions.
- `/Users/jon/projects/kiln/.planning/research/ARCHITECTURE.md` — supervision tree + bounded contexts.
- `/Users/jon/projects/kiln/.planning/research/PITFALLS.md` — P2 (cost runaway), P5 (sandbox escape), P8 (prompt injection), P10 (model deprecation), P17 (OTel context), P20 (LLM JSON), P21 (secrets).
- `/Users/jon/projects/kiln/.planning/REQUIREMENTS.md` — AGENT-01/02/05, SAND-01..04, SEC-01, BLOCK-01/03, OPS-02/03.
- `/Users/jon/projects/kiln/.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — P1 D-06, D-12, D-17, D-42, D-44, D-46.
- `/Users/jon/projects/kiln/.planning/phases/02-workflow-engine-core/02-CONTEXT.md` — P2 D-57, D-70, D-73, D-91, D-97.

---

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH — all versions pre-pinned; MuonTrap sole new addition validated against hexdocs.
- **Architecture patterns:** HIGH — 46 locked decisions; patterns mirror P1/P2 established shapes (compile-time registries 4th instance, scaffold-now-fill-later 2nd instance, staged supervisor boot, `MuonTrap` for shell-out).
- **Docker hardening (Pitfall 2, Sandbox Resource Limits, Adversarial Tests):** HIGH — CIS Docker Benchmark + Docker Bench for Security + OWASP Container Rules grounded with specific control IDs.
- **Secret discipline (Pitfall 1, SEC-01 Architecture):** HIGH — 6-layer defense is explicit structural invariant; each layer mapped to a specific test.
- **Streaming backpressure (SSE → PubSub → LiveView):** MEDIUM-HIGH for the P3 deferral rationale; N/A for P7 implementation (out of scope).
- **DTU pattern (Hand-written handlers + JSV validation):** MEDIUM — only one public prior art (StrongDM); Kiln's adaptation is sound but needs empirical tuning during P9 dogfood.
- **BudgetGuard per-call pre-flight:** HIGH — Anthropic `count_tokens` endpoint verified + response shape confirmed + pricing estimation is pure function.
- **Fallback chain (OPS-02):** HIGH — LiteLLM taxonomy well-documented; Kiln extends with `:context_length_exceeded` + `:content_policy_violation` + audit event with `tier_crossed` flag.
- **Structured output (D-104):** HIGH for native mode availability; HIGH for the facade pattern; MEDIUM for per-provider dispatch details (industry consensus but some providers change quarterly).
- **Anthropic 2026 native `output_config` API:** HIGH — verified against Anthropic official docs (request body reference); **this is a refinement of CONTEXT D-104 that the planner MUST apply.**
- **Concrete sandbox limits (2g/2cpu/512 pids/4096 nofile):** HIGH for policy shape + CIS grounding; MEDIUM for exact numbers (Phase 3 execution validates against live Phoenix/Oban compile workload).
- **Orphan sweep + MuonTrap macOS gap:** HIGH — defense-in-depth covers both Linux cgroup case and macOS port-close case.
- **Project Constraints (CLAUDE.md):** HIGH — every CLAUDE.md directive is either structurally honored by D-101..D-155 or explicitly flagged as out-of-scope for P3 (typed tool allowlist, untrusted-content markers, scenario runner).

**Research date:** 2026-04-20
**Valid until:** 2026-05-20 (30 days — stable domain; revalidate Anthropic `output_config` API availability if planner/executor defer Phase 3 execution past this window, since the endpoint is newly-GA and could iterate).
