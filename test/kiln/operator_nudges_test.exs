defmodule Kiln.OperatorNudgesTest do
  use Kiln.DataCase, async: false

  require Logger

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.OperatorNudges

  setup do
    :ok = Kiln.OperatorNudgeLimiter.ensure_table()
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)
    {:ok, correlation_id: cid}
  end

  test "submit records audit", %{correlation_id: _} do
    run = RunFactory.insert(:run)
    assert {:ok, _id} = OperatorNudges.submit(run.id, "hello planner")
  end

  test "submit rejects oversize body" do
    run = RunFactory.insert(:run)
    big = String.duplicate("x", 400)
    assert {:error, :body_too_long} = OperatorNudges.submit(run.id, big)
  end

  test "submit enforces cooldown with injectable clock" do
    run = RunFactory.insert(:run)
    t0 = ~U[2026-01-01 00:00:00Z]
    t1 = DateTime.add(t0, 5, :second)
    t2 = DateTime.add(t0, 25, :second)

    assert {:ok, _} =
             OperatorNudges.submit(run.id, "first", utc_now: fn -> t0 end)

    assert {:error, :rate_limited} =
             OperatorNudges.submit(run.id, "second", utc_now: fn -> t1 end)

    assert {:ok, _} =
             OperatorNudges.submit(run.id, "third", utc_now: fn -> t2 end)
  end
end
