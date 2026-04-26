---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "00"
subsystem: testing
tags:
  - phase-3
  - wave-0
  - mox
  - bypass
  - muontrap
  - ex_docker_engine_api
  - test-infrastructure

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor
    provides: mix.exs base deps (anthropix, ex_machina, mox), elixirc_paths(:test) convention, Kiln.Oban.BaseWorker, Kiln.StuckDetectorCase singleton-guard pattern
  - phase: 02-workflow-engine-core
    provides: Kiln.StuckDetectorCase deferred-activation pattern, Kiln.Repo Ecto sandbox, existing test/support scaffold (oban_case, rehydration_case, cas_test_helper)

provides:
  - Mox defmocks (Kiln.Agents.AdapterMock, Kiln.Sandboxes.DriverMock) with deferred-activation guard
  - 6 ExUnit case templates (AgentAdapterCase, SandboxCase, DtuCase, FactoryCircuitBreakerCase, and the helper modules DockerHelper + AnthropicStubServer)
  - 4 fixture corpora (5 Anthropic response JSONs, 3 pricing seed vectors, 5 fake-secret keys, 3 network-isolation baselines)
  - 3 new mix deps (muontrap ~> 1.7, bypass ~> 2.1, ex_docker_engine_api ~> 1.43)
  - test_helper.exs 9-tag exclude list (docker, dtu, integration, live_*, adversarial_egress, secret_leak_hunt, budget_overrun)

affects:
  - 03-01 (Kiln.Secrets — consumes fake_keys fixture)
  - 03-02 (Kiln.Blockers playbooks — consumes blockers reason gate)
  - 03-03 (new audit event kinds)
  - 03-04 (FactoryCircuitBreaker — consumes FactoryCircuitBreakerCase)
  - 03-05 (Kiln.Agents.Adapter — Wave 2 auto-activates AdapterMock)
  - 03-06 (Pricing + BudgetGuard — consumes pricing vectors)
  - 03-07/08 (Sandboxes — consumes SandboxCase + DriverMock)
  - 03-08 (adversarial egress suite — consumes isolation_baselines + fake_keys)
  - 03-09 (DTU — consumes DtuCase + AnthropicStubServer pattern)

# Tech tracking
tech-stack:
  added:
    - "muontrap ~> 1.7 (crash-safe docker run wrapper; D-115/D-154)"
    - "bypass ~> 2.1 (test-only HTTP stub server for Anthropic adapter tests)"
    - "ex_docker_engine_api ~> 1.43 (Docker Engine API client for OrphanSweeper LIST; version tracks Docker Engine API revision, NOT abstract semver)"
  patterns:
    - "Deferred-activation Mox defmock (target behaviour may be absent at Wave 0; real defmock auto-activates when Wave 2/4 ships the behaviour)"
    - "Idempotency guard for test/support files that are both elixirc-compiled AND Code.require_file'd (unless Code.ensure_loaded?(Module) wrap)"
    - "Docker-gated ExUnit case templates with @moduletag :docker + docker_available?/0 skip path + on_exit container cleanup"
    - "Hand-authored fixture corpora (never ExVCR) — SEC-01 gate against persisted PAT tokens"

