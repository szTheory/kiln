---
gsd_state_version: 1.0
milestone: v0.1.0
milestone_name: milestone
status: ready_to_plan
stopped_at: Phase 03 complete; Phase 04 is next
last_updated: "2026-04-21T12:45:00.000Z"
last_activity: 2026-04-21 -- /gsd-resume-work consumed HANDOFF.json; Phase 4 code on main ahead of STATE text
progress:
  total_phases: 10
  completed_phases: 3
  total_plans: 28
  completed_plans: 28
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-18)

**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.
**Current focus:** Phase 04 — agent-tree-and-shared-memory

## Current Position

Phase: 04 (agent-tree-and-shared-memory) — READY TO PLAN
Plan: 0 of TBD
Status: Phase 03 complete; Phase 04 not started
Last activity: 2026-04-20 -- 03-10/03-11 shipped, validated, and Phase 03 closed

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 28
- Average duration: ~19 min
- Total execution time: ~155 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1     | 7/7   | ~140m | ~20m     |
| 02    | 9/9   | -     | -        |
| 03    | 12/12 | -     | -        |

**Recent Trend:**

- Last 11 plans: 03-00 (~15m, feat), 03-01 (~7m, feat+test), 03-02 (~7m, feat+test), 03-03 (~8m, feat+migration), 03-04/05/06 (recovered Wave 2 worktree outputs, validated and merged), 03-07 (sandbox substrate), 03-08 (sandbox runtime recovery), 03-09 (DTU host-side recovery), 03-10 (stage auto-enqueue), 03-11 (application wiring)
- Trend: Phase 03 is complete. The runtime scaffolding, DTU sidecar, provider-secret gate, and workflow auto-enqueue are all in place; the next phase is the agent-session/work-unit layer.

*Updated after each plan completion.*
| Phase 02 P00 | ~7m | 2 tasks | 13 files |
| Phase 02 P01 | ~7min | 2 tasks | 14 files |
| Phase 02 P02 | ~6min | 2 tasks | 11 files |
| Phase Phase 02 P03 P~8min | 2 | 11 tasks | - files |
| Phase Phase 02 PP04 | ~5min | 2 tasks | 8 files |
| Phase 02 P07 | 9min | 3 tasks | 11 files |
| Phase Phase 02 PP08 | ~15min | 2 tasks | 8 files |
| Phase 03 P00 | ~15min | 3 tasks | 17 files |
| Phase 03 P04 | ~7min | 2 tasks | 6 files |
| Phase 03 P05 | recovered | 3 tasks | 18 files |
| Phase 03 P06 | recovered | 2 tasks | 24 files |
| Phase 03 P07 | ~wave-3 | 3 tasks | 19 files |
| Phase 03 P08 | recovered | 3 tasks | 5 files |
| Phase 03 P09 | recovered | 3 tasks | 7 files |
| Phase 03 P10 | ~wave-5 | 3 tasks | 4 files |
| Phase 03 P11 | ~wave-5 | 4 tasks | 8 files |

## Accumulated Context

### Decisions

Full decision log lives in PROJECT.md Key Decisions table. Roadmap-level decisions:

