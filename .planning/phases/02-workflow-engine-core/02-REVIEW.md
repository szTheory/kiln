---
phase: 02-workflow-engine-core
reviewed: 2026-04-19T23:30:00Z
depth: standard
files_reviewed: 49
files_reviewed_list:
  - config/config.exs
  - config/dev.exs
  - config/runtime.exs
  - config/test.exs
  - lib/kiln/application.ex
  - lib/kiln/artifacts.ex
  - lib/kiln/artifacts/artifact.ex
  - lib/kiln/artifacts/cas.ex
  - lib/kiln/artifacts/corruption_error.ex
  - lib/kiln/artifacts/gc_worker.ex
  - lib/kiln/artifacts/scrub_worker.ex
  - lib/kiln/audit/event_kind.ex
  - lib/kiln/boot_checks.ex
  - lib/kiln/policies.ex
  - lib/kiln/policies/stuck_detector.ex
  - lib/kiln/runs.ex
  - lib/kiln/runs/illegal_transition_error.ex
  - lib/kiln/runs/run.ex
  - lib/kiln/runs/run_director.ex
  - lib/kiln/runs/run_subtree.ex
  - lib/kiln/runs/run_supervisor.ex
  - lib/kiln/runs/transitions.ex
  - lib/kiln/stages.ex
  - lib/kiln/stages/contract_registry.ex
  - lib/kiln/stages/stage_run.ex
  - lib/kiln/stages/stage_worker.ex
  - lib/kiln/workflows.ex
  - lib/kiln/workflows/compiled_graph.ex
  - lib/kiln/workflows/compiler.ex
  - lib/kiln/workflows/graph.ex
  - lib/kiln/workflows/loader.ex
  - lib/kiln/workflows/schema_registry.ex
  - lib/mix/tasks/check_bounded_contexts.ex
  - lib/mix/tasks/check_no_signature_block.ex
  - priv/audit_schemas/v1/artifact_written.json
  - priv/audit_schemas/v1/integrity_violation.json
  - priv/audit_schemas/v1/run_state_transitioned.json
  - priv/audit_schemas/v1/stage_input_rejected.json
  - priv/repo/migrations/20260419000001_extend_audit_event_kinds.exs
  - priv/repo/migrations/20260419000002_create_runs.exs
  - priv/repo/migrations/20260419000003_create_stage_runs.exs
  - priv/repo/migrations/20260419000004_create_artifacts.exs
  - priv/stage_contracts/v1/coding.json
  - priv/stage_contracts/v1/merge.json
  - priv/stage_contracts/v1/planning.json
  - priv/stage_contracts/v1/testing.json
  - priv/stage_contracts/v1/verifying.json
  - priv/workflow_schemas/v1/workflow.json
  - priv/workflows/elixir_phoenix_feature.yaml
findings:
  critical: 0
  warning: 7
  info: 7
  total: 14
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-04-19T23:30:00Z
**Depth:** standard
**Files Reviewed:** 49
**Status:** issues_found

## Summary

Phase 2 ships a substantial, highly-disciplined Workflow Engine Core: workflow loading/compilation, state-machine transitions, per-run supervision with rehydration, content-addressed artifact storage, and JSV boundary validation. The code is generally of high quality — extensive moduledocs, explicit invariants tied to CONTEXT.md decision records, ETS hygiene via `try/after`, append-only enforcement via three-layer DB defense, and thoughtful anti-pattern avoidance (string atoms not `String.to_atom`, Ecto.Enum over boolean flags, `compile_env` over runtime reads).

No blocker or critical issues were found. The most significant findings are:

1. **HIGH** — `StageWorker.perform/1` pattern-matches `fetch_or_record_intent/2`'s 3-shape return as a 2-tuple; an `{:error, reason}` return silently flows into `guard_not_completed/1` with `reason` bound to `op`, producing a confusing crash downstream instead of a typed error.
2. **HIGH** — `RunDirector.assert_workflow_unchanged/1` uses the relative path `"priv/workflows/<id>.yaml"` — this breaks in a release (release cwd ≠ project root) and should use `Application.app_dir(:kiln, ...)`.
3. **HIGH** — The `StuckDetector.check/1` contract documents `{:halt, atom(), map()}` as a valid return in Phase 5, but `Transitions.transition/3` calls it inside a `Repo.transact/2` via `with :ok <- StuckDetector.check(...)`. A `{:halt, _, _}` return becomes the `with`'s else-value and is returned from the transaction callback — `Repo.transact/2` only accepts `:ok | {:ok, _} | :error | {:error, _}`, so Phase 5 activation will crash the transaction wrapper at runtime unless the caller is updated.

There are also several MEDIUM / LOW items around relative paths in `Application.compile_env` defaults, a `GenServer.call` held inside an open DB transaction, unvalidated `workflow_id` format in the `Run` changeset, and a non-defensive `String.to_existing_atom/1` call on user-visible Oban args. None of these block phase completion; all have concrete remediation.

## Warnings

### WR-01 (HIGH): `StageWorker.perform/1` silently matches `{:error, _}` return from `fetch_or_record_intent/2`

**File:** `lib/kiln/stages/stage_worker.ex:92-101`
**Issue:** `Kiln.ExternalOperations.fetch_or_record_intent/2` returns one of three shapes per its `@spec`:

```
{:inserted_new, Operation.t()}
| {:found_existing, Operation.t()}
| {:error, Ecto.Changeset.t() | term()}
```

The `with` clause in `StageWorker.perform/1` destructures it as a 2-tuple:

```elixir
{_status, op} <-
  fetch_or_record_intent(key, %{...}),
:ok <- guard_not_completed(op),
```

An `{:error, reason}` return structurally matches `{_status, op}` — `_status` binds `:error`, `op` binds the `reason` (a changeset or arbitrary term). `guard_not_completed/1` then falls through its catch-all `defp guard_not_completed(_op), do: :ok`, and execution continues into `stub_dispatch` + `complete_op(op, ...)`. `complete_op` will eventually crash in `Operation.changeset(op, ...)` when handed a non-`%Operation{}` value, surfacing as an Oban retry with a confusing stacktrace rather than the intended typed failure.

**Fix:** Match each expected status explicitly and route `{:error, _}` to the error branch. Example:

```elixir
with {:ok, root} <- ContractRegistry.fetch(stage_kind),
     :ok <- validate_input(stage_input, root),
     {:ok, op} <- record_intent(key, run_id, stage_run_id, args),
     :ok <- guard_not_completed(op),
     {:ok, _artifact} <- stub_dispatch(run_id, stage_run_id, stage_kind),
     :ok <- maybe_transition_after_stage(run_id, stage_kind) do
  _ = complete_op(op, %{"result" => "stub_ok", "stage_kind" => args["stage_kind"]})
  :ok
else
  ...
end

defp record_intent(key, run_id, stage_run_id, args) do
  case fetch_or_record_intent(key, %{
         op_kind: "stage_dispatch",
         intent_payload: args,
         run_id: run_id,
         stage_id: stage_run_id
       }) do
    {:inserted_new, op} -> {:ok, op}
    {:found_existing, op} -> {:ok, op}
    {:error, _} = err -> err
  end
end
```

### WR-02 (HIGH): `RunDirector` loads workflow YAML via relative path — breaks in releases

**File:** `lib/kiln/runs/run_director.ex:177`
**Issue:** `assert_workflow_unchanged/1` constructs the workflow path as:

```elixir
path = Path.join(["priv/workflows", "#{run.workflow_id}.yaml"])
```

This resolves against the OTP release's cwd (not the project root / not the release's `priv/` dir). In a `mix release`, the BEAM's working directory is frequently `/` or a daemon-managed directory — `File.exists?(path)` returns `false`, the branch treats missing-as-changed, and every in-flight run gets escalated with `reason: :workflow_changed` on boot. The same issue affects `Kiln.Workflows.load(path)` on the happy branch.

**Fix:** Use `Application.app_dir/2` to resolve the packaged priv directory at runtime:

```elixir
defp assert_workflow_unchanged(run) do
  priv_dir = Application.app_dir(:kiln, "priv/workflows")
  path = Path.join(priv_dir, "#{run.workflow_id}.yaml")
  ...
end
```