key-files:
  created:
    - "test/support/mocks.ex — Mox defmock registry + placeholder fallback"
    - "test/support/agent_adapter_case.ex — ExUnit case template for adapter-contract tests"
    - "test/support/sandbox_case.ex — docker-gated case with container cleanup"
    - "test/support/dtu_case.ex — DTU sidecar case (docker compose up -d dtu in setup_all)"
    - "test/support/factory_circuit_breaker_case.ex — mirrors StuckDetectorCase for D-139 scaffold"
    - "test/support/anthropic_stub_server.ex — Bypass handle factory + canned ok/rate_limit responses"
    - "test/support/docker_helper.ex — docker_available?/0 + exec_in_container/2 helpers"
    - "test/support/mocks_test.exs — Wave 0 smoke test (4 tests, 0 failures)"
    - "test/support/fixtures/anthropic_responses/{ok_message,rate_limit_429,server_error_500,context_length_exceeded,content_policy_violation}.json — 5 hand-authored response shapes"
    - "test/support/fixtures/pricing/anthropic_vectors_seed.exs — 3 seed pricing vectors (Wave 2 expands to 10)"
    - "test/support/fixtures/secrets/fake_keys.exs — 5 deterministic fake provider keys (each value contains FAKE marker)"
    - "test/support/fixtures/network/isolation_baselines.exs — 3 DNS/TCP negative-egress baselines"
  modified:
    - "mix.exs — added muontrap, bypass, ex_docker_engine_api"
    - "mix.lock — idna unlocked (7.1.0 → 6.1.1) to satisfy hackney transitive + 15 new lock entries"
    - "test/test_helper.exs — Code.require_file(support/mocks.ex) before ExUnit.start + 9-tag exclude list"
    - ".planning/phases/03-agent-adapter-sandbox-dtu-safety/03-VALIDATION.md — Wave 0 checklist marked complete; per-task map statuses flipped to green"
    - ".planning/ROADMAP.md — Phase 2 row 5/9→9/9 (stale); Phase 3 row 0/TBD→1/12; Phase 3 Plans section populated with 12 plans"
    - ".planning/STATE.md — progress 57%→61%, plan 1→2, Plan 03-00 decisions block added, session continuity"

key-decisions:
  - "ex_docker_engine_api ~> 1.43 (plan specified ~> 7.0 — incorrect; hex package versions track Docker Engine API revision, not abstract semver)"
  - "Deferred-activation Mox defmock pattern (Mox 1.2 invokes Code.ensure_compiled!/1 at defmock time; placeholder-module fallback with __deferred__/0 marker stands in until Wave 2/4 ships the behaviour)"
  - "Idempotency guard around whole test/support/mocks.ex body (elixirc auto-compile + test_helper.exs Code.require_file ⇒ double-load; `unless Code.ensure_loaded?(Kiln.TestMocks)` makes the second load a safe no-op without losing the plan-mandated Code.require_file semantics)"
  - "Unlocked idna 7.1.0 → 6.1.1 (Rule 3 blocker resolution: hackney transitive requires idna ~> 6.1.0; jsv accepts ~> 6.0 or ~> 7.0; resolver picks 6.1.1 which satisfies both)"
  - "Committed test/support/fixtures/secrets/fake_keys.exs — NOT gitignored (plan's trailing Decision paragraph supersedes the earlier gitignore suggestion; every value contains FAKE marker + invalid entropy + moduledoc makes the 'not real' nature explicit)"

patterns-established:
  - "Deferred-activation Mox defmock — mirrors StuckDetectorCase's Plan 02-00 scaffold-now-activate-later pattern; Wave 0 ships the mock name, Wave N ships the behaviour, no arrow-dependency cross-plan edits required"
  - "ExUnit.start(exclude: [...]) with 9 tags — docker/dtu/integration/live_* + adversarial_* — opt-in test dimension model for Phase 3+ (hand-pick via mix test --include <tag>)"
  - "Fixture seeding with _seed.exs suffix — signals 'minimum subset for Wave N; Wave M expands' per AI-SPEC Reference Dataset methodology"

requirements-completed: []  # Plan 03-00 is scaffolding — requirements AGENT-01, SAND-01, SEC-01 etc. are completed by Waves 1-5, not Wave 0. Do NOT mark complete.

# Metrics
duration: 15min
completed: 2026-04-20
---

# Phase 3 Plan 00: Wave 0 Test Infrastructure Summary

**Mox defmocks with deferred-activation, 6 docker-gated ExUnit case templates, Bypass Anthropic stub, and 4-corpus hand-authored fixture seed — the test substrate every Phase 3 Wave 1+ plan assumes exists.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-20T16:45:00Z (approximate — first deps.get invocation)
- **Completed:** 2026-04-20T17:00:00Z
- **Tasks:** 3
- **Files modified:** 17 (13 created, 4 modified)
- **Tests:** 4/4 passing (test/support/mocks_test.exs); full suite 257/0 (no regressions)

## Accomplishments

