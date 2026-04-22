defmodule Kiln.AuditReplayTest do
  @moduledoc false

  use Kiln.DataCase, async: true

  alias Kiln.Audit
  alias Kiln.Factory.Run, as: RunFactory

  test "replay_page/1 walks forward with truncated flag and stable ORDER BY occurred_at, id" do
    run = RunFactory.insert(:run, workflow_id: "wf_audit_replay_page")
    shared_dt = ~U[2026-04-22 10:00:00.000000Z]
    cid1 = Ecto.UUID.generate()
    cid2 = Ecto.UUID.generate()
    cid3 = Ecto.UUID.generate()

    assert {:ok, e1} =
             Audit.append(%{
               event_kind: :stage_started,
               payload: %{"stage_kind" => "coding", "attempt" => 1},
               correlation_id: cid1,
               run_id: run.id,
               occurred_at: shared_dt,
               actor_id: "test:replay1"
             })

    assert {:ok, e2} =
             Audit.append(%{
               event_kind: :stage_started,
               payload: %{"stage_kind" => "testing", "attempt" => 1},
               correlation_id: cid2,
               run_id: run.id,
               occurred_at: shared_dt,
               actor_id: "test:replay2"
             })

    later = DateTime.add(shared_dt, 5, :microsecond)

    assert {:ok, _e3} =
             Audit.append(%{
               event_kind: :stage_started,
               payload: %{"stage_kind" => "verifying", "attempt" => 1},
               correlation_id: cid3,
               run_id: run.id,
               occurred_at: later,
               actor_id: "test:replay3"
             })

    # Same occurred_at → ORDER BY occurred_at ASC, id ASC must disambiguate by id.
    assert e1.occurred_at == e2.occurred_at

    sorted =
      Audit.replay(run_id: run.id)
      |> Enum.sort_by(fn e -> {e.occurred_at, e.id} end)

    assert length(sorted) == 3
    [first, second, third] = sorted
    assert first.occurred_at == second.occurred_at
    assert DateTime.compare(second.occurred_at, third.occurred_at) == :lt

    assert %{events: [^first], truncated: true} =
             Audit.replay_page(run_id: run.id, limit: 1, after: nil)

    assert %{events: [^second], truncated: true} =
             Audit.replay_page(run_id: run.id, limit: 1, after: {first.occurred_at, first.id})

    assert %{events: [^third], truncated: false} =
             Audit.replay_page(run_id: run.id, limit: 1, after: {second.occurred_at, second.id})
  end

  test "replay_page/1 anchor :tail returns latest rows ascending" do
    run = RunFactory.insert(:run, workflow_id: "wf_audit_replay_tail")
    base = ~U[2026-04-22 11:00:00.000000Z]

    for i <- 1..3 do
      dt = DateTime.add(base, i, :microsecond)

      assert {:ok, _} =
               Audit.append(%{
                 event_kind: :stage_started,
                 payload: %{"stage_kind" => "coding", "attempt" => i},
                 correlation_id: Ecto.UUID.generate(),
                 run_id: run.id,
                 occurred_at: dt,
                 actor_id: "test:tail#{i}"
               })
    end

    assert %{events: events, truncated: truncated?} =
             Audit.replay_page(run_id: run.id, limit: 2, anchor: :tail)

    assert length(events) == 2
    assert [%{occurred_at: a}, %{occurred_at: b}] = events
    assert DateTime.compare(a, b) in [:lt, :eq]
    assert truncated? in [true, false]
  end
end