Additionally, consider validating `run.workflow_id` shape before interpolating it into a filesystem path (defense in depth — see WR-03).

### WR-03 (HIGH): `StuckDetector.check/1` `{:halt, _, _}` return will crash `Repo.transact/2` on Phase 5 activation

**File:** `lib/kiln/runs/transitions.ex:94-103`, `lib/kiln/policies/stuck_detector.ex:58-59`
**Issue:** `StuckDetector.check/1`'s documented contract — explicitly called out as "stable through Phase 5" — is:

```
:ok | {:halt, reason :: atom(), payload :: map()}
```

`Transitions.transition/3` consumes it with `:ok <-` inside the `Repo.transact/2` closure:

```elixir
Repo.transact(fn ->
  with {:ok, run} <- lock_run(run_id),
       :ok <- assert_allowed(run.state, to),
       :ok <- StuckDetector.check(%{run: run, to: to, meta: meta}),
       ...
  end
end)
```

When Phase 5 flips the GenServer body to return `{:halt, :stuck, %{...}}`, the `with` clause fails to match and returns the 3-tuple as the closure value. `Repo.transact/2` expects `:ok | {:ok, _} | :error | {:error, _}` — any other return shape raises (`Ecto.InvalidChangesetError`-like or `RuntimeError`), not the intended same-tx escalation path. The no-op body today masks this — Phase 2 never exercises the halt path.

**Fix:** Either (a) decode `{:halt, _, _}` explicitly in `transition/3` and convert it to `{:error, {:stuck, payload}}` inside the closure before the `with` completes, or (b) rewrite the closure to use a `case` on `StuckDetector.check/1` and call a same-tx `transition(..., :escalated, payload)` branch. Option (a) is smaller:

```elixir
case StuckDetector.check(%{run: run, to: to, meta: meta}) do
  :ok ->
    with {:ok, updated} <- update_state(run, to, meta),
         {:ok, _event} <- append_audit(updated, run.state, to, meta) do
      {:ok, updated}
    end

  {:halt, reason, payload} ->
    # same-tx escalation — write :escalated state + audit event + return error
    do_escalate(run, reason, payload)
end
```

Add a test today that stubs `Kiln.Policies.StuckDetector` (via a Mox boundary or direct handler swap) to return `{:halt, :stuck, %{}}` and asserts `Transitions.transition/3` returns a typed error — locks in the contract before Phase 5 trips it.

### WR-04 (MEDIUM): `GenServer.call` on singleton `StuckDetector` held inside open DB transaction

**File:** `lib/kiln/runs/transitions.ex:98`
**Issue:** `Transitions.transition/3` opens a `Repo.transact/2`, takes a `SELECT ... FOR UPDATE` lock on the run row, then calls `StuckDetector.check/1` — a synchronous `GenServer.call` against a singleton process (per-app). The DB connection is held (and the row lock is held) for the entire round-trip to the singleton.

Phase 2 is no-op (`{:reply, :ok, state}`), so queue depth is trivial. But in Phase 5, the sliding-window body is planned to itself query the DB (via `stage_runs` failure-class windows). Under load, every concurrent run-transition serializes through one process — the singleton becomes a bottleneck AND holds every caller's DB connection + row lock while it resolves.

**Fix:** Move the `StuckDetector.check/1` call OUTSIDE the `Repo.transact/2` (before the lock), cache the result, then re-check inside the transaction as a sanity guard; or convert `StuckDetector` to an ETS-backed read (the sliding window is eventually-consistent anyway); or document the bottleneck and have Phase 5 make the call asynchronous via a pub/sub signal rather than an in-tx call. This also mitigates WR-03 (no more `{:halt, _, _}` inside the transact closure).

### WR-05 (MEDIUM): `Kiln.Artifacts.CAS` compile-env defaults are relative paths — production release hazard

**File:** `lib/kiln/artifacts/cas.ex:34-35`
**Issue:**