- `mix deps.get` resolves cleanly with 3 new deps (muontrap, bypass, ex_docker_engine_api); lock diff is 15 new entries + idna downgrade
- `mix compile --warnings-as-errors` exits 0
- `test/support/mocks_test.exs` smoke test: 4 tests, 0 failures
- Mox defmocks register for both `Kiln.Agents.AdapterMock` and `Kiln.Sandboxes.DriverMock` via deferred-activation guard (no Wave 2/4 arrow dependency)
- `test_helper.exs` 9-tag exclude list ensures docker/live_provider/adversarial suites are opt-in
- 4 fixture corpora seeded + parse verified (5 Anthropic JSON, 3 pricing vectors, 5 fake keys, 3 network baselines)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add muontrap, bypass, ex_docker_engine_api deps** — `6abb048` (chore)
2. **Task 2: Mox defmocks + 6 ExUnit case templates** — `fc25650` (test)
3. **Task 3: Seed hand-authored fixture corpora** — `4de8841` (test)

**Plan metadata:** pending (`docs(phase-03-00): complete Wave 0 plan` — next step)

## Files Created/Modified

### Created (13)
- `test/support/mocks.ex` — Mox defmock registry with deferred-activation guard for `Kiln.Agents.AdapterMock` + `Kiln.Sandboxes.DriverMock`
- `test/support/agent_adapter_case.ex` — ExUnit case template (Mox + correlation_id seed + verify_on_exit!/set_mox_from_context)
- `test/support/sandbox_case.ex` — docker-gated case with ETS-tracked container-cleanup on_exit
- `test/support/dtu_case.ex` — DTU sidecar case (`docker compose up -d dtu` in setup_all, static IP 172.28.0.10)
- `test/support/factory_circuit_breaker_case.ex` — mirrors `Kiln.StuckDetectorCase`; Code.ensure_loaded? defensive start
- `test/support/anthropic_stub_server.ex` — Bypass factory + canned ok_response/rate_limit_response
- `test/support/docker_helper.ex` — `docker_available?/0`, `exec_in_container/2`, `track_container/2`
- `test/support/mocks_test.exs` — Wave 0 smoke test (AdapterMock loadable, DriverMock loadable, Bypass handle works, docker_available? returns boolean)
- `test/support/fixtures/anthropic_responses/ok_message.json` — success response with usage record
- `test/support/fixtures/anthropic_responses/rate_limit_429.json` — 429 rate_limit_error
- `test/support/fixtures/anthropic_responses/server_error_500.json` — 500 api_error
- `test/support/fixtures/anthropic_responses/context_length_exceeded.json` — 200k prompt rejection
- `test/support/fixtures/anthropic_responses/content_policy_violation.json` — content-filter rejection
- `test/support/fixtures/pricing/anthropic_vectors_seed.exs` — 3 seed pricing vectors (Opus/Sonnet/Haiku 4.5)
- `test/support/fixtures/secrets/fake_keys.exs` — 5 deterministic-FAKE provider key shapes
- `test/support/fixtures/network/isolation_baselines.exs` — 3 DNS/TCP negative-egress baselines

### Modified (4)
- `mix.exs` — added muontrap ~> 1.7, bypass ~> 2.1 (test-only), ex_docker_engine_api ~> 1.43
- `mix.lock` — idna 7.1.0 → 6.1.1 + 15 new entries (bypass, cowboy, cowlib, cowboy_telemetry, hackney, metrics, mimerl, muontrap, parse_trans, plug_cowboy, ranch, certifi, tesla, unicode_util_compat, ex_docker_engine_api)
- `test/test_helper.exs` — `Code.require_file("support/mocks.ex", __DIR__)` + `ExUnit.start(exclude: [...])` with 9-tag list
- `.planning/phases/03-agent-adapter-sandbox-dtu-safety/03-VALIDATION.md` — Wave 0 checklist marked complete; 03-00-{01,02,03} per-task rows flipped to green

## Decisions Made

See frontmatter `key-decisions` for the 5 binding decisions. Highlights:

