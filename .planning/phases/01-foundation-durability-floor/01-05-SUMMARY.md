---
phase: 01-foundation-durability-floor
plan: 05
subsystem: observability
tags: [logger, logger_json, telemetry, metadata, oban, task-async-stream, obs-01]

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor/01
    provides: "logger_json 7.0.4 dep + LoggerJSON formatter metadata whitelist + D-42 7-child supervision tree"
  - phase: 01-foundation-durability-floor/02
    provides: "mix check 11-tool gate including Kiln.Credo.NoProcessPut (blocks the banned Process.put/2 transport alternative)"
  - phase: 01-foundation-durability-floor/03
    provides: "Kiln.Audit.append/1 auto-fills correlation_id from Logger.metadata — the metadata threaded by this plan flows into audit events for free"
provides:
  - "`LoggerJSON.Formatters.Basic` active on `:default_handler` — every log line is JSON with top-level `time`/`severity`/`message` + nested `metadata` object carrying the six D-46 mandatory keys"
  - "`Kiln.Logger.Metadata.with_metadata/2` — block decorator for scoping synchronous code; try/after restores prior metadata even on raise; nested calls compose"
  - "`Kiln.Logger.Metadata.default_filter/2` — `:logger` filter wired in `config/config.exs` that defaults the six D-46 keys to the atom `:none` (renders `\"none\"` in JSON) when absent"
  - "`Kiln.Telemetry.pack_ctx/0` + `unpack_ctx/1` — serialisable context snapshot for cross-process threading; normalises `\"none\"` ↔ `:none` through JSONB round-trip"
  - "`Kiln.Telemetry.async_stream/3` — drop-in `Task.async_stream` wrapper that pre-packs ctx into every child closure (LOG-01)"
  - "`Kiln.Telemetry.pack_meta/0` — returns `%{\"kiln_ctx\" => ctx}` map for Oban `Job.meta` at enqueue time (LOG-02 enqueuer-side)"
  - "`Kiln.Telemetry.ObanHandler` — `:telemetry` handler on `[:oban, :job, :start|:stop]`; restores `job.meta[\"kiln_ctx\"]` into worker Logger.metadata (LOG-02 worker-side)"
  - "`Kiln.LoggerCaptureHelper.capture_json/1` — test helper that attaches a per-test `:logger` handler wired to `LoggerJSON.Formatters.Basic` and forwards formatted lines to the test process as JSON-decoded maps; works around `ExUnit.CaptureLog`'s plain-text-only formatter"
  - "D-47 contrived multi-process test — mechanically proves OBS-01 by asserting `correlation_id` matches parent on Task.async_stream children AND Oban `perform/1` log lines in the same run"
affects:
  - 01-04 (`Kiln.Oban.BaseWorker` — will wrap `Kiln.Telemetry.pack_meta/0` into a default `new/2` so every BaseWorker-enqueued job carries ctx automatically)
  - 01-06 (BootChecks — may assert the Oban telemetry handler is attached as a 6th invariant)
  - Phase 2+ (every run/stage logs through this pipeline; every `Audit.append/1` picks up `correlation_id` from `Logger.metadata` wired by `Kiln.Logger.Metadata.with_metadata/2`)
  - Phase 3 (P3 LLM-call logging — every token-usage log line carries the right correlation_id end-to-end)
  - Phase 6 (GitHub operations — every git/gh-CLI operation log line is traceable back to the run that emitted it)

# Tech tracking
tech-stack:
  added: []  # logger_json 7.0.4 dep already installed in Plan 01-01
  patterns:
    - "Primary-level logger floor (config/test.exs sets :warning) must be lifted inside capture_json/1 to :all and restored after — :info lines in D-47 tests would otherwise be filtered before reaching any handler"
    - "Custom :logger handler module for test capture — ExUnit.CaptureLog's plain-text-only formatter cannot exercise JSON; attach_handler with __MODULE__ as the callback module + LoggerJSON.Formatters.Basic gives per-test JSON capture"
    - "Handler-ID must be an atom — {:atom, ref()} tuples raise :invalid_id; use `:\"#{prefix}_#{unique_int}\"` pattern"
    - "Telemetry handlers attached via :telemetry.attach/4 in Application.start/2 (after Supervisor.start_link) — NOT as supervision-tree children — keep D-42's 7-child invariant"
    - "Oban `testing: :manual` + `perform_job/2` is the right test mode for telemetry-handler verification — :inline can bypass telemetry in some Oban 2.21 paths, and drain_queue would require the Oban migration (01-04 ships it)"