```elixir
@cas_root Application.compile_env(:kiln, [:artifacts, :cas_root], "priv/artifacts/cas")
@tmp_root Application.compile_env(:kiln, [:artifacts, :tmp_root], "priv/artifacts/tmp")
```

These defaults resolve relative to the BEAM's working directory at runtime. In a release that default is NOT the project root, so the CAS silently writes blobs under a wrong directory (typically the release's working dir). `config/runtime.exs` does NOT set these (neither dev nor prod), so prod runs fall through to the relative default. Blobs written this way would then be unreachable from `read!/1` and would break ORCH-04 "survive a restart" if a restart changes cwd.

**Fix:** Either (a) change the defaults to `Application.app_dir(:kiln, "priv/artifacts/cas")` (computed at compile time — resolves the release's real priv path), or (b) require operators to set explicit absolute paths in `config/runtime.exs` for `:prod`, and raise a `BootChecks` invariant when the resolved path is relative. Option (a) is simpler:

```elixir
@default_cas_root Path.join([:code.priv_dir(:kiln) |> to_string(), "artifacts", "cas"])
@cas_root Application.compile_env(:kiln, [:artifacts, :cas_root], @default_cas_root)
```

Note: `:code.priv_dir/1` at module-attribute-evaluation time resolves correctly at compile time. Verify behaviour under `mix release`; if it's fragile, fall back to making the config values REQUIRED at runtime (raise on absent).

### WR-06 (MEDIUM): `Run.changeset/2` does not validate `workflow_id` format — RunDirector path injection defense-in-depth gap

**File:** `lib/kiln/runs/run.ex:108-116`, `lib/kiln/runs/run_director.ex:177`
**Issue:** The workflow dialect schema (`priv/workflow_schemas/v1/workflow.json`) constrains `id` to `^[a-z][a-z0-9_]{2,63}$`, but `Kiln.Runs.Run.changeset/2` persists whatever `workflow_id` attribute is cast without a mirror regex. A buggy or adversarial caller (e.g. a future admin endpoint, a malformed migration, a crafted test fixture) could persist a `workflow_id` like `"../../../../etc/passwd"`. `RunDirector.assert_workflow_unchanged/1` then builds `Path.join(["priv/workflows", "../../../../etc/passwd.yaml"])`, which `File.exists?/1` resolves against the filesystem. It's read-only (and `.yaml`-suffixed), so the blast radius is small — but it's a real defense-in-depth gap.

**Fix:** Add a format validation in `Run.changeset/2` mirroring the schema regex:

```elixir
|> validate_format(:workflow_id, ~r/^[a-z][a-z0-9_]{2,63}$/)
```

Also add a DB-level CHECK constraint in a follow-up migration (mirror of the `workflow_checksum` CHECK) so a raw-SQL bypass is also rejected.

### WR-07 (MEDIUM): `String.to_existing_atom/1` on Oban arg raises `ArgumentError` — preferable to return typed cancel

**File:** `lib/kiln/stages/stage_worker.ex:89`
**Issue:** `stage_kind = String.to_existing_atom(args["stage_kind"])` is called BEFORE the `with` chain. If `stage_kind` is not one of the five registered atoms (which would only happen if an Oban job was enqueued from buggy code OR if an older job from a removed kind exists in the queue after a rollback), this raises `ArgumentError`. Oban converts the crash to a retry — but the worker's contract is to return `{:cancel, _}` on an unrecoverable boundary rejection (per the moduledoc's `:cancel` vs `:discard` discussion). Burning retry attempts on an unknowable bad job is wasteful.

**Fix:** Wrap the atomisation in a case:

```elixir
stage_kind =
  case args["stage_kind"] do
    s when s in ~w(planning coding testing verifying merge) ->
      String.to_existing_atom(s)

    other ->
      # Return early as cancel — do not raise, do not retry.
      # (restructure with/else to catch this shape)
      ...
  end
```

Or, cleaner, add a `validate_stage_kind/1` helper and put it at the head of the `with` chain so it surfaces as a typed `{:cancel, {:unknown_stage_kind, ...}}`.

## Info

### IN-01 (LOW): `CasTestHelper.setup_tmp_cas/0` claims to redirect CAS writes — but `CAS` captures paths at compile time