1. **`ex_docker_engine_api ~> 1.43` (not `~> 7.0`)** — the package is versioned against the Docker Engine API revision it targets (1.43.x ⇒ Docker Engine 24+/25+), not abstract semver. Corrected the plan text's incorrect version pin.
2. **Deferred-activation Mox defmock** — Mox 1.2 invokes `Code.ensure_compiled!/1` at defmock time; wrapped each defmock in `unless Code.ensure_loaded?(mock_name) do if Code.ensure_loaded?(target_behaviour) do Mox.defmock(...) else placeholder end end` so Wave 0 compiles before Wave 2/4 ships the behaviour.
3. **Idempotency guard** — `test/support/` is `elixirc_paths(:test)` so `mocks.ex` auto-compiles, then `test_helper.exs`'s `Code.require_file` re-executes the body. Wrapping the whole top-level block in `unless Code.ensure_loaded?(Kiln.TestMocks)` makes the second load a safe no-op.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected `ex_docker_engine_api` version pin**
- **Found during:** Task 1 (`mix deps.get`)
- **Issue:** Plan specified `ex_docker_engine_api ~> 7.0`. The hex package is versioned against the Docker Engine API revision (published as 1.43.x), so the constraint matched no versions. `mix deps.get` failed with "doesn't match any versions, version solving failed".
- **Fix:** Changed constraint to `~> 1.43`. Added comment in `mix.exs` explaining the versioning convention.
- **Files modified:** `mix.exs`
- **Verification:** `mix deps.get` resolved; `mix compile --warnings-as-errors` exited 0.
- **Committed in:** `6abb048` (Task 1 commit)

**2. [Rule 3 - Blocker] Unlocked idna to satisfy hackney transitive dep**
- **Found during:** Task 1 (after version fix)
- **Issue:** Lock had `idna 7.1.0` (from jsv transitive, which accepts `~> 6.0 or ~> 7.0`). `ex_docker_engine_api → hackney → idna ~> 6.1.0` — incompatible with the locked version.
- **Fix:** `mix deps.unlock idna` followed by `mix deps.get`. Resolver picked idna 6.1.1 which satisfies both constraint paths.
- **Files modified:** `mix.lock` (idna + 15 new entries)
- **Verification:** Full test suite ran (257/0 pass) under the new lock; no behavioural regression.
- **Committed in:** `6abb048` (Task 1 commit)

**3. [Rule 1 - Bug] Mox defmock deferred-activation guard**
- **Found during:** Task 2 (first `mix compile` after mocks.ex landed)
- **Issue:** Plan asserted `Mox.defmock/2` would compile even when the target `for:` behaviour was absent. Mox 1.2 actually calls `Code.ensure_compiled!/1` at defmock time and raises `(ArgumentError) could not load module Kiln.Agents.Adapter due to reason :nofile`.
- **Fix:** Wrapped each defmock in `unless Code.ensure_loaded?(mock_name) do … end` + `if Code.ensure_loaded?(target) do Mox.defmock(...) else Kiln.TestMocks.define_placeholder!(mock_name) end`. Placeholder modules expose `__deferred__/0` so tests can detect the scaffold state. Mirrors the Plan 02-00 `Kiln.StuckDetectorCase` deferred-activation precedent.
- **Files modified:** `test/support/mocks.ex`
- **Verification:** `mix compile --warnings-as-errors` exit 0; smoke test passes; Wave 2/4 plans will flip the `Code.ensure_loaded?` branch at the next `mix compile` after landing `Kiln.Agents.Adapter` / `Kiln.Sandboxes.Driver`.
- **Committed in:** `fc25650` (Task 2 commit)

