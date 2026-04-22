defmodule Kiln.Stages.NextStageDispatcher do
  @moduledoc """
  Auto-enqueues newly-unblocked workflow stages after a stage succeeds.

  This module is intentionally process-free. It reads the run's pinned
  workflow graph, checks parent-stage completion, creates the next
  `stage_runs` row on demand, and enqueues `Kiln.Stages.StageWorker`
  jobs with deterministic idempotency keys.
  """

  import Ecto.Query

  alias Kiln.{ModelRegistry, Repo, Runs, Stages, Telemetry, Workflows}
  alias Kiln.Stages.{StageRun, StageWorker}

  @doc """
  Filters artifact refs for sandbox hydration when `holdout_excluded` is true
  (D-S02c / SPEC-04). Removes refs whose `sha256` is tagged as a holdout digest
  (`"holdout_"` prefix — synthetic marker in tests and internal tooling).

  Pure function: safe to call from tests without Docker or a full run graph.
  """
  @spec artifact_allowlist(list(map()), map()) :: list(map())
  def artifact_allowlist(artifact_refs, %{holdout_excluded: true})
      when is_list(artifact_refs) do
    Enum.reject(artifact_refs, &holdout_artifact_ref?/1)
  end

  def artifact_allowlist(artifact_refs, _ctx) when is_list(artifact_refs),
    do: artifact_refs

  defp holdout_artifact_ref?(ref) when is_map(ref) do
    dig = Map.get(ref, "sha256") || Map.get(ref, :sha256)
    is_binary(dig) and String.starts_with?(dig, "holdout_")
  end

  defp holdout_artifact_ref?(_), do: false

  @spec enqueue_next!(Ecto.UUID.t(), String.t()) :: :ok
  def enqueue_next!(run_id, completed_workflow_stage_id)
      when is_binary(run_id) and is_binary(completed_workflow_stage_id) do
    run = Runs.get!(run_id)
    {:ok, compiled} = load_workflow(run.workflow_id)
    stage_states = stage_state_map(run_id)

    compiled.stages
    |> Enum.filter(fn stage ->
      completed_workflow_stage_id in stage.depends_on and
        all_parents_succeeded?(stage, stage_states) and
        not Map.has_key?(stage_states, stage.id)
    end)
    |> Enum.each(fn stage ->
      stage_run = create_or_fetch_stage_run(run, stage)
      meta = Map.merge(Telemetry.pack_meta(), %{"run_id" => run_id})

      %{
        "idempotency_key" => "run:#{run_id}:stage:#{stage.id}",
        "run_id" => run_id,
        "stage_run_id" => stage_run.id,
        "stage_kind" => Atom.to_string(stage.kind),
        "stage_input" => build_stage_input(run, stage_run, stage)
      }
      |> StageWorker.new(meta: meta)
      |> Oban.insert()
    end)

    :ok
  end

  defp load_workflow(workflow_id) do
    path = Path.join(["priv", "workflows", "#{workflow_id}.yaml"])
    Workflows.load(path)
  end

  defp stage_state_map(run_id) do
    Repo.all(
      from sr in StageRun,
        where: sr.run_id == ^run_id,
        order_by: [asc: sr.attempt, asc: sr.inserted_at],
        select: {sr.workflow_stage_id, sr.state}
    )
    |> Map.new()
  end

  defp all_parents_succeeded?(stage, stage_states) do
    Enum.all?(stage.depends_on, fn dep_id ->
      Map.get(stage_states, dep_id) == :succeeded
    end)
  end

  defp create_or_fetch_stage_run(run, stage) do
    case Repo.one(
           from sr in StageRun,
             where:
               sr.run_id == ^run.id and sr.workflow_stage_id == ^stage.id and sr.attempt == 1,
             limit: 1
         ) do
      nil ->
        {:ok, stage_run} =
          Stages.create_stage_run(%{
            run_id: run.id,
            workflow_stage_id: stage.id,
            kind: stage.kind,
            agent_role: stage.agent_role,
            timeout_seconds: stage.timeout_seconds,
            sandbox: stage.sandbox
          })

        stage_run

      %StageRun{} = stage_run ->
        stage_run
    end
  end

  defp build_stage_input(run, stage_run, stage) do
    ref = artifact_ref()
    role_snapshot = role_snapshot(run.model_profile_snapshot, stage.agent_role)

    base = %{
      "run_id" => run.id,
      "stage_run_id" => stage_run.id,
      "attempt" => stage_run.attempt,
      "spec_ref" => ref,
      "budget_remaining" => %{
        "tokens_usd" => 1.0,
        "tokens" => 1000,
        "elapsed_seconds" => 300
      },
      "model_profile_snapshot" => role_snapshot
    }

    # holdout_excluded: true — non-verifier stages must never receive holdout
    # bodies or digests (SPEC-04); see `artifact_allowlist/2` for manifest CAS.
    case stage.kind do
      :planning ->
        Map.merge(base, %{"holdout_excluded" => true, "last_diagnostic_ref" => nil})

      :coding ->
        Map.merge(base, %{"holdout_excluded" => true, "plan_ref" => ref})

      :testing ->
        Map.merge(base, %{"holdout_excluded" => true, "code_ref" => ref})

      :verifying ->
        Map.merge(base, %{"holdout_excluded" => true, "test_output_ref" => ref})

      :merge ->
        Map.merge(base, %{"holdout_excluded" => true, "verifier_verdict_ref" => ref})
    end
  end

  defp role_snapshot(snapshot, agent_role) do
    role_key = Atom.to_string(agent_role)

    cond do
      is_map(snapshot["roles"]) ->
        case Map.get(snapshot["roles"], role_key) do
          model when is_binary(model) ->
            %{"role" => role_key, "requested_model" => model, "fallback_chain" => []}

          %{"model" => model, "fallback" => fallback} ->
            %{"role" => role_key, "requested_model" => model, "fallback_chain" => fallback || []}

          %{model: model, fallback: fallback} ->
            %{"role" => role_key, "requested_model" => model, "fallback_chain" => fallback || []}

          _ ->
            role_snapshot_from_profile(snapshot["profile"], agent_role)
        end

      true ->
        role_snapshot_from_profile(snapshot["profile"], agent_role)
    end
  end

  defp role_snapshot_from_profile(profile_name, agent_role) when is_binary(profile_name) do
    role_key = Atom.to_string(agent_role)

    case Enum.find(ModelRegistry.all_presets(), &(Atom.to_string(&1) == profile_name)) do
      nil ->
        default_role_snapshot(role_key)

      preset ->
        case ModelRegistry.resolve(preset) |> Map.get(agent_role) do
          %{model: model, fallback: fallback} ->
            %{"role" => role_key, "requested_model" => model, "fallback_chain" => fallback || []}

          _ ->
            default_role_snapshot(role_key)
        end
    end
  end

  defp role_snapshot_from_profile(_profile_name, agent_role) do
    default_role_snapshot(Atom.to_string(agent_role))
  end

  defp default_role_snapshot(role_key) do
    %{
      "role" => role_key,
      "requested_model" => "claude-sonnet-4-5",
      "fallback_chain" => []
    }
  end

  defp artifact_ref do
    %{
      "sha256" => String.duplicate("f", 64),
      "size_bytes" => 100,
      "content_type" => "text/markdown"
    }
  end
end
