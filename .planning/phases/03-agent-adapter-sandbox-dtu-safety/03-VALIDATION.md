---
phase: 3
slug: agent-adapter-sandbox-dtu-safety
status: draft
nyquist_compliant: false
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
| (filled during planning — one row per executor task; plans MUST populate) | | | | | | | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Populated by planner:** Every PLAN.md task must append a row here mapping `task_id → test command`. The planner MUST emit VALIDATION.md diffs alongside PLAN.md updates so Nyquist Dimension 8 coverage is proven before execution begins.

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags (`mix test.watch` forbidden in CI)
- [ ] Feedback latency < 120s quick / < 480s full
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
