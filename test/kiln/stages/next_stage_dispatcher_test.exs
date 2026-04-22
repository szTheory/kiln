defmodule Kiln.Stages.NextStageDispatcherTest do
  use Kiln.ObanCase, async: false

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.Stages.{NextStageDispatcher, StageWorker}
  alias Kiln.Workflows

  test "is a pure module with enqueue_next!/2 and no GenServer callbacks" do
    assert {:module, NextStageDispatcher} = Code.ensure_compiled(NextStageDispatcher)
    assert function_exported?(NextStageDispatcher, :enqueue_next!, 2)
    refute function_exported?(NextStageDispatcher, :start_link, 1)
    refute function_exported?(NextStageDispatcher, :init, 1)
  end

  test "enqueues the coding stage after planning succeeds" do
    {:ok, graph} = Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    run =
      RunFactory.insert(:run,
        workflow_id: graph.id,
        workflow_version: graph.version,
        workflow_checksum: graph.checksum,
        model_profile_snapshot: %{"profile" => graph.model_profile}
      )

    _planning =
      StageRunFactory.insert(:stage_run,
        run_id: run.id,
        workflow_stage_id: "plan",
        kind: :planning,
        agent_role: :planner,
        state: :succeeded,
        sandbox: :readonly
      )

    assert :ok = NextStageDispatcher.enqueue_next!(run.id, "plan")

    assert_enqueued(
      worker: StageWorker,
      args: %{
        "idempotency_key" => "run:#{run.id}:stage:code",
        "run_id" => run.id,
        "stage_kind" => "coding"
      }
    )

    assert [%Oban.Job{meta: meta}] = all_enqueued(worker: StageWorker)
    assert meta["run_id"] == run.id
    assert Map.has_key?(meta, "kiln_ctx")
  end

  test "returns :ok without enqueueing when the completed stage is a leaf" do
    {:ok, graph} = Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    run =
      RunFactory.insert(:run,
        workflow_id: graph.id,
        workflow_version: graph.version,
        workflow_checksum: graph.checksum
      )

    _merge =
      StageRunFactory.insert(:stage_run,
        run_id: run.id,
        workflow_stage_id: "merge",
        kind: :merge,
        agent_role: :coder,
        state: :succeeded,
        sandbox: :readwrite
      )

    assert :ok = NextStageDispatcher.enqueue_next!(run.id, "merge")
    refute_enqueued(worker: StageWorker)
  end
end