**4. [Rule 1 - Bug] Idempotency guard for double-load of mocks.ex**
- **Found during:** Task 2 (after fix #3, compile still emitted "redefining module" warnings fatal under `--warnings-as-errors`)
- **Issue:** `test/support/` is an `elixirc_paths(:test)` entry, so the file's top-level code runs at `mix compile`. `test_helper.exs` then calls `Code.require_file("support/mocks.ex", __DIR__)` (plan-mandated acceptance criterion) which re-executes the top-level, triggering "redefining module Kiln.TestMocks" + "redefining module Kiln.Agents.AdapterMock".
- **Fix:** Wrapped the entire `mocks.ex` body (defmodule + defmock block) in `unless Code.ensure_loaded?(Kiln.TestMocks) do … end`. The second loader short-circuits without re-defining any module. Preserves the plan's `Code.require_file` acceptance criterion.
- **Files modified:** `test/support/mocks.ex`
- **Verification:** Clean-rebuild `mix compile --warnings-as-errors` exit 0 with zero warnings; smoke test 4/4 pass; full suite 257/0.
- **Committed in:** `fc25650` (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (2 × Rule 1 bugs, 1 × Rule 3 blocker, 1 × Rule 1 follow-on bug from fix #3)
**Impact on plan:** All auto-fixes necessary for `mix deps.get` + `mix compile --warnings-as-errors` + Wave 0 smoke-test acceptance criteria to pass. No scope creep; the plan's public contract (dep list, case-template names, fixture corpora) is preserved exactly.

## Issues Encountered

- Plan's version pin for `ex_docker_engine_api` was wrong (documented above).
- Plan's assumption about `Mox.defmock/2` deferred resolution was wrong (documented above).
- Plan's assumption about `Code.require_file` as sole loader was wrong (documented above).

The three upstream assumption-bugs in the plan's `<action>` text are worth noting for future Phase N Wave 0 plans — the planner should verify version-pin strings against hex and verify `Mox.defmock` target-resolution timing before locking the plan text.

## Threat Flags

None. Task scope matched the declared `<threat_model>`:
- **T-03-00-01** (deps entering mix.lock): mitigated by version pins + `mix deps.unlock --check-unused` clean.
- **T-03-00-02** (fake_keys.exs contains real values): mitigated by literal `FAKE` marker in every value + no-entropy padding + moduledoc comment.
- **T-03-00-03** (Mox mocks used in production): mitigated by `only: :test` scope on `bypass` and `ex_machina`; `muontrap` + `ex_docker_engine_api` are runtime-needed but do not register any defmock. No `config :kiln, Kiln.Agents.Adapter, Kiln.Agents.AdapterMock` is set anywhere.

## User Setup Required

None — no external service configuration required. All new deps are library additions; fixtures are committed; Docker is not required to run the Wave 0 smoke suite (the docker-tagged tests skip cleanly when `docker` is not on PATH).

## Next Phase Readiness

**Unblocks:** Plans 03-01 (Kiln.Secrets), 03-02 (Kiln.Blockers), 03-03 (audit event kinds) are ready for parallel spawn by the orchestrator — all three list `depends_on: ["03-00"]` in their frontmatter and consume either the Mox scaffold, the fixture corpus, or the 9-tag exclude list.

**No blockers.** The lock file and compile graph are clean; `mix test` reports 257/0 across the repo.

**Concerns:** The three upstream plan-assumption bugs should be flagged for the plan-check pass on future Wave 0 plans in later phases — specifically the "Mox.defmock does not require the target behaviour to be compiled" assumption, which tripped once in Wave 0 and would trip again if the same wording appears in a Phase 4/5 Wave 0.

## Self-Check: PASSED

Verified after writing SUMMARY.md:

- [x] `mix.exs` contains `{:muontrap, "~> 1.7"}`, `{:bypass, "~> 2.1", only: :test}`, `{:ex_docker_engine_api, "~> 1.43"}`
- [x] `mix deps.get` resolves cleanly
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `test/support/mocks.ex` exists with 2 `Mox.defmock(` call sites (grep count of the literal `Mox.defmock` substring is 8 including doc mentions; all 8 are intentional)
- [x] 6 ExUnit case templates present (agent_adapter_case, sandbox_case, dtu_case, factory_circuit_breaker_case + helpers docker_helper, anthropic_stub_server)
- [x] `test/test_helper.exs` contains `Code.require_file("support/mocks.ex", __DIR__)` BEFORE `ExUnit.start/1`
- [x] 9-tag exclude list (docker, dtu, integration, live_anthropic, live_openai, live_google, live_ollama, adversarial_egress, secret_leak_hunt, budget_overrun)
- [x] 5 Anthropic response JSONs parse (`jq .` exits 0 on each)
- [x] 3 .exs fixtures parse via `mix run --no-start -e 'Code.eval_file(...)'`
- [x] Every fake_keys value contains `FAKE` substring
- [x] `mix test test/support/mocks_test.exs` reports 4 tests, 0 failures
- [x] Full suite: 257 tests, 0 failures, 5 excluded (no regressions from Phase 1/2 baseline)
- [x] Task commits exist: `6abb048`, `fc25650`, `4de8841` (verified via `git log --oneline`)

---
*Phase: 03-agent-adapter-sandbox-dtu-safety*
*Completed: 2026-04-20*
