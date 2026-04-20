defmodule Kiln.Stages.StageWorker do
  @moduledoc """
  Dispatches a single stage of a run (D-70, D-73, D-74, D-75, D-76, D-87).

  Enqueued with args:

      %{
        "idempotency_key" => "run:<run_id>:stage:<stage_run_id>",
        "run_id" => <run_id>,
        "stage_run_id" => <stage_run_id>,
        "stage_kind" => "planning" | "coding" | "testing" | "verifying" | "merge",
        "stage_input" => %{...}   # must validate against priv/stage_contracts/v1/<kind>.json
      }

  and Oban `meta` containing `kiln_ctx` (packed by `Kiln.Telemetry.pack_ctx/0`
  at enqueue time). `perform/1` restores Logger metadata via
  `Kiln.Telemetry.unpack_ctx/1` on entry so child log lines carry the
  parent's `correlation_id` / `run_id` / `stage_id`.

  Phase 2 stubs the agent dispatch — happy path produces a canned artifact
  (`<kind>.md`) via `Kiln.Artifacts.put/4` and transitions the run via
  `Kiln.Runs.Transitions.transition/3`. Phase 3 replaces the stub with
  real per-kind agent adapters.

  ## State-machine transition mapping (LOCKED per 02-08-PLAN.md)

      :planning  → :coding
      :coding    → :testing
      :testing   → :verifying
      :verifying → :merged       # reaches terminal per D-87
      :merge     → NO TRANSITION # terminal :merged already reached via :verifying

  Phase 2 end-to-end test drives 4 stages (plan, code, test, verify), NOT 5.
  The 5th `:merge` stage in `priv/workflows/elixir_phoenix_feature.yaml`
  is Phase-3 territory — Phase 3 will add real merge semantics (the actual
  git merge operation) and the correct transition owner for the `:merge`
  kind.

  ## Idempotency (D-70)

  `use Kiln.Oban.BaseWorker, queue: :stages` gives insert-time
  `unique: [keys: [:idempotency_key], period: :infinity, ...]`; runtime
  dedupe is enforced by calling
  `fetch_or_record_intent/2` + asserting the existing op's state isn't
  already `:completed`. A retry of the same `idempotency_key` after a
  successful completion returns `:ok` without re-running the stub
  dispatch (D-14 two-phase intent contract).

  ## Boundary rejection (D-75, D-76)

  `Kiln.Stages.ContractRegistry.fetch/1` returns the JSV-compiled
  stage-input contract for the kind; `JSV.validate/2` rejects malformed
  envelopes (including the `spec_ref.size_bytes` > 50 MB cap per D-75)
  BEFORE any side effect. Rejection returns
  `{:cancel, {:stage_input_rejected, err}}` — `:cancel` (NOT `:discard`,
  which is deprecated in Oban 2.21 per PITFALLS P9) because rejection
  should not trigger Oban retry/backoff. A `:stage_input_rejected` audit
  event is appended and the run is transitioned to `:escalated` with
  `reason: :invalid_stage_input` (a boundary violation indicates a
  workflow / upstream-producer bug, not an operator remediation).
  """

  use Kiln.Oban.BaseWorker, queue: :stages

  alias Kiln.Artifacts
  alias Kiln.Repo
  alias Kiln.Runs.Transitions
  alias Kiln.Stages.{ContractRegistry, NextStageDispatcher, StageRun}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, meta: meta}) do
    # Only restore Logger metadata when the enqueuing process packed a
    # non-empty kiln_ctx via Kiln.Telemetry.pack_meta/0. An empty ctx
    # would otherwise CLOBBER the current process's metadata with the
    # placeholder `:none` atoms — a loud correctness bug in tests that
    # drive perform_job/2 directly without packing a meta envelope.
    case meta["kiln_ctx"] do
      ctx when is_map(ctx) and map_size(ctx) > 0 ->
        _ = Kiln.Telemetry.unpack_ctx(ctx)

      _ ->
        :ok
    end

    key = args["idempotency_key"]
    run_id = args["run_id"]
    stage_run_id = args["stage_run_id"]
    stage_kind = String.to_existing_atom(args["stage_kind"])
    stage_input = args["stage_input"] || %{}

    with {:ok, root} <- ContractRegistry.fetch(stage_kind),
         :ok <- validate_input(stage_input, root),
         {_status, op} <-
           fetch_or_record_intent(key, %{
             op_kind: "stage_dispatch",
             intent_payload: args,
             run_id: run_id,
             stage_id: stage_run_id
           }),
         :ok <- guard_not_completed(op),
         {:ok, _stage_run} <- update_stage_run(stage_run_id, %{state: :running}),
         {:ok, _artifact} <- stub_dispatch(run_id, stage_run_id, stage_kind),
         {:ok, _stage_run} <- update_stage_run(stage_run_id, %{state: :succeeded}),
         :ok <- maybe_transition_after_stage(run_id, stage_kind),
         :ok <- enqueue_next_stage(run_id, stage_run_id) do
      _ = complete_op(op, %{"result" => "stub_ok", "stage_kind" => args["stage_kind"]})
      :ok
    else
      {:error, {:stage_input_rejected, err}} ->
        _ = update_stage_run(stage_run_id, %{state: :failed, error_summary: "invalid_stage_input"})

        _ =
          Kiln.Audit.append(%{
            event_kind: :stage_input_rejected,
            run_id: run_id,
            stage_id: stage_run_id,
            correlation_id: Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
            payload: %{
              "stage_run_id" => stage_run_id,
              "stage_kind" => args["stage_kind"],
              "errors" => wrap_errors(err)
            }
          })

        _ = Transitions.transition(run_id, :escalated, %{reason: :invalid_stage_input})
        {:cancel, {:stage_input_rejected, err}}

      {:error, :already_completed} ->
        # Idempotent no-op — the intent row already records :completed.
        :ok

      {:error, :unknown_kind} = err ->
        Logger.error(
          "StageWorker unknown stage_kind stage_run_id=#{stage_run_id} stage_kind=#{stage_kind}",
          run_id: run_id,
          stage_id: stage_run_id
        )

        {:cancel, err}

      {:error, reason} ->
        _ = update_stage_run(stage_run_id, %{state: :failed, error_summary: inspect(reason)})

        Logger.error(
          "StageWorker failure stage_run_id=#{stage_run_id} reason=#{inspect(reason)}",
          run_id: run_id,
          stage_id: stage_run_id
        )

        {:error, reason}
    end
  end

  # -- private helpers ----------------------------------------------------

  defp validate_input(input, root) do
    case JSV.validate(input, root) do
      {:ok, _casted} -> :ok
      {:error, err} -> {:error, {:stage_input_rejected, JSV.normalize_error(err)}}
    end
  end

  # `fetch_or_record_intent/2` returns `{:inserted_new | :found_existing, op}`.
  # An already-completed op short-circuits the happy path so a retry after
  # a successful run returns `:ok` without re-producing the artifact or
  # re-firing a transition (D-14).
  defp guard_not_completed(%{state: :completed}), do: {:error, :already_completed}
  defp guard_not_completed(_op), do: :ok

  # Phase-2 stub: produce a canned artifact for the stage kind and write
  # it through the Kiln.Artifacts CAS path. Phase 3 replaces this stub
  # with a real agent invocation.
  #
  # Pass `content_type` as the atom (not the string) so Kiln.Artifacts
  # does not call `String.to_existing_atom/1` — the atom is guaranteed
  # to exist because Kiln.Artifacts.Artifact's `@content_types` module
  # attribute creates it at compile time.
  defp stub_dispatch(run_id, stage_run_id, stage_kind) do
    body = ["# Stub output for stage_kind=", Atom.to_string(stage_kind), "\n"]

    Artifacts.put(stage_run_id, "#{stage_kind}.md", body,
      run_id: run_id,
      content_type: :"text/markdown",
      producer_kind: Atom.to_string(stage_kind)
    )
  end

  # LOCKED MAPPING (02-08-PLAN.md):
  # planning → coding; coding → testing; testing → verifying; verifying → merged.
  # merge → NO TRANSITION (terminal already reached via verifying; Phase 3 adds real merge).
  defp maybe_transition_after_stage(run_id, :planning) do
    case Transitions.transition(run_id, :coding) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  defp maybe_transition_after_stage(run_id, :coding) do
    case Transitions.transition(run_id, :testing) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  defp maybe_transition_after_stage(run_id, :testing) do
    case Transitions.transition(run_id, :verifying) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  defp maybe_transition_after_stage(run_id, :verifying) do
    case Transitions.transition(run_id, :merged) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  # :merge kind does NOT transition in Phase 2 — the run already reached :merged
  # via :verifying. Phase 3 adds real merge semantics + correct transition owner.
  defp maybe_transition_after_stage(_run_id, :merge), do: :ok

  defp enqueue_next_stage(run_id, stage_run_id) do
    stage_run = Repo.get!(StageRun, stage_run_id)
    NextStageDispatcher.enqueue_next!(run_id, stage_run.workflow_stage_id)
  end

  defp update_stage_run(stage_run_id, attrs) do
    case Repo.get(StageRun, stage_run_id) do
      nil ->
        {:error, :stage_run_not_found}

      %StageRun{} = stage_run ->
        stage_run
        |> StageRun.changeset(attrs)
        |> Repo.update()
    end
  end

  # The :stage_input_rejected audit schema requires `errors` to be an
  # array of objects. `JSV.normalize_error/1` returns a single map
  # (`%{valid: false, details: [...]}`); wrap it in a list so the schema
  # validator accepts it. Keys are stringified — JSONB round-trips atoms
  # to strings and the audit-schema's `additionalProperties: true` on
  # items tolerates the shape.
  defp wrap_errors(err) when is_map(err), do: [stringify_map(err)]
  defp wrap_errors(err) when is_list(err), do: Enum.map(err, &stringify_map/1)
  defp wrap_errors(other), do: [%{"error" => inspect(other)}]

  defp stringify_map(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), stringify_value(v)} end)
  end

  defp stringify_map(other), do: %{"error" => inspect(other)}

  defp stringify_value(v) when is_map(v), do: stringify_map(v)
  defp stringify_value(v) when is_list(v), do: Enum.map(v, &stringify_value/1)

  defp stringify_value(v) when is_atom(v) and not is_boolean(v) and not is_nil(v),
    do: Atom.to_string(v)

  defp stringify_value(v), do: v
end
