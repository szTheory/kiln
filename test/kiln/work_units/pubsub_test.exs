defmodule Kiln.WorkUnits.PubSubTest do
  use Kiln.DataCase, async: false

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.WorkUnits
  alias Kiln.WorkUnits.PubSub, as: WUPubSub

  test "successful mutations broadcast on global, per-unit, and per-run topics" do
    run = RunFactory.insert(:run)

    Phoenix.PubSub.subscribe(Kiln.PubSub, WUPubSub.global_topic())
    Phoenix.PubSub.subscribe(Kiln.PubSub, WUPubSub.run_topic(run.id))

    assert {:ok, wu} = WorkUnits.seed_initial_planner_unit(run.id)

    for _ <- 1..2 do
      assert_receive {:work_unit, p}
      assert p.id == wu.id
      assert p.run_id == run.id
      assert p.event == :created
    end

    Phoenix.PubSub.subscribe(Kiln.PubSub, WUPubSub.unit_topic(wu.id))

    assert {:ok, _} = WorkUnits.claim_next_ready(run.id, :planner)

    for _ <- 1..3 do
      assert_receive {:work_unit, p}
      assert p.id == wu.id
      assert p.run_id == run.id
      assert p.event == :claimed
    end
  end

  test "failed transactions emit no broadcasts" do
    run = RunFactory.insert(:run)
    assert {:ok, a} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :planner})
    assert {:ok, b} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :coder})
    assert {:ok, _} = WorkUnits.block_work_unit(a.id, b.id)

    Phoenix.PubSub.subscribe(Kiln.PubSub, WUPubSub.global_topic())

    assert {:error, _} = WorkUnits.block_work_unit(a.id, b.id)

    refute_receive {:work_unit, _}, 200
  end
end
