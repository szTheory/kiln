---
phase: 3
slug: agent-adapter-sandbox-dtu-safety
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-20
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mox + StreamData + LazyHTML (existing from Phase 1) |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix check` (includes `test`, `credo --strict`, `dialyzer`, `sobelow`, `mix_audit`, `xref graph --format cycles`, `check_bounded_contexts`) |
| **Estimated runtime** | ~90s quick, ~5–8 min full (Dialyzer PLT dominant) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale`
- **After every plan wave:** Run `mix check` (full meta-runner)
- **Before `/gsd-verify-work`:** Full suite must be green; sandbox-escape adversarial suite must be green
- **Max feedback latency:** 120 seconds quick; 480 seconds full

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-00-01 | 00 | 0 | AGENT-01, SAND-01 | T-03-00-01 | New deps resolve reproducibly (`muontrap`, `bypass`, `ex_docker_engine_api`) | unit (compile) | `mix deps.get && mix compile --warnings-as-errors` | ❌ Wave 0 (mix.exs edit) | ⬜ |
| 03-00-02 | 00 | 0 | AGENT-01, SAND-01, SAND-04 | T-03-00-03 | Mox defmocks + 5 ExUnit case templates compile + resolve | unit | `mix test test/support/mocks_test.exs --max-failures=1` | ❌ Wave 0 | ⬜ |
| 03-00-03 | 00 | 0 | SEC-01, OPS-02 | T-03-00-02 | Fixture corpora seeded + parseable (Anthropic responses / pricing vectors / fake keys / isolation baselines) | unit | `elixir -e 'Code.eval_file("test/support/fixtures/secrets/fake_keys.exs")'` exit 0 | ❌ Wave 0 | ⬜ |
| 03-01-01 | 01 | 1 | SEC-01 | T-03-01-01, T-03-01-02 | `Kiln.Secrets.Ref` inspect never leaks raw key; `reveal!/1` is sole raw-string boundary | unit | `mix test test/kiln/secrets_test.exs --max-failures=1` | ❌ Wave 1 (lib/kiln/secrets.ex) | ⬜ |
| 03-01-02 | 01 | 1 | SEC-01 | T-03-01-03 | `Kiln.Logging.SecretRedactor` scrubs 5 key-name substrings + 5 value-prefix patterns | unit | `mix test test/kiln/logging/secret_redactor_test.exs --max-failures=1` | ❌ Wave 1 | ⬜ |
| 03-02-01 | 02 | 1 | BLOCK-01 | T-03-02-01 | `Kiln.Blockers.Reason` closed 9-atom enum + `BlockedError` exception + playbook JSV schema | unit | `mix test test/kiln/blockers/reason_test.exs --max-failures=1` | ❌ Wave 1 | ⬜ |
| 03-02-02 | 02 | 1 | BLOCK-01 | T-03-02-02 | 9 playbook markdown files (6 real + 3 stub) with YAML frontmatter matching `priv/playbook_schemas/v1/playbook.json` | unit (filesystem) | `ls priv/playbooks/v1/*.md | wc -l` returns 9 AND `head -1` of each is `---` | ❌ Wave 1 | ⬜ |
| 03-02-03 | 02 | 1 | BLOCK-01 | T-03-02-01, T-03-02-02 | `Kiln.Blockers.PlaybookRegistry` compile-time @external_resource walk + JSV validate + Mustache render + CompileError on missing file | unit | `mix compile --warnings-as-errors && mix test test/kiln/blockers/playbook_registry_test.exs test/kiln/blockers_test.exs --max-failures=1` | ❌ Wave 1 | ⬜ |
| 03-03-01 | 03 | 1 | AGENT-05, OPS-02, SEC-01, BLOCK-03 | T-03-03-01, T-03-03-03 | 9 new audit event kinds (`orphan_container_swept`, `dtu_contract_drift_detected`, `dtu_health_degraded`, `factory_circuit_opened/closed`, `model_deprecated_resolved`, `model_routing_fallback`, `notification_fired/suppressed`) + JSV Draft 2020-12 schemas | unit (compile) | `mix compile --warnings-as-errors && for f in priv/audit_schemas/v1/orphan_container_swept.json priv/audit_schemas/v1/dtu_contract_drift_detected.json priv/audit_schemas/v1/dtu_health_degraded.json priv/audit_schemas/v1/factory_circuit_opened.json priv/audit_schemas/v1/factory_circuit_closed.json priv/audit_schemas/v1/model_deprecated_resolved.json priv/audit_schemas/v1/model_routing_fallback.json priv/audit_schemas/v1/notification_fired.json priv/audit_schemas/v1/notification_suppressed.json; do jq . "$f" > /dev/null; done` | ❌ Wave 1 | ⬜ |
| 03-03-02 | 03 | 1 | AGENT-05, OPS-02 | T-03-03-02 | Reversible Postgres migration round-trip (drops + re-adds `audit_events_event_kind_check`) | integration | `mix ecto.migrate && mix test test/kiln/audit/event_kind_p3_test.exs --max-failures=1 && mix ecto.rollback --step 1 && mix ecto.migrate` | ❌ Wave 1 | ⬜ |
| 03-04-01 | 04 | 2 | BLOCK-03 | — (D-91 precedent) | `Kiln.Policies.FactoryCircuitBreaker` supervised no-op GenServer (mirrors `StuckDetector`) with stable `check/1 :: :ok | {:halt, atom, map}` contract | unit | `mix test test/kiln/policies/factory_circuit_breaker_test.exs --max-failures=1` | ❌ Wave 2 | ⬜ |
| 03-04-02 | 04 | 2 | BLOCK-03 | T-03-04-01, T-03-04-02, T-03-04-03 | `Kiln.Notifications.desktop/2` OS-routed dispatch + ETS dedup 5-min TTL + `notification_fired`/`notification_suppressed` audit + `Blockers.Reason.valid?/1` gate | unit | `mix test test/kiln/notifications_test.exs --max-failures=1` | ❌ Wave 2 | ⬜ |
| 03-05-01 | 05 | 2 | AGENT-01 | T-03-05-01 | `Kiln.Agents.Adapter` behaviour (4 callbacks) + Prompt/Response structs (Jason.Encoder excludes `metadata`/`raw`) + SessionSupervisor DynamicSupervisor | unit | `mix test test/kiln/agents/adapter_contract_test.exs test/kiln/agents/prompt_test.exs test/kiln/agents/response_test.exs --max-failures=1` | ❌ Wave 2 | ⬜ |
| 03-05-02 | 05 | 2 | AGENT-01, AGENT-05, SEC-01 | T-03-05-02, T-03-05-03 | `Kiln.Agents.Adapter.Anthropic` LIVE wrapping Anthropix 0.6.2 + telemetry span + `ExternalOperations` two-phase intent + EXACTLY 1 `Secrets.reveal!` site | contract | `mix test test/kiln/agents/adapter/anthropic_test.exs --exclude live_anthropic --max-failures=1 && [ "$(grep -c Secrets.reveal! lib/kiln/agents/adapter/anthropic.ex)" = "1" ]` | ❌ Wave 2 | ⬜ |
| 03-05-03 | 05 | 2 | AGENT-01 | T-03-05-04 | Scaffolded `Adapter.{OpenAI,Google,Ollama}` (behaviour-compliant, `{:error, :scaffolded}` default) + `StructuredOutput` facade dispatches by capabilities + JSV post-validation | contract | `mix test test/kiln/agents/adapter/openai_test.exs test/kiln/agents/adapter/google_test.exs test/kiln/agents/adapter/ollama_test.exs test/kiln/agents/structured_output_test.exs --exclude live_openai --exclude live_google --exclude live_ollama --max-failures=1` | ❌ Wave 2 | ⬜ |
| 03-06-01 | 06 | 2 | AGENT-02, OPS-03 | T-03-06-03 | `Kiln.Pricing` priv-loaded tables + 6 D-57 presets (`:same_provider` policy) + `ModelRegistry.adapter_for/1` routing + `mix kiln.registry.show` CLI | unit | `mix test test/kiln/pricing_test.exs test/kiln/model_registry_test.exs test/kiln/model_registry/presets_test.exs --max-failures=1 && mix kiln.registry.show elixir_lib` | ❌ Wave 2 | ⬜ |
| 03-06-02 | 06 | 2 | AGENT-05, OPS-02 | T-03-06-01, T-03-06-02 | `BudgetGuard.check!/2` 7-step pre-flight (D-138 strict, no override) raises `BlockedError(:budget_exceeded)` + `TelemetryHandler` writes `model_routing_fallback` only on actual fallback | unit | `mix test test/kiln/agents/budget_guard_test.exs test/kiln/agents/telemetry_handler_test.exs --max-failures=1 && [ "$(grep -c BUDGET_OVERRIDE lib/kiln/agents/budget_guard.ex)" = "0" ]` | ❌ Wave 2 | ⬜ |
| 03-07-01 | 07 | 3 | SAND-01, SAND-02, SAND-03 | T-03-07-01, T-03-07-02 | `Kiln.Sandboxes.ContainerSpec` + `ImageResolver` (priv-loaded digest) + `Limits` (`:persistent_term`) | unit | `mix test test/kiln/sandboxes/container_spec_test.exs test/kiln/sandboxes/image_resolver_test.exs test/kiln/sandboxes/limits_test.exs --max-failures=1` | ❌ Wave 3 | ⬜ |
| 03-07-02 | 07 | 3 | SAND-04, SEC-01 | T-03-07-03, T-03-07-04 | `EnvBuilder` (strict allowlist — secret-shaped names rejected) + `Hydrator`/`Harvester` (CAS IO) | unit | `mix test test/kiln/sandboxes/env_builder_test.exs test/kiln/sandboxes/hydrator_test.exs test/kiln/sandboxes/harvester_test.exs --max-failures=1` | ❌ Wave 3 | ⬜ |
| 03-08-01 | 08 | 4 | SAND-01, SAND-02 | T-03-08-01, T-03-08-02 | `Kiln.Sandboxes.Driver` behaviour + `DockerDriver` MuonTrap-wrapped D-117 hardened argv (no `--privileged`, no `docker.sock`) + telemetry with full argv metadata + `--name kiln-stage-<uuid>` label | unit | `mix test test/kiln/sandboxes/docker_driver_test.exs --max-failures=1 && [ "$(grep -cE '(docker.sock|--privileged)' lib/kiln/sandboxes/docker_driver.ex)" = "0" ]` | ❌ Wave 4 | ⬜ |
| 03-08-02 | 08 | 4 | SAND-01 | T-03-08-03 | `OrphanSweeper` GenServer boot+periodic scan + `Sandboxes.Supervisor` (OrphanSweeper FIRST per D-120, DedupCache hosted here) + rewritten `Kiln.Sandboxes` moduledoc (no "Phase 4") | unit | `mix test test/kiln/sandboxes/orphan_sweeper_test.exs --max-failures=1 && [ "$(grep -c 'Phase 4' lib/kiln/sandboxes.ex)" = "0" ]` | ❌ Wave 4 | ⬜ |
| 03-09-01 | 09 | 4 | SAND-03 | T-03-09-01, T-03-09-04 | `priv/dtu/` mini-mix-project (Bandit + Plug.Router + 6 GitHub handlers + chaos closed-enum middleware + JSV stub + 501 fallback + pinned OpenAPI snapshot) | unit | `cd priv/dtu && mix deps.get && mix compile --warnings-as-errors && mix test` | ❌ Wave 4 | ⬜ |
| 03-09-02 | 09 | 4 | SAND-03 | T-03-09-02, T-03-09-03 | `Kiln.Sandboxes.DTU.{Supervisor, HealthPoll, ContractTest, CallbackRouter}` — HealthPoll 3-miss-degrade + ContractTest Oban stub on `:dtu` queue | unit | `mix test test/kiln/sandboxes/dtu/health_poll_test.exs test/kiln/sandboxes/dtu/contract_test_test.exs --max-failures=1` | ❌ Wave 4 | ⬜ |
| 03-10-01 | 10 | 5 | — | T-03-10-02 | `NextStageDispatcher` pure module (NOT a GenServer) with fan-out + fan-in barrier via `depends_on` + idempotency key `run:<id>:stage:<sid>` | unit | `mix test test/kiln/stages/next_stage_dispatcher_test.exs --exclude integration --max-failures=1` | ❌ Wave 5 | ⬜ |
| 03-10-02 | 10 | 5 | AGENT-05, SAND-04 | T-03-10-01, T-03-10-03 | `StageWorker.perform/1` integrated chain: BudgetGuard → Hydrator → DockerDriver → Adapter → Harvester → NextStageDispatcher (LOCKED transition mapping preserved) + workspace cleanup on both paths | integration | `mix test test/kiln/stages/ --exclude integration --max-failures=1` | ❌ Wave 5 | ⬜ |
| 03-11-01 | 11 | 5 | — | T-03-11-03 | `Kiln.Application` 14-child supervision tree (Sandboxes.Supervisor before RunDirector per D-120; single Finch with per-provider pools per D-109 amendment) + `Limits.load!` + `TelemetryHandler.attach` | unit | `mix test test/kiln/application_test.exs --max-failures=1` | ❌ Wave 5 | ⬜ |
| 03-11-02 | 11 | 5 | SEC-01 | T-03-11-01 | `Kiln.BootChecks.run!/0` extended to 8 invariants (+ `:secrets_presence_map_non_empty`, + `:no_prior_boot_sandbox_orphans` per D-143) | unit | `mix test test/kiln/boot_checks_test.exs --exclude docker --max-failures=1` | ❌ Wave 5 | ⬜ |
| 03-11-03 | 11 | 5 | SEC-01, BLOCK-01 | T-03-11-01, T-03-11-02 | `RunDirector.start_run/1` gates on `Secrets.present?/1` (raises `BlockedError(:missing_api_key)` before any LLM call); `config/runtime.exs` seeds `Kiln.Secrets` from env; spec upgrades D-151..D-155 applied (CLAUDE / ARCHITECTURE / STACK / PITFALLS) | unit | `mix test test/kiln/runs/run_director_p3_test.exs --max-failures=1 && grep -c MuonTrap CLAUDE.md && grep -c 'Sandbox dependencies' .planning/research/STACK.md` | ❌ Wave 5 | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*File Exists column: `❌ Wave N` means the file does not exist yet and is created by the indicated wave; `✅ existing` would indicate reuse of a Phase 1/2 artifact.*

