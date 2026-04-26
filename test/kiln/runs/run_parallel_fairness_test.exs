defmodule Kiln.Runs.RunParallelFairnessTest do
  @moduledoc """
  Multi-run contention harness for PARA-01: each run leaving `:queued` emits
  `[:kiln, :run, :scheduling, :queued, :stop]` exactly once when started via
  `RunDirector.start_run/1`.
  """

  use Kiln.RehydrationCase, async: false

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs.RunDirector
  alias Kiln.Workflows

  setup do
    prev_skip = System.get_env("KILN_SKIP_OPERATOR_READINESS")
    System.put_env("KILN_SKIP_OPERATOR_READINESS", "1")
    :ok = Kiln.Secrets.put(:anthropic_api_key, "test-key")

    on_exit(fn ->
      case prev_skip do
        nil -> System.delete_env("KILN_SKIP_OPERATOR_READINESS")
        v -> System.put_env("KILN_SKIP_OPERATOR_READINESS", v)
      end

      for key <- [:anthropic_api_key, :openai_api_key, :google_api_key, :ollama_host] do
        Kiln.Secrets.put(key, nil)
      end

      cleanup_runs()
    end)

    reset_run_director_for_test()
    :ok
  end

  test "each of N queued runs emits dwell stop telemetry when started" do
    {:ok, graph} = Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    runs =
      for _ <- 1..4 do
        RunFactory.insert(:run,
          workflow_id: graph.id,
          workflow_version: graph.version,
          workflow_checksum: graph.checksum,
          state: :queued,
          model_profile_snapshot: %{"roles" => %{"planner" => "claude-sonnet-4-5"}}
        )
      end

    {:ok, agent} = Agent.start_link(fn -> 0 end)

    handler_id = "parallel-fairness-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:kiln, :run, :scheduling, :queued, :stop],
        fn _event, measurements, _metadata, _ ->
          assert is_integer(measurements.duration)
          assert measurements.duration >= 0
          Agent.update(agent, &(&1 + 1))
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    for run <- runs do
      assert {:ok, updated} = RunDirector.start_run(run.id)
      assert updated.state == :planning
      allow_session_roles_for_run(run.id)
    end

    assert Agent.get(agent, & &1) == length(runs)
  end
end