**File:** `test/support/cas_test_helper.ex:66-70`
**Issue:** `setup_tmp_cas/0` calls `Application.put_env(@app, @env_key, cas_root: ..., tmp_root: ...)`. `Kiln.Artifacts.CAS` reads these paths via `Application.compile_env/3` (captured at module compile time per the CAS moduledoc), so the runtime `put_env` is a no-op for the CAS module itself. The helper still has utility for future `Application.get_env` readers (GC workers), and the surrounding docstring acknowledges this — but the moduledoc line 15-17 still says "the helper captures the existing `:artifacts` env entry" in a way that implies it actually overrides CAS writes. The `cas_test.exs` moduledoc already carries the correct disclaimer; carry the same disclaimer into `CasTestHelper`.

**Fix:** Add to `CasTestHelper`'s moduledoc: "IMPORTANT: `Kiln.Artifacts.CAS` uses `Application.compile_env/3` — the runtime put_env here does NOT redirect CAS writes. This helper is retained for future `Application.get_env/2` readers (GC workers, future scrub workers). Tests that need CAS path isolation rely on the per-env `config/test.exs` setting, not this helper."

### IN-02 (LOW): Integration tests depend on `Process.sleep/1` for scan completion — known-flaky pattern

**File:** `test/integration/rehydration_test.exs:102,156`, `test/integration/run_subtree_crash_test.exs:79,95,133,143,146`
**Issue:** Rehydration and subtree-crash tests do `send(pid, :boot_scan)` + `Process.sleep(300)` to let the async scan complete. This is known-flaky on slow/loaded CI boxes — timing-dependent tests are the single largest flake source in most Elixir codebases. `rehydration_case.ex` even hints at the fix ("a more surgical alternative is a test-only `GenServer.call(director, :sync)` hook in Plan 07 — this sleep is the minimal P2-safe version"), but the hook was not added.

**Fix:** Add a test-only `handle_call(:sync, _, state) -> {:reply, :ok, state}` clause to `RunDirector`. A preceding cast/info is processed first (message-ordering guarantee), so `send(pid, :boot_scan); GenServer.call(pid, :sync)` completes deterministically without `sleep`. Same for `:periodic_scan`. Replace every `Process.sleep` in the integration tests with the call.

### IN-03 (LOW): `Kiln.Workflows.Compiler.normalize_stages/1` calls `Map.fetch!` on enum maps — JSV bypass path raises `KeyError`

**File:** `lib/kiln/workflows/compiler.ex:151-168`
**Issue:** `normalize_stages/1` uses `Map.fetch!(@kind_atoms, s["kind"])` (and similarly for `agent_role` and `sandbox`). If a caller invokes `Compiler.compile/1` directly (bypassing `Loader.load/1` and its JSV step — a supported "unit-test bypass" per the moduledoc), an unknown kind raises `KeyError` rather than returning the typed `{:error, {:graph_invalid, {:unknown_kind, _}, _}}` shape. The test-bypass path is exactly where this matters — it loses the typed-error contract.

**Fix:** Use `Map.get(@kind_atoms, s["kind"])` + a validator at the head of `compile/1` that rejects unknown enum values before `normalize_stages/1` runs. Example:

```elixir
defp normalize_stages(stages_raw) do
  Enum.reduce_while(stages_raw, {:ok, []}, fn s, {:ok, acc} ->
    with {:ok, kind} <- fetch_enum(@kind_atoms, s["kind"], :kind),
         {:ok, role} <- fetch_enum(@agent_role_atoms, s["agent_role"], :agent_role),
         {:ok, sandbox} <- fetch_enum(@sandbox_atoms, s["sandbox"], :sandbox) do
      {:cont, {:ok, [%{id: s["id"], kind: kind, ...} | acc]}}
    else
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end)
end
```

### IN-04 (LOW): `SchemaRegistry.fetch/1` error tuple shape differs from contract in Loader error types