- Phase structure: 9 phases at standard granularity (SUMMARY's 8 + split operator-UX into Phase 7 core run UI and Phase 8 intake/ops/unblock/onboarding) — justified by expanded INTAKE/OPS/BLOCK/UI-07..09 scope
- Five HIGH-cost pitfalls (P2 cost runaway, P3 idempotency, P5 sandbox escape, P8 prompt injection, P21 secrets) treated as architectural invariants seeded in Phase 1, not features
- Zero-human-QA (UAT-01/02) and typed-block contract (BLOCK-01..04) are cross-cutting invariants; scenario runner is the sole acceptance oracle
- Phases 3, 4, 5 flagged HIGH for `/gsd-research-phase` before planning
- Plan 02-00 decisions: (a) SHELL-vs-LIVE factory discipline — live for workflow raw maps, shells with placeholder_*_attrs/0 markers for Run/StageRun/Artifact which Plans 02/03 fill; (b) Defensive Module.concat + Code.ensure_loaded + function_exported? indirection in Kiln.RehydrationCase + Kiln.StuckDetectorCase so case templates compile against Plan 02-00 codebase AND auto-activate once Plan 06 / Plan 07 ship their target GenServers — no arrow-dependency cross-plan edits required; (c) Kiln.CasTestHelper uses process-dict keyed by base directory for capture-and-restore of Application.get_env(:kiln, :artifacts) — prevents env-bleed across async tests without a global-state agent; (d) Block-list YAML syntax in cyclic.yaml (idiomatic for priv/workflows/*.yaml authoring) rather than inline [c] arrays — YamlElixir parses both identically; (e) SHELL factory moduledocs describe the eventual live ex_machina/Ecto shape using prose rather than inline use-directive examples, satisfying grep acceptance checks while preserving documentation intent
- Plan 02-01 decisions: (a) Audit schemas (3 new D-85 kinds) shipped payload-only matching Phase 1 convention, not full-envelope shape implied by plan spec text — Kiln.Audit.append/1 validates only the payload map; (b) verifying.json relaxes holdout_excluded to type boolean (not const true) per D-74 — verifier stages may run against the holdout set, the 4 other kinds enforce const: true structurally; (c) new registries' fetch/1 returns {:error, :unknown_kind}; Phase 1's Kiln.Audit.SchemaRegistry still returns :schema_missing (retrofit deferred); (d) migration down/0 hard-codes the original 22-kind list because reading EventKind at rollback time would observe the 25-atom current-source module attribute and make down a silent no-op; (e) Phase 2 registries opt in to JSV formats: true; Phase 1 Kiln.Audit.SchemaRegistry does not — deferred retrofit flagged by RESEARCH.md correction #1 / STACK.md D-100.
- Plan 02-02 decisions: (a) FK on_delete :restrict (D-81) validated at BOTH Ecto.ConstraintError path (Repo.delete!) AND raw Postgrex.Error path (Repo.query! bypass) — proves invariant holds regardless of caller surface; (b) Run factory ships realistic caps_snapshot (max_retries/max_tokens_usd/max_elapsed_seconds/max_stage_duration_seconds) and model_profile_snapshot defaults, not bare %{} — downstream Plan 06/07 and Phase 3 BudgetGuard tests benefit from realistic shapes; (c) StageRun factory leaves run_id: nil by design with moduledoc-documented caller contract — auto-inserting a parent run would hide FK dependency and produce orphan rows on build/1 without persistence; (d) StageRun changeset pre-wires all 6 check_constraints (kind/agent_role/state/sandbox/attempt/cost_usd) so a raw attrs-drift Repo.insert bypass still surfaces clean changeset errors — defence-in-depth mirroring Phase 1 Kiln.ExternalOperations.Operation; (e) Both migrations use def change (reversible) with 2-arg execute/2 for every DDL escape — migrate → rollback --step 2 → migrate round-trip verified clean
- Plan 02-03 decisions: (a) test-env CAS paths made STABLE (not per-invocation-unique) after System.unique_integer hit :validate_compile_env at boot — content-addressed dedup makes stable paths safe; (b) Kiln.CasTestHelper (Plan 02-00) not used by CAS tests since CAS uses Application.compile_env which ignores runtime put_env — helper retained for future non-CAS consumers; (c) append-only grant pattern applied second time (mirrors audit_events); (d) Repo.transact/2 (Ecto 3.13 new API) preferred over Repo.transaction/1 for put/4's CAS+row+audit atomicity — cleaner {:ok, val}/{:error, reason} contract; (e) audit-before-raise in read!/1 ensures integrity_violation forensic record survives caller rescue handler; (f) artifact_factory leaves stage_run_id + run_id nil by design (mirrors StageRun factory FK-visibility pattern)
- Plan 02-04 decisions: (a) Raised pool_size in both config/runtime.exs (:prod) and config/dev.exs to 20 — plan text targeted runtime.exs only, but the D-68 budget math has to hold at dev runtime too since dev.exs carries the P1 pool_size:10 that runs the real solo-op local loop; (b) Placed check_oban_queue_budget!/0 4th in the BootChecks invariant chain (contexts→revoke→trigger→oban_queue_budget→secrets) — groups the audit-ledger invariants thematically; Plan 07 will insert workflow_schema_loads near this slot; (c) Did NOT extend BootChecks.@context_modules to 13 in this plan — Plan 07 Task 2 owns the paired SSOT update (BootChecks list + Mix task @expected) to keep them in lockstep; (d) Broke Mix task @expected to one-module-per-line so grep -c "Kiln\." returns 20 (>= 13 acceptance threshold); (e) Rewrote a 'do NOT pass atoms: true' comment to avoid the literal trigger string — future defense-in-depth grep gates (threat-model T3) depend on literal absence
- Plan 02-07 decisions: (a) Kiln.Runs.RunSubtree ships with a Task.Supervisor lived-child in Phase 2 — the ORCH-02 integration test (checker issue #1 mandatory) needs a real killable pid; deferring would regress the checker fix; Phase 3's swap to Kiln.Agents.SessionSupervisor + Kiln.Sandboxes.Supervisor is a one-line init/1 child-list change with contract (strategy/restart/name/budget) preserved; (b) lived_child_pid/1 exposes via Registry lookup O(1) rather than Supervisor.which_children/1 scan; (c) RunDirector runs as live singleton across MIX_ENV=test (:permanent :one_for_one child of Kiln.Supervisor); tests interact with live singleton + per-test RunSupervisor cleanup via DynamicSupervisor.terminate_child/2 loop gives deterministic state; (d) D-94 treats missing workflow file identically to checksum mismatch — one typed :workflow_changed reason covers both; (e) handle_info/2 catch-all clause added (Rule 3 defensive) so :permanent director doesn't crash-loop on stray messages; (f) test/kiln_web/health_plug_test.exs auto-updated 12 -> 13 (Rule 1) — D-97 spec upgrade drifted /health probe payload; (g) deferred-activation CI gate pattern fully realised: Plan 02-04 shipped mix check_bounded_contexts source with deferred activation, Plan 02-07 extended BootChecks @context_modules 12 -> 13 in lockstep; canonical pattern for Wave-1 scaffolding gates paired with Wave-M SSOT
- Plan 02-08 decisions: (a) Pass content_type to Artifacts.put/4 as atom :"text/markdown" not string — sidesteps String.to_existing_atom lookup when Kiln.Artifacts.Artifact module not pre-loaded (D-63 atom-exhaustion defence vs module load order); (b) Guard Kiln.Telemetry.unpack_ctx/1 on kiln_ctx map_size > 0 — empty ctx would clobber test-process Logger.metadata with :none atoms, breaking downstream Audit.append correlation_id cast; applies to every future Oban worker; (c) Wrap JSV.normalize_error/1 as [stringify_map(err)] for :stage_input_rejected audit payload — audit schema declares errors: array<object>, normalize_error returns single map; (d) Inline stage_run_id/reason into Logger.error message string — stays within 6 D-46 canonical metadata keys; (e) End-to-end test drives 4 non-merge stages via explicit for-loop — CONTEXT.md <deferred> moved auto-enqueue to Phase 3 per checker issue #8 option (a); (f) LOCKED StageWorker transition mapping encoded in 4 explicit function heads + :merge no-op catch-all — zero executor discretion per checker #3; (g) rehydration test uses Kiln.RehydrationCase.reset_run_director_for_test/0 + send(RunDirector, :boot_scan) + Process.sleep(300) as BEAM-kill simulation — mix test can't kill the VM cleanly; resending :boot_scan to the live singleton exercises the same rehydration path a cold boot would.
- Plan 03-00 decisions: (a) `ex_docker_engine_api ~> 1.43` (not `~> 7.0` as plan text specified) — hex package is versioned against the Docker Engine API revision it targets (published as 1.43.x for Docker Engine 24+/25+), not abstract semver; Rule 1 deviation documented in commit `6abb048`; (b) Unlocked idna 7.1.0 → 6.1.1 (Rule 3 blocker): hackney transitive via ex_docker_engine_api requires `idna ~> 6.1.0`; jsv accepts `~> 6.0 or ~> 7.0`, so the 6.1.1 pick satisfies both; (c) Mox defmock deferred-activation pattern: plan assumed `Mox.defmock/2` tolerates absent target behaviours, Mox 1.2 actually calls `Code.ensure_compiled!/1` at defmock time — wrapped each defmock in `unless Code.ensure_loaded?(mock_name)` + `if Code.ensure_loaded?(target)` with placeholder-module fallback so Wave 0 compiles before Wave 2/4 ship the behaviours (Rule 1 deviation); (d) Idempotency guard around entire `test/support/mocks.ex` body: `test/support/` is an `elixirc_paths(:test)` entry, so the file's top-level code executes once at `mix compile` time + a second time when `test_helper.exs` does `Code.require_file` — wrapping the whole body in `unless Code.ensure_loaded?(Kiln.TestMocks)` makes the second load a no-op and satisfies the plan's `Code.require_file` acceptance criterion while staying warnings-clean under `--warnings-as-errors`; (e) Committed (not gitignored) `test/support/fixtures/secrets/fake_keys.exs` per plan Task 3 paragraph-ending "Decision: commit the fixture file; do NOT gitignore" — moduledoc comments make the "not real" nature explicit and every value contains the `FAKE` marker substring; (f) Placed mocks smoke test at `test/support/mocks_test.exs` (not `test/kiln/`) because the plan acceptance command specifies that literal path — `mix test <path>` accepts an explicit `.exs` file regardless of discovery root.
- Plan 03-04 decisions: (a) `FactoryCircuitBreaker` copied the `StuckDetector` scaffold exactly so Phase 5 can fill only the `handle_call/3` body; (b) notifications validate blocker reasons before shell-out and always write either `notification_fired` or `notification_suppressed`; (c) dedup state lives in an ETS table owned by `Kiln.Notifications.DedupCache`, with `:ets.whereis/1` guards protecting restart and teardown windows.
- Plan 03-05 decisions: (a) Anthropic is the only live provider in Phase 3, with OpenAI/Google/Ollama shipped as compiling scaffolds behind the same behaviour; (b) provider-agnostic prompt/response structs are intentionally narrow and keep metadata out of generic JSON encoding; (c) `SessionSupervisor` ships now as the stable ownership seam for the Phase 4 agent tree.
- Plan 03-06 decisions: (a) `Kiln.ModelRegistry.next/3` is deterministic by role order so fallback walks are stable and auditable; (b) `BudgetGuard` has no override and writes audit before raising `Kiln.Blockers.BlockedError`; (c) `BudgetGuard` only calls notifications when the dedup ETS table is live, preserving the current Phase 3/11 wiring boundary; (d) `TelemetryHandler` writes `model_routing_fallback` only on `:stop` mismatch events and leaves `:start` / `:exception` as accepted no-ops in Phase 3.
- Plan 03-07 decisions: (a) sandbox image metadata, limits, and image lock data ship as pure substrate before driver wiring; (b) `EnvBuilder` treats secret-shaped names and non-allowlisted names as separate failure modes while still failing closed; (c) `Hydrator` resolves artifact refs by SHA through the CAS APIs, and `Harvester` writes back through `Kiln.Artifacts.put/4` so audit emission stays on the existing artifact path.

### Plan 01-01 decisions

- Scaffold via `mix phx.new` in a tempdir + `rsync` into the repo to preserve `.planning/`, `prompts/`, `CLAUDE.md`
- DNSCluster fully removed (dep + child + config line) — LOCAL-01 targets single-node local deploy
- `MIX_TEST_PARTITION` read moved from `config/test.exs` → `config/runtime.exs` to satisfy T-02 (no env reads at compile time)
- `.env.sample` allowlisted via `!.env.sample` in `.gitignore`
- Oban migration version pinned at 13 (per deps/oban 2.21.1) — Plan 04 to hardcode

### Plan 01-07 decisions

- D-50: CLAUDE.md Conventions now cite the D-12 three-layer INSERT-only defense (REVOKE + `audit_events_immutable()` trigger + RULE no-op) instead of the RULE-only claim
- D-51: ARCHITECTURE.md section 9 renamed `events` → `audit_events`; schema aligned to the Plan 03 shape (event_kind Ecto.Enum, schema_version, stage_id, autogenerate: false PK); SQL example replaced with the D-12 three-layer enforcement + five D-10 composite indexes; narrative paragraph rewritten to cite the RULE silent-bypass rationale; classify_event/1 examples updated from event_type strings to event_kind atoms
- D-52: STACK.md documents `pg_uuidv7` Postgres extension (ghcr.io/fboulnois/pg_uuidv7:1.7.0 image pin, uuid_generate_v7(), PG 18 native-uuidv7() migration path, kjmph pure-SQL fallback); compose-snippet annotated rather than rewritten so the reference pattern stays intact
- D-53: version drift eliminated from research docs — PROJECT.md already carried `Elixir 1.19.5+/OTP 28.1+`, so ARCHITECTURE.md (2 hits) + STACK.md (4 hits) + SUMMARY.md (2 hits) were aligned to it; two "stale items" paragraphs rewritten as resolved
- D-51 scope boundary respected: ARCHITECTURE.md line 143's `Kiln.Audit` public-API description still says `event_type` (outside section 9); logged as a deferred cross-reference for a future audit plan

### Plan 01-02 decisions

- xref cycles uses `--label compile-connected` (Elixir xref docs best practice); the Phoenix scaffold has harmless runtime cycles between router/endpoint/controllers/layouts that don't cause recompilation pain — compile-connected cycles are the recompile tax we care about for the 12-context DAG
- `:credo` added to Dialyzer `plt_add_apps` because `lib/kiln/credo/*` modules `use Credo.Check`; without it Dialyzer flags 9 "unknown function" errors despite Credo being `runtime: false`
- Custom Credo checks compiled as normal project code (no `requires:` list in `.credo.exs`) — adding the list caused "redefining module" warnings because Credo evaluated the file twice
- Sobelow baseline intentionally non-empty at P1 — Phoenix scaffold `:browser` pipeline ships without a CSP plug; Phase 7 (UI) adds the real CSP and removes the `.sobelow-skips` entry
- `mix deps.unlock --unused` required to pass ex_check's `unused_deps` tool — Plan 01-01 removed `:dns_cluster` from mix.exs but didn't clean mix.lock; one-time cleanup
- All 23 ex_slop checks enabled (full default set) — the P1 scaffold was clean after the Task 2 Rule-3 fixups; revisit in Phase 9 dogfood if noisy

### Plan 01-05 decisions

- **LoggerJSON.Formatters.Basic JSON shape:** metadata nested under a top-level `"metadata"` object (not flattened). Top-level keys are `time` (ISO 8601 UTC ms), `severity`, `message`, `metadata`. Plan 06 HealthPlug JSON emission and every log-asserting test in Phases 2-9 should read via `line["metadata"][key] || line[key]` (works against `Basic` today + flat-metadata formatters like `GoogleCloud`/`Datadog` tomorrow).
- **`Kiln.Logger.Metadata.default_filter/2` ships (not skipped).** `take_metadata/2` inside `LoggerJSON.Formatters.Basic` uses `Map.take/2`, which omits absent keys — without the filter, missing keys would not appear in JSON (inconsistent schema). Filter `Map.put_new`s `:none` atom for each of the six D-46 keys; Jason serialises to `"none"` string.
- **Oban test mode = `testing: :manual` + `perform_job/2`**, NOT `:inline` (can bypass `[:oban, :job, :start]` telemetry in some Oban 2.21 paths) and NOT `drain_queue/1` (requires Oban migrations — those land in Plan 01-04). `perform_job/2` executes via `Executor.call/1` synchronously in the test process and DOES fire the telemetry event (verified in `deps/oban/lib/oban/queue/executor.ex:97`). LOG-02's proof: clear test-process `Logger.metadata` BEFORE `perform_job`, so a passing assertion means the `ObanHandler` restored ctx.
- **Primary-level logger lift inside `capture_json/1`.** `config/test.exs` sets `level: :warning` to quiet dev-noise; Erlang's logger primary filter drops `:info` events before any handler sees them. `capture_json/1` snapshots `:logger.get_primary_config()`, sets level to `:all`, restores in `after`. Alternative (use `Logger.warning` everywhere in tests) rejected as fragile + fights OBS-01's intent.
- **`Kiln.Telemetry.ObanHandler` attaches via `:telemetry.attach_many/4`, NOT as a supervision-tree child.** Telemetry handlers are ETS-backed, not process-backed. Attach happens in `Kiln.Application.start/2` post-`Supervisor.start_link`; matching detach in `stop/1`. Supervision tree stays at exactly 7 children (D-42 invariant preserved).
- **`:logger` callback fns (`log/2`, `adding_handler/1`, `removing_handler/1`, `changing_config/3`) MUST be public.** Erlang dispatches by MFA. ex_slop's `DocFalseOnPublicFunction` trips on `@doc false` on public fns — resolution is to give each callback a real `@doc` string explaining the Erlang contract. Established the pattern in `test/support/logger_capture_helper.ex` for any future Erlang callback modules.

### Plan 01-04 decisions

- @oban_migration_version = 14 (not 12 from plan text, not 13 from Plan 01-01 SUMMARY). Verified against `deps/oban/lib/oban/migrations/postgres.ex` `@current_version 14`. D-49 mandates pinning; the integer is whatever current Oban version exposes.
- Kept the two uncommitted migration files left by a prior stalled agent attempt after cross-checking against plan spec. Files matched the plan + added reversibility niceties (reversible CHECK + owner transfer + grants via `execute/2`) consistent with 01-03's patterns. Avoided ~10 tool calls of unnecessary rewrite.
- 30-day TTL pruner registered via `Oban.Plugins.Cron` crontab in `config/config.exs`, NOT as a new supervision-tree child — keeps D-42 7-child invariant.
- Pruner uses `SET LOCAL ROLE kiln_owner` inside its `Repo.transaction` to escalate DELETE privilege (T-03 mitigation keeps kiln_app without DELETE on `external_operations`). Same mechanism as `AuditLedgerCase.with_role/2` from Plan 01-03; LOCAL scope auto-resets role on txn commit.
- `Kiln.Oban.BaseWorker` is a `__using__/1` macro (NOT a shared behaviour). Macro expansion at compile time injects safe defaults per-worker; callers override via `use Kiln.Oban.BaseWorker, max_attempts: 5` — `Keyword.put_new` means explicit opts always win.
- `fetch_or_record_intent/2` uses Brandur's `INSERT ... ON CONFLICT DO NOTHING` + `SELECT FOR UPDATE` fallback. When conflict hits, Ecto returns `%Operation{id: nil}` because no RETURNING row; the fallback `SELECT` observes the winner deterministically. Operation PK uses `read_after_writes: true` so first-winner path hydrates `id` automatically.
- BaseWorker test uses `Worker.__opts__/0` introspection (documented `@callback __opts__` at `deps/oban/lib/oban/worker.ex:464`) for max_attempts/unique assertions. Rejected brittle alternatives like changeset-data inspection or perform-job-observes-opts.

### Plan 01-06 decisions

- **Audit-mutation probe uses SAVEPOINT + ROLLBACK TO SAVEPOINT**, not a naive try/rescue inside Repo.transaction. The initial design failed: a deliberately-failing UPDATE puts Postgres in ABORT state (SQLSTATE 25P02), so the next COMMIT returns `{:error, :rollback}` and the probe misreports as a connectivity failure. SAVEPOINT restores a runnable state after the catch; `Repo.rollback(outcome)` cleanly unwinds the outer txn. Works identically in sandboxed tests and fresh boot connections.
- **BEFORE UPDATE triggers are per-row** — `UPDATE audit_events WHERE FALSE` matches zero rows, so the trigger never fires and `:audit_trigger_active` would falsely report "invariant violated" on every healthy boot. Fix: INSERT a throwaway `stage_started` row inside the probe's SAVEPOINT first, then UPDATE it. Outer `Repo.rollback` ensures the INSERT never lands.
- **9 P1 stub context modules** (Specs, Intents, Workflows, Runs, Stages, Agents, Sandboxes, GitHub, Policies) shipped empty (@moduledoc-only) rather than deferred to owning phases. Pins the 12-context naming SSOT at P1 per D-42 so Phase 2+ can't silently drift. Each stub's docstring names the phase it activates in.
- **Staged Application.start/2** uses `Supervisor.start_link` with 6 infra children → `Kiln.BootChecks.run!/0` → `ObanHandler.attach/0` → `Supervisor.start_child(..., KilnWeb.Endpoint.child_spec([]))`. Post-boot `Supervisor.which_children/1` returns EXACTLY 7 entries. A panic during BootChecks leaves a 6-child tree (still healthy, Repo+Oban both running) rather than a partial 7-child tree. Asserted by test/kiln/application_test.exs.
- **`Kiln.Credo.NoMixEnvAtRuntime` exempts `config/*.exs`** via `Path.split/1` + `"config" in segments`. Same compile-time exemption class as `mix.exs`. Enables `config :kiln, :env, Mix.env()` in config/config.exs so BootChecks can dispatch secrets checks on :dev vs :prod without re-reading Mix.env at runtime (CLAUDE.md anti-pattern).
- **Dialyzer tight types shipped for BootChecks + HealthPlug** — `@type context_module` as a union of the 12 specific modules eliminates the `contract_supertype` warning on `context_modules/0`; `@type health_payload :: %{required(String.t()) => String.t() | non_neg_integer()}` pins the D-31 JSON shape so a future drift (e.g., adding a bool key) surfaces as a Dialyzer mismatch, not a silent contract break.
- **`KILN_SKIP_BOOTCHECKS=1` is the SOLE escape hatch** per D-33. No verbose mode, no per-invariant skip flags. The log line is grep-friendly (`grep KILN_SKIP_BOOTCHECKS /var/log/kiln.log` surfaces every bypass). A richer API would encourage normalising the bypass.
- **first_run.sh probes host port 5432 before `docker compose up`** via `lsof` + `docker ps`. Pre-existing `sigra-uat-postgres` container on this dev host is detected and the script fails fast with two remediation options. Operator action unblocks in seconds rather than debugging a cryptic bind error deep in compose.

### Plan 01-03 decisions

- D-12 Layer 3 RULE shipped **DISABLED** by default (Rule 1 deviation from plan spec). Postgres query rewriting runs BEFORE triggers fire — an active `DO INSTEAD NOTHING` RULE masks Layer 2's trigger. Disabled RULE keeps Layer 2 the loud error path; AUD-03 test enables the RULE explicitly to verify it works.
- Migration 1 ships a kjmph pure-SQL `uuid_generate_v7()` fallback when `pg_uuidv7` extension is unavailable (Rule 3 deviation). Probe via `pg_available_extensions` with `@disable_ddl_transaction true` — rescue inside a migration transaction doesn't work (25P02 aborts). Fallback path sanctioned by CONTEXT.md D-06 canonical refs.
- `config/runtime.exs` KILN_DB_ROLE → Postgrex :parameters wiring is **conditional on env-var presence**. Unset = no SET ROLE; keeps `mix ecto.drop`/`create` on pre-migration-2 DB from failing with "role kiln_app does not exist".
- `audit_events` ownership transferred to kiln_owner via `ALTER TABLE OWNER TO` inside migration 3 — keeps DDL authority centralized even when bootstrap runs `mix ecto.migrate` as connecting superuser.
- `Kiln.Audit.Event` needs `read_after_writes: true` on its UUID v7 PK so Ecto fetches the Postgres-generated default `uuid_generate_v7()` id back to the struct after INSERT.
- `Kiln.Audit.append/1` uses `Map.put_new_lazy` (not `Map.put_new`) for correlation_id fallback — eager `put_new` evaluates the Logger-fetching function even when the key is already present, producing spurious ArgumentErrors.
- Postgrex 0.22.0 `err.postgres.code` is the atom `:insufficient_privilege` for SQLSTATE 42501 (not the string `"42501"`). Trigger uses `USING ERRCODE = 'feature_not_supported'` (0A000) so catching code can discriminate trigger errors from CHECK and privilege errors.

### Pending Todos

From .planning/todos/pending/ — ideas captured during sessions.

None yet.

### Blockers/Concerns

**BLOCKER — operator environment (Plan 01-01 verification):** Host port 5432 held by pre-existing `sigra-uat-postgres` Docker container. Prevented running `docker compose up -d db && mix ecto.create && mix ecto.migrate && mix test` during Plan 01-01 execution. Static acceptance criteria all pass; DB smoke deferred to operator next session (stop the conflicting container or run Kiln compose with alternate host port).

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Verification | `docker compose up -d db` under Kiln's own compose (port 5432 conflict with sigra-uat-postgres). All Plan 01-03 verification passed via kjmph pure-SQL fallback + sigra's `kiln` user; operator action still required to switch to Kiln's `pg_uuidv7` image path before Phase 2. | Operator action required | 2026-04-19 (Plan 01-01; revalidated 01-03) |
| Doc cross-reference | ARCHITECTURE.md line 143 `Kiln.Audit` context description still lists `event_type` filter (section 9 now uses `event_kind`) | Future bounded-context doc audit | 2026-04-18 (Plan 01-07; D-51 scope was section-9-only) |

## Session Continuity

Last session: 2026-04-21 -- resumed via `/gsd-resume-work` (structured handoff consumed; see git history if needed)
Stopped at: Normalize Phase 4 — untracked `04-*-PLAN.md` / `04-REVIEW.md` / `04-PATTERNS.md` vs `main`; then `/gsd-research-phase 4` (HIGH) or `/gsd-plan-phase 4` per ROADMAP
Resume file: `.planning/phases/04-agent-tree-shared-memory/.continue-here.md`
Next command: Triage uncommitted planning files, then `/gsd-research-phase 4` (or `/gsd-plan-phase 4` if research already done)

**Completed Phase:** 3 (Agent Adapter, Sandbox, DTU & Safety) — 12 plans — completed 2026-04-20

**Note:** Phase 5 discuss output is on `main` (`.planning/phases/05-spec-verification-bounded-loop/05-CONTEXT.md`); execution order remains Phase 4 before Phase 5 unless explicitly reprioritized.
