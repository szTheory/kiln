defmodule Kiln.Integration.AgentTreeSharedMemoryTest do
  @moduledoc """
  End-to-end work-unit readiness, blockers, PubSub, and claim discipline
  (Phase 4 plan 04-04).
  """

  use Kiln.DataCase, async: false

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.WorkUnits
  alias Kiln.WorkUnits.PubSub, as: WUPubSub

  @moduletag :integration

  test "blocked unit stays unclaimable until unblock commits and broadcasts" do
    run = RunFactory.insert(:run, state: :coding)

    assert {:ok, _} = WorkUnits.seed_initial_planner_unit(run.id)
    assert {:ok, planner_wu} = WorkUnits.claim_next_ready(run.id, :planner)

    assert {:ok, coder_wu} =
             WorkUnits.create_work_unit(%{
               run_id: run.id,
               agent_role: :coder,
               input_payload: %{},
               result_payload: %{}
             })

    coder_id = coder_wu.id

    assert {:ok, _} = WorkUnits.block_work_unit(coder_id, planner_wu.id)

    Phoenix.PubSub.subscribe(Kiln.PubSub, WUPubSub.run_topic(run.id))

    assert {:error, :none_ready} = WorkUnits.claim_next_ready(run.id, :coder)

    assert {:ok, _} = WorkUnits.unblock_work_unit(coder_id, planner_wu.id)

    assert_receive {:work_unit, %{id: ^coder_id, event: :unblocked}}, 1_000

    assert {:ok, claimed} = WorkUnits.claim_next_ready(run.id, :coder)
    assert claimed.id == coder_wu.id
  end

  test "concurrent same-role claims cannot double-claim one unit" do
    run = RunFactory.insert(:run, state: :coding)

    assert {:ok, _} = WorkUnits.seed_initial_planner_unit(run.id)

    parent = self()

    tasks =
      for _ <- 1..5 do
        Task.async(fn ->
          send(parent, {:claim_result, WorkUnits.claim_next_ready(run.id, :planner)})
        end)
      end

    results =
      for _ <- 1..5 do
        receive do
          {:claim_result, r} -> r
        after
          2_000 -> :timeout
        end
      end

    for t <- tasks, do: Task.await(t, 5_000)

    oks = Enum.count(results, &match?({:ok, _}, &1))
    errs = Enum.count(results, &match?({:error, _}, &1))

    assert oks == 1
    assert errs == 4
  end
end