key-files:
  created:
    - "lib/kiln/logger/metadata.ex"
    - "lib/kiln/telemetry.ex"
    - "lib/kiln/telemetry/oban_handler.ex"
    - "test/support/logger_capture_helper.ex"
    - "test/kiln/logger/metadata_test.exs"
    - "test/kiln/telemetry/metadata_threading_test.exs"
  modified:
    - "config/config.exs (LoggerJSON.Formatters.Basic on :default_handler + default_filter wired)"
    - "config/test.exs (Oban testing: :manual for deterministic perform_job in metadata-threading test)"
    - "lib/kiln/application.ex (attach Kiln.Telemetry.ObanHandler after Supervisor.start_link; matching detach in stop/1; alias added for Credo AliasUsage)"

key-decisions:
  - "LoggerJSON.Formatters.Basic metadata keys render NESTED under a top-level `\"metadata\"` JSON object (not flattened to top-level) — confirmed empirically against formatter source `take_metadata/2`. This is the shape Plan 06 HealthPlug JSON emission and every future log-asserting test consumes. Plan 06's HealthPlug will match by using `line[\"metadata\"][key] || line[key]` read pattern (also the pattern used in both test files here for robustness against a future formatter swap)."
  - "Default-filter SHIPPING (not skipped). `take_metadata(meta, [keys])` uses `Map.take/2` internally, which OMITS missing keys rather than defaulting them — without the filter, absent keys would simply not appear in JSON output (inconsistent schema). `Kiln.Logger.Metadata.default_filter/2` runs before the formatter and `Map.put_new`s `:none` atom for each of the six keys that's missing. The atom serialises to the string `\"none\"` via Jason's Atom handling. Result: consistent schema on every line."
  - "Oban test mode = `testing: :manual` + `perform_job/2` (not `:inline` and not `drain_queue/1`). :inline can bypass the [:oban, :job, :start] telemetry event in some Oban 2.21 executor paths (Executor.call's record_started fires telemetry, but the :inline path occasionally short-circuits via Oban.insert/2). drain_queue requires the Oban migrations (oban_jobs table) — those land in Plan 01-04 which runs after this plan. perform_job executes via Executor.call synchronously in the test process, which DOES fire [:oban, :job, :start] (verified in deps/oban/lib/oban/queue/executor.ex:97). LOG-02 proves the handler is load-bearing by clearing the test process's Logger.metadata BEFORE perform_job — a successful assertion means the handler restored ctx from job.meta."
  - "primary-level lift inside capture_json/1. config/test.exs sets `config :logger, level: :warning` to quiet dev-noise during mix test. Erlang's logger applies the primary level as the first filter — :info events are dropped before reaching any handler, so capture_json's custom handler would see nothing. The helper snapshots `:logger.get_primary_config()`, sets level to `:all`, runs the capture, and restores the prior level in `after`. Alternative considered (and rejected): require all tests to call `Logger.warning` instead of `Logger.info` — fragile, easy to forget, fights OBS-01's intent (production emits at :info for normal lifecycle events)."
  - "Handler callbacks are public (not @doc false). ex_slop's DocFalseOnPublicFunction check trips on `@doc false` on public defs because that pattern usually indicates a module API leak. But `:logger` REQUIRES the callback module's `log/2`, `adding_handler/1`, `removing_handler/1`, `changing_config/3` to be public (Erlang dispatches by MFA). Resolution: document each callback with a real @doc string explaining the :logger contract. Module-level @moduledoc clarifies that only `capture_json/1` is caller-facing."

patterns-established:
  - "JSON-capture test pattern — `{result, lines} = capture_json(fun)`, then `lines |> Enum.find(message_matcher) |> get_metadata(key)`. Every log-asserting test in Phases 2-9 uses this helper."
  - "cross-process ctx threading contract — pack at the boundary (`pack_ctx` for Task, `pack_meta` for Oban), unpack as soon as possible inside the child (`async_stream` does it automatically; ObanHandler does it before perform/1 runs). No inline `Process.put`/`Process.get` for transport — Kiln.Credo.NoProcessPut blocks that path at CI (Plan 02)."
  - "`Logger.reset_metadata(prior)` for block-scope restoration — this replaces the WHOLE metadata list (not a merge); pairs with `Logger.metadata()` to capture-and-restore the prior full state. Distinct from `Logger.metadata(new_meta)` which MERGES."
  - "Oban meta JSONB round-trip forces `\"none\"` string representation — the atom `:none` packed at enqueue becomes `\"none\"` after Postgres JSONB serialisation. `Kiln.Telemetry.unpack_ctx/1` normalises `\"none\"` back to `:none` so formatters see a consistent shape whether the ctx took the in-memory Task path or the persisted Oban path."