**File:** `lib/kiln/workflows/schema_registry.ex:59-65`, `lib/kiln/workflows/loader.ex:92-107`
**Issue:** `SchemaRegistry.fetch/1`'s `@spec` is `{:ok, JSV.Root.t()} | {:error, :unknown_kind}`. `Loader.validate_schema/1` pattern-matches on that exact shape (`{:error, :unknown_kind}`) — fine today. But `ContractRegistry.fetch/1` has the identical shape, and `StageWorker.perform/1` matches the `:unknown_kind` atom (`{:error, :unknown_kind} = err`) before the generic `{:error, reason}` branch. If either registry is ever extended to return a different error shape (e.g. `{:error, {:compile_failed, ...}}`), the Loader and StageWorker will NOT match and will fall through to the catch-all branch, which handles it as a generic error — acceptable, but the compile-time `:missing` fallback is the only error shape today. Two registries with the same invariant is brittle.

**Fix:** Extract a shared `BuildRegistry` macro or consolidate both into `Kiln.SchemaRegistry` with a namespaced key (e.g. `fetch(:workflow, :root)` vs `fetch(:contract, :planning)`). No change required for Phase 2 — this is a "info for future refactor" item.

### IN-05 (LOW): `stringify_map/1` fallback `%{"error" => inspect(other)}` silently coerces non-map errors

**File:** `lib/kiln/stages/stage_worker.ex:231`
**Issue:** `wrap_errors/1` and `stringify_map/1` have a catch-all clause that wraps any non-map value in `%{"error" => inspect(other)}`. This is graceful — but it means the `:stage_input_rejected` audit payload's `errors` field can silently lose structured information if a `JSV.normalize_error/1` shape change lands upstream. The audit schema requires `errors[*]` to be objects, which is satisfied, but the contents become a `inspect/1` blob rather than structured diagnostic data.

**Fix:** Log a warning when the fallback fires so upstream shape changes surface in `mix check` logs:

```elixir
defp stringify_map(other) do
  Logger.warning("stringify_map fallback fired — unexpected JSV error shape",
    got: inspect(other, limit: 200)
  )
  %{"error" => inspect(other)}
end
```

### IN-06 (INFO): `audit_events_immutable` trigger-check migration is referenced from BootChecks but not re-verified in tests

**File:** `lib/kiln/boot_checks.ex:277-331`
**Issue:** The `probe_audit_mutation/2` helper uses `SAVEPOINT` + rollback pattern correctly to probe D-12's Layer 1 (REVOKE) and Layer 2 (trigger). However, the probe INSERTs a "probe" row via `kiln_owner`, triggers the UPDATE, and rolls back via `Repo.rollback`. Under a test sandbox this is inside an existing test transaction — the savepoint pattern handles it — but the probe's correctness depends on Postgres's behavior when rolling back a subtransaction inside an existing one. The existing test `test/kiln/boot_checks_test.exs` presumably verifies this, but I didn't open it. Worth a dedicated comment in `probe_audit_mutation/2` documenting the sandbox-vs-bare-connection semantics so a future refactor doesn't silently weaken the probe.

**Fix:** Non-blocking documentation clarification. No code change required.

### IN-07 (INFO): `@cas_root` / `@tmp_root` captured at compile time; `config/test.exs` uses `System.tmp_dir!()` at config compile time

**File:** `config/test.exs:30-32`, `lib/kiln/artifacts/cas.ex:34-35`
**Issue:** `config/test.exs` evaluates `System.tmp_dir!()` at config-compile time (which reads `TMPDIR`/`TMP`/`TEMP` env vars at that moment). The resolved path is baked into the compiled `CAS` module attributes. If a developer changes `TMPDIR` between `mix compile` and `mix test` (unusual but possible — e.g. `direnv` update, shell `export`), the compiled CAS paths won't match their current shell and tests will write to stale paths. `mix.exs` invalidation normally recompiles when config files change, but an env-var change alone does NOT trigger recompilation.

**Fix:** Non-blocking. Either (a) accept the brittleness and document in `config/test.exs` that `TMPDIR` changes require `mix clean`, or (b) switch to a stable per-project test path like `Path.join([System.cwd!(), "tmp", "cas_test"])`.

---

_Reviewed: 2026-04-19T23:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