**Populated by planner:** All 28 executor tasks across plans 03-00..03-11 have a Task ID row mapping `task_id → test command`. Nyquist Dimension 8 coverage proven. Sampling-continuity gate: no 3 consecutive tasks without automated verify — every row has an `Automated Command`.

---

## Wave 0 Requirements

Wave 0 for Phase 3 establishes the behaviour seams, Mox mocks, and test harnesses needed before Wave 1 can begin. All items are new (no prior coverage).

- [ ] `test/support/agent_adapter_case.ex` — shared ExUnit case for adapter contract tests
- [ ] `test/support/anthropic_stub_server.ex` — Bypass/Plug-based Anthropic API stub (pinned HTTP fixtures, cassette-style replay)
- [ ] `test/support/docker_fixture.ex` — helpers to spin up ephemeral sandbox containers with pinned Alpine digest
- [ ] `test/support/dtu_mock_case.ex` — shared case with DTU mock network + egress assertions
- [ ] `test/kiln/agents/adapter_contract_test.exs` — Mox-backed behaviour contract suite (AGENT-01)
- [ ] `test/kiln/agents/model_registry_test.exs` — role resolution, presets, fallback chain (AGENT-02, AGENT-05)
- [ ] `test/kiln/agents/budget_guard_test.exs` — per-call USD/token gate (AGENT-05)
- [ ] `test/kiln/sandboxes/egress_block_test.exs` — adversarial negative suite over TCP/UDP/DNS/ICMP/IPv6 (SAND-01)
- [ ] `test/kiln/sandboxes/dtu_reachability_test.exs` — DTU mock reachable on `dtu_only` network (SAND-04)
- [ ] `test/kiln/sandboxes/resource_limits_test.exs` — `--cap-drop=ALL`, `--pids-limit`, `--memory`, `--cpus`, `--ulimit nofile` (SAND-02, SAND-03)
- [ ] `test/kiln/secrets/redaction_test.exs` — `@derive Inspect except: [:api_key]` + crash-dump + Logger line + changeset error proofs (SEC-01)
- [ ] `test/kiln/blockers/playbook_test.exs` — typed reason enum mapped to remediation playbook (BLOCK-01, BLOCK-03)
- [ ] Add `:bypass`, `:muontrap`, `:ex_docker_engine_api` to `mix.exs` if not already present from Phase 1

*If any item exists from Phase 1, mark ✅ existing and skip in Wave 0.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Desktop notification on `:missing_api_key` blocker fires `osascript`/`notify-send` | BLOCK-03 | OS-level notification center side-effect; CI has no GUI | On macOS dev loop: unset `ANTHROPIC_API_KEY`, start a run; confirm macOS Notification Center displays the typed block reason. Automated portion asserts the shell-out is invoked with correct args (Mox). |
| `docker inspect` output contains no provider secrets in env | SEC-01 | Live container introspection | Automated via `test/kiln/sandboxes/secrets_leak_test.exs` (shells out to `docker inspect` with a running stage container fixture); manual spot-check during `/gsd-verify-work` confirms CI snapshot matches live behavior. |

*All other phase behaviors have automated verification.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags (`mix test.watch` forbidden in CI)
- [x] Feedback latency < 120s quick / < 480s full
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** planner-approved 2026-04-20 (revision iteration 1/3). Executor may begin Wave 0.