requirements-completed: [OBS-01]

# Metrics
duration: ~15min
completed: 2026-04-19
---

# Phase 01 Plan 05: logger_json + D-45 metadata-threading spine Summary

**Structured JSON logging via `LoggerJSON.Formatters.Basic` on Erlang's `:default_handler`; the D-45 dual API (`Kiln.Logger.Metadata.with_metadata/2` block + `Kiln.Telemetry.{pack_ctx, unpack_ctx, async_stream, pack_meta}` cross-process + `Kiln.Telemetry.ObanHandler` on `[:oban, :job, :start]`) threading the six D-46 mandatory metadata keys onto every log line whether emitted from the main process, a `Task.async_stream` child, or an Oban `perform/1`; the D-47 contrived multi-process test proves OBS-01 mechanically.**

## Performance

- **Duration:** ~15 min (wall clock)
- **Started:** 2026-04-19T04:09:20Z
- **Completed:** 2026-04-19T04:22:00Z (approximate)
- **Tasks:** 2/2
- **Files created/modified:** 6 new + 3 modified (9 total)

## Accomplishments

- **LoggerJSON formatter active end-to-end.** `config/config.exs` installs `LoggerJSON.Formatters.Basic` on `:default_handler` with the six D-46 keys whitelisted + `Kiln.Logger.Metadata.default_filter/2` defaulting missing keys to `"none"` — verified by smoke test (`mix run -e 'Logger.info(...)'` emits JSON with all six keys present).
- **D-45 dual API shipped and covered.** `Kiln.Logger.Metadata.with_metadata/2` for synchronous block scope (try/after restore + compose on nesting), `Kiln.Telemetry.{pack_ctx, unpack_ctx, async_stream, pack_meta}` for cross-process threading.
- **`Kiln.Telemetry.ObanHandler` attached at boot** in `Kiln.Application.start/2` (post-`Supervisor.start_link`, NOT as a supervised child — telemetry handlers are ETS-backed). Idempotent attach; matching `detach/0` in `Application.stop/1`. **Supervision tree stays at exactly 7 children** (D-42 invariant preserved).
- **D-47 contrived multi-process test passing (OBS-01 proof).** Three assertions in `test/kiln/telemetry/metadata_threading_test.exs`:
  - **LOG-01** — `Task.async_stream` children inherit parent `correlation_id` (via wrapper's pre-packed closure). 3 child log lines asserted.
  - **LOG-02** — Oban `perform/1` inherits enqueue-time `correlation_id` (via `job.meta["kiln_ctx"]` unpacked by `ObanHandler`). Test clears `Logger.metadata` BEFORE `perform_job/2` so a passing assertion mechanically proves the handler restored ctx.
  - **D-47 combined** — both paths in one run, both log lines carry the same parent correlation_id.
- **`Kiln.LoggerCaptureHelper.capture_json/1`** — attaches a per-test `:logger` handler wired to `LoggerJSON.Formatters.Basic`, parses output as JSON, and returns decoded maps. `ExUnit.CaptureLog` cannot be used because it installs its own plain-text-only formatter; this helper is the required-tool alternative.
- **`mix check` green across all 11 tools** (formatter, compiler, ex_unit, credo, dialyzer, sobelow, mix_audit, xref_cycles, no_compile_secrets, no_manual_qa, unused_deps).
- **44 tests pass** (37 prior + 4 metadata behavior + 3 threading behaviors). Plan 01-03's audit ledger tests all still green (regression check).

## Task Commits

Each task committed atomically:

1. **Task 1: logger_json config + Kiln.Logger.Metadata + Kiln.Telemetry + ObanHandler + Application attach** — `5888aac` (feat)
2. **Task 2: Contrived multi-process D-47 test + metadata_test + LoggerCaptureHelper** — `0a5ba87` (test)

Plan metadata commit follows this SUMMARY.

## Output Answers (per plan's `<output>` section)

- **JSON shape produced by logger_json 7.0.4.** `LoggerJSON.Formatters.Basic` emits JSON with **top-level** `time` (ISO 8601 UTC ms precision), `severity` (lowercased level string), `message`, and a nested `metadata` object carrying the whitelisted keys. Example from smoke test:

  ```json
  {
    "message": "test",
    "time": "2026-04-19T04:14:51.314Z",
    "metadata": {
      "correlation_id": "abc-123",
      "causation_id": "none",
      "actor": "none",
      "actor_role": "none",
      "run_id": "none",
      "stage_id": "none"
    },
    "severity": "info"
  }
  ```

  **Metadata is nested under `"metadata"` (not flattened).** Plan 06 HealthPlug JSON emission and every future log-asserting test should read through `line["metadata"][key] || line[key]` (the pattern used in both test files here) for robustness against a future formatter swap (e.g. to `GoogleCloud` or `Datadog` which flatten).

- **Default-filter status: SHIPPING.** `Kiln.Logger.Metadata.default_filter/2` is wired in `config/config.exs` under `filters:`. Required because `LoggerJSON.Formatters.Basic`'s `take_metadata/2` uses `Map.take/2` internally — absent keys are simply omitted from the output, producing an inconsistent schema. The filter `Map.put_new`s `:none` atom for each of the six keys that's missing. Jason serialises `:none` → `"none"` string, giving grep pipelines the consistent-schema guarantee.

- **Oban testing mode: `:manual` + `perform_job/2`.** Not `:inline` (can bypass `[:oban, :job, :start]` telemetry in some Oban 2.21 executor paths). Not `drain_queue/1` (requires `oban_jobs` table — the Oban migration lands in Plan 01-04). `perform_job/2` executes via `Executor.call/1` synchronously in the test process and DOES fire the telemetry event (verified in `deps/oban/lib/oban/queue/executor.ex:97`). LOG-02 proves the handler is load-bearing by clearing `Logger.metadata([])` BEFORE `perform_job` — a successful assertion means the handler restored ctx from `job.meta["kiln_ctx"]`.

## Files Created/Modified

### New files (Plan 05)

- `lib/kiln/logger/metadata.ex` — `Kiln.Logger.Metadata` module with `with_metadata/2`, `mandatory_keys/0`, `default_filter/2` (the `:logger` filter). 66 LOC.
- `lib/kiln/telemetry.ex` — `Kiln.Telemetry` module with `pack_ctx/0`, `unpack_ctx/1`, `async_stream/3`, `pack_meta/0`. 88 LOC.
- `lib/kiln/telemetry/oban_handler.ex` — `Kiln.Telemetry.ObanHandler` with `attach/0`, `detach/0`, `handle_event/4`. 48 LOC.
- `test/support/logger_capture_helper.ex` — `Kiln.LoggerCaptureHelper` with `capture_json/1` + four `:logger` callback fns. 132 LOC.
- `test/kiln/logger/metadata_test.exs` — 4 behaviours covering `with_metadata/2` set-and-reset, raise-restoration, nested composition, and the six-key contract on bare `Logger.info/1` lines.
- `test/kiln/telemetry/metadata_threading_test.exs` — 3 behaviours (LOG-01, LOG-02, D-47 combined).

### Modified files

- `config/config.exs` — added `config :logger, :default_handler, formatter: ..., filters: [kiln_metadata_defaults: ...], filters_config: [default: :log]` while retaining the prior `:default_formatter` keys config for any fallback handler.
- `config/test.exs` — added `config :kiln, Oban, testing: :manual` so Oban.Testing's `perform_job/2` executes deterministically via `Executor.call` without needing `oban_jobs`.
- `lib/kiln/application.ex` — `alias Kiln.Telemetry.ObanHandler` at module top (Credo AliasUsage); post-`Supervisor.start_link` call to `ObanHandler.attach/0`; matching `ObanHandler.detach/0` in `stop/1` callback.

## Decisions Made

See `key-decisions` frontmatter — five decisions made during execution, each documented with rationale and cross-references.

The highest-impact was the **primary-level lift inside `capture_json/1`**: `config :logger, level: :warning` in `config/test.exs` means `Logger.info/1` is filtered at the primary before reaching any handler — the D-47 tests would have seen `lines=[]`. The alternative (require tests to use `Logger.warning`) is fragile and fights OBS-01's intent (production emits at `:info` for normal lifecycle events). Lifting to `:all` inside the capture span and restoring afterward keeps test behaviour stable while letting the broader suite keep its quiet floor.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Primary logger level lifted to `:all` inside `capture_json/1`**
- **Found during:** Task 2 (first run of `metadata_test.exs` — all 4 tests failed with `lines=[]`).
- **Issue:** `config/test.exs` sets `config :logger, level: :warning`. Erlang's logger applies the primary-level filter BEFORE handlers, so `Logger.info/1` events never reached the custom capture handler the helper attached.
- **Fix:** `capture_json/1` snapshots `:logger.get_primary_config()` before attach, sets primary level to `:all` for the capture span, restores the prior level in the `after` clause so other tests keep the `:warning` floor.
- **Files modified:** `test/support/logger_capture_helper.ex`
- **Verification:** All 4 metadata tests + 3 threading tests pass after the fix.
- **Committed in:** `0a5ba87` (Task 2)

**2. [Rule 3 — Blocking] Use `Oban.Testing.perform_job/2` instead of `Oban.drain_queue/1`**
- **Found during:** Task 2 planning (reviewing plan's action block against current DB state).
- **Issue:** The plan's example D-47 test calls `Oban.drain_queue(queue: :default)`. `drain_queue` reads jobs from the `oban_jobs` table — that table doesn't exist yet (the Oban migration lands in Plan 01-04, which runs AFTER 01-05 per the current wave order).
- **Fix:** Switched to `perform_job/2` which takes a `%Oban.Job{}` struct (built via `Oban.Testing.build_job/3`) and executes it via `Oban.Queue.Executor.call/1` — synchronously in the test process, no DB access, but DOES fire `[:oban, :job, :start]` telemetry (verified in `deps/oban/lib/oban/queue/executor.ex:97`). LOG-02's mechanical proof is preserved: the test clears `Logger.metadata` before `perform_job`, so a passing assertion means the `ObanHandler` restored ctx.
- **Files modified:** `test/kiln/telemetry/metadata_threading_test.exs`
- **Verification:** LOG-02 + D-47 combined tests pass.
- **Committed in:** `0a5ba87` (Task 2)

**3. [Rule 1 — Bug] Dialyxir `contract_supertype` on `mandatory_keys/0`**
- **Found during:** Task 2 (`mix check` after implementation + tests).
- **Issue:** `@spec mandatory_keys() :: [atom()]` is too broad — Dialyxir infers the success typing is the exact six-atom literal list and flags the `supertype`.
- **Fix:** Narrowed the spec to the exact atom union: `[:actor | :actor_role | :causation_id | :correlation_id | :run_id | :stage_id, ...]`.
- **Files modified:** `lib/kiln/logger/metadata.ex`
- **Verification:** `mix dialyzer` clean (0 errors).
- **Committed in:** `0a5ba87` (Task 2 — fix-with-tests)

**4. [Rule 1 — Bug] Credo `Enum.count` vs `length` + `!= []` vs `>= 1`**
- **Found during:** Task 2 (`mix check` after implementation + tests).
- **Issue:** Credo flagged `length(child_lines) == 3` and `length(worker_lines) >= 1` (length is O(n); preferred idiom is `Enum.count/1` when counting is needed and `list != []` when existence is the question).
- **Fix:** Switched to `Enum.count/1` for the exact-count assertion and `worker_lines != []` for the existence assertion.
- **Files modified:** `test/kiln/telemetry/metadata_threading_test.exs`
- **Committed in:** `0a5ba87` (Task 2)

**5. [Rule 1 — Bug] Credo `AliasUsage` — two nested-module call sites in `Kiln.Application`**
- **Found during:** Task 2 (`mix check`).
- **Issue:** `Kiln.Telemetry.ObanHandler.attach()` and `.detach()` called via full module path — `ex_slop` / Credo flag AliasUsage when a deeply-nested module is called from multiple sites.
- **Fix:** `alias Kiln.Telemetry.ObanHandler` at top; call sites use `ObanHandler.attach/0` and `ObanHandler.detach/0`.
- **Files modified:** `lib/kiln/application.ex`
- **Committed in:** `0a5ba87` (Task 2 — batched with other Credo fixups)

**6. [Rule 1 — Bug] `@doc false` on public `:logger` callback fns tripped `DocFalseOnPublicFunction`**
- **Found during:** Task 2 (`mix check`).
- **Issue:** `Kiln.LoggerCaptureHelper.{log, adding_handler, removing_handler, changing_config}` must be public (Erlang dispatches `:logger` callbacks by MFA). Initially marked `@doc false` because they aren't part of the user-facing API — but ex_slop's `DocFalseOnPublicFunction` check trips on that pattern (usually indicates API leakage).
- **Fix:** Gave each callback a real `@doc` string explaining the `:logger` contract. Moduledoc clarifies that only `capture_json/1` is caller-facing.
- **Files modified:** `test/support/logger_capture_helper.ex`
- **Committed in:** `0a5ba87` (Task 2)

**7. [Rule 3 — Blocking] Formatter-applied reflow of multi-clause `handle_event/4`**
- **Found during:** Task 2 (`mix format --check-formatted`).
- **Issue:** `mix format` reformatted the pattern-match `handle_event([:oban, :job, :start], _, %{job: %{meta: %{"kiln_ctx" => ctx}}}, _)` clause across multiple lines for line-length conformance.
- **Fix:** Ran `mix format` + accepted the reflow (no behaviour change).
- **Files modified:** `lib/kiln/telemetry/oban_handler.ex`
- **Committed in:** `0a5ba87` (Task 2)

---

**Total deviations:** 7 auto-fixed (2 Rule-3 blocking, 5 Rule-1 bugs / strict-gate fixups).
**Impact on plan:** All deviations essential to reach the plan's own acceptance criteria (tests green, `mix check` green across all 11 tools). Zero scope creep. Deviation #1 (primary-level lift) was the most architecturally significant — without it, the entire test suite would have been dead code.

## Issues Encountered

**1. `ExUnit.CaptureLog` cannot be used for JSON-metadata assertions.** `capture_log/1` installs its own temporary `:logger` handler with a plain-text formatter (`"[info] message\n"` shape) — NOT the `LoggerJSON.Formatters.Basic` installed on `:default_handler`. Confirmed empirically. The solution (the `Kiln.LoggerCaptureHelper.capture_json/1` helper) attaches a per-test handler using the same `LoggerJSON.Formatters.Basic.new/1` config as production. This helper is reusable for every future log-asserting test in Phases 2–9.

**2. `config :logger, level: :warning` in `config/test.exs` filters `:info` at the primary.** Covered under Deviation #1 above. Lifted to `:all` inside `capture_json/1`, restored in `after`.

**3. Oban's `oban_jobs` table doesn't exist yet (Plan 01-04 ships the Oban migration).** Covered under Deviation #2 above. Switched to `perform_job/2` which doesn't touch the DB.

**4. No Postgres DB interaction needed by Plan 01-05.** Unlike Plan 01-03 which required role-switching and migration bring-up, Plan 01-05 touches only in-memory state (Logger.metadata, ETS-backed telemetry handlers). The port-5432 sigra-uat-postgres blocker flagged in 01-01 / 01-03 SUMMARYs is NOT a concern for this plan — `mix test` runs entirely on the sigra postgres (via credential sharing documented in 01-03) without issue.

## User Setup Required

None. Plan 01-05 introduces no new env vars, no new external services, no new user-setup items.

The pre-existing operator blockers (Docker Desktop + asdf install from Plan 01-01; port-5432 conflict from 01-03) remain unchanged by this plan.

## Next Phase Readiness

**Ready for Plan 01-04 (external_operations + Kiln.Oban.BaseWorker):**
- `Kiln.Telemetry.pack_meta/0` is the right default for `BaseWorker.new/2` to call at enqueue — Plan 04 just needs to wrap it:
  ```elixir
  def new(args, opts \\ []) do
    opts = Keyword.put_new(opts, :meta, Kiln.Telemetry.pack_meta())
    super(args, opts)
  end
  ```
- `Kiln.Telemetry.ObanHandler` already handles the worker-side unpack — no BaseWorker boilerplate needed for ctx threading.
- Plan 04's test suite should use the same `Kiln.LoggerCaptureHelper.capture_json/1` pattern when asserting on BaseWorker-produced log lines.

**Ready for Plan 01-06 (BootChecks + HealthPlug):**
- BootChecks can ASSERT the Oban telemetry handler is attached as a 6th invariant (the attach is idempotent, so a BootChecks call after `Supervisor.start_link` is safe):
  ```elixir
  handler_ids = :telemetry.list_handlers([:oban, :job, :start]) |> Enum.map(& &1.id)
  unless {Kiln.Telemetry.ObanHandler, :oban_job_lifecycle} in handler_ids do
    raise Kiln.BootChecks.Error, ...
  end
  ```
- HealthPlug JSON emission can reuse `Kiln.LoggerCaptureHelper.capture_json/1` in its tests to assert the health endpoint response carries the right correlation_id.

**Ready for Phase 2+:**
- Every `Kiln.Audit.append/1` already consumes `Logger.metadata[:correlation_id]` (Plan 03) — Phase 2's run state machine can wrap every transition in `Kiln.Logger.Metadata.with_metadata([run_id: r, stage_id: s], fn -> ... end)` and audit events flow through automatically.
- Every `Task.async_stream` in Phase 2+ should use `Kiln.Telemetry.async_stream/3` instead — direct `Task.async_stream` would skip ctx propagation.
- Every Oban job enqueue in Phase 2+ should pass `meta: Kiln.Telemetry.pack_meta()` (or inherit it via `Kiln.Oban.BaseWorker.new/2` once Plan 04 ships).

**Notes for downstream planners:**
- **JSON line shape:** `{"time": "...", "severity": "...", "message": "...", "metadata": {"correlation_id": "...", ...}}`. The `metadata` object is nested — reads through `line["metadata"][key] || line[key]` stay robust against a future formatter swap.
- **Unset keys render as `"none"` string.** Never `null`, never missing. D-46 contract.
- **Prohibited transport:** `Process.put(:correlation_id, ...)` — `Kiln.Credo.NoProcessPut` (Plan 02) trips CI. Use `Kiln.Telemetry.pack_ctx/unpack_ctx` or `Kiln.Logger.Metadata.with_metadata/2`.
- **Credo `@doc false` + public fn trap:** if a later plan adds a callback module (e.g. `:telemetry`, `:gen_statem`), the callbacks must be public per the Erlang contract but `@doc false` trips `DocFalseOnPublicFunction`. Give each callback a real `@doc` string explaining the Erlang contract (pattern established in `logger_capture_helper.ex`).

## Self-Check: PASSED

**Files created — `test -f`:**

- `lib/kiln/logger/metadata.ex` — FOUND
- `lib/kiln/telemetry.ex` — FOUND
- `lib/kiln/telemetry/oban_handler.ex` — FOUND
- `test/support/logger_capture_helper.ex` — FOUND
- `test/kiln/logger/metadata_test.exs` — FOUND
- `test/kiln/telemetry/metadata_threading_test.exs` — FOUND

**Commits verified — `git log --oneline | grep "01-05"`:**

- `5888aac feat(01-05): logger_json formatter + D-45 metadata API + Oban handler` — FOUND
- `0a5ba87 test(01-05): contrived D-47 multi-process proof + metadata tests` — FOUND

**Acceptance criteria from 01-05-PLAN.md:**

- Task 1 acceptance — all 7 greps + `mix compile --warnings-as-errors` + smoke-test `mix run` grep all PASS.
- Task 2 acceptance — `mix test test/kiln/logger/metadata_test.exs` and `mix test test/kiln/telemetry/metadata_threading_test.exs` both exit 0 (4 + 3 tests all green). `capture_json` + `Jason.decode` + `Telemetry.async_stream` + `Telemetry.pack_meta` all grep-present.

**`mix check` tail (final run):**
```
 ✓ compiler success in 0:00
 ✓ credo success in 0:01
 ✓ dialyzer success in 0:04
 ✓ ex_unit success in 0:02
 ✓ formatter success in 0:01
 ✓ mix_audit success in 0:01
 ✓ no_compile_secrets success in 0:01
 ✓ no_manual_qa success in 0:01
 ✓ sobelow success in 0:01
 ✓ unused_deps success in 0:01
 ✓ xref_cycles success in 0:01
```

All 11 tools green. **OBS-01 mechanically proven via D-47 contrived test.**

**Pre-existing uncommitted `prompts/software dark factory prompt.txt`:** untouched throughout — still modified in working tree, not staged.

---

*Phase: 01-foundation-durability-floor*
*Plan: 05*
*Completed: 2026-04-19*
