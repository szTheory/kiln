defmodule Kiln.Repo.Migrations.WorkUnitEventsImmutabilityTest do
  @moduledoc """
  Proves three-layer append-only enforcement for `work_unit_events`,
  mirroring `audit_events` tests.
  """

  use Kiln.AuditLedgerCase, async: false

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Repo
  alias Kiln.WorkUnits.{WorkUnit, WorkUnitEvent}

  defp insert_work_unit! do
    run = RunFactory.insert(:run)

    {:ok, wu} =
      %WorkUnit{}
      |> WorkUnit.changeset(%{run_id: run.id, agent_role: :planner})
      |> Repo.insert()

    wu
  end

  defp insert_work_unit_event!(overrides \\ %{}) do
    wu = insert_work_unit!()

    defaults = %{
      work_unit_id: wu.id,
      event_kind: :created,
      payload: %{},
      occurred_at: DateTime.utc_now(:microsecond)
    }

    {:ok, ev} =
      %WorkUnitEvent{}
      |> WorkUnitEvent.changeset(Map.merge(defaults, overrides))
      |> Repo.insert()

    ev
  end

  describe "WUE-01 Layer 1 (REVOKE) — kiln_app role" do
    test "UPDATE as kiln_app raises Postgrex.Error with :insufficient_privilege" do
      event = insert_work_unit_event!()

      caught =
        try do
          with_role("kiln_app", fn ->
            Repo.query!(
              "UPDATE work_unit_events SET payload = '{\"x\":1}'::jsonb WHERE id = $1",
              [Ecto.UUID.dump!(event.id)]
            )
          end)

          :no_error_raised
        rescue
          e in Postgrex.Error -> {:caught, e.postgres.code}
        end

      assert {:caught, :insufficient_privilege} = caught
    end

    test "DELETE as kiln_app raises Postgrex.Error with :insufficient_privilege" do
      event = insert_work_unit_event!()

      caught =
        try do
          with_role("kiln_app", fn ->
            Repo.query!("DELETE FROM work_unit_events WHERE id = $1", [Ecto.UUID.dump!(event.id)])
          end)

          :no_error_raised
        rescue
          e in Postgrex.Error -> {:caught, e.postgres.code}
        end

      assert {:caught, :insufficient_privilege} = caught
    end
  end

  describe "WUE-02 Layer 2 (trigger) — kiln_owner role, REVOKE bypassed" do
    test "UPDATE as kiln_owner raises with 'work_unit_events is append-only'" do
      event = insert_work_unit_event!()

      caught =
        try do
          with_role("kiln_owner", fn ->
            Repo.query!(
              "UPDATE work_unit_events SET payload = '{\"x\":1}'::jsonb WHERE id = $1",
              [Ecto.UUID.dump!(event.id)]
            )
          end)

          :no_error_raised
        rescue
          e in Postgrex.Error -> {:caught, e.postgres.message}
        end

      assert {:caught, msg} = caught
      assert msg =~ "work_unit_events is append-only"
    end

    test "DELETE as kiln_owner raises with 'work_unit_events is append-only'" do
      event = insert_work_unit_event!()

      caught =
        try do
          with_role("kiln_owner", fn ->
            Repo.query!("DELETE FROM work_unit_events WHERE id = $1", [Ecto.UUID.dump!(event.id)])
          end)

          :no_error_raised
        rescue
          e in Postgrex.Error -> {:caught, e.postgres.message}
        end

      assert {:caught, msg} = caught
      assert msg =~ "work_unit_events is append-only"
    end
  end

  describe "WUE-03 Layer 3 (RULE) — trigger disabled, RULE enabled" do
    test "UPDATE with trigger disabled + RULE enabled is silent no-op (num_rows: 0)" do
      event = insert_work_unit_event!(%{payload: %{"k" => "original"}})
      original = Repo.get!(WorkUnitEvent, event.id).payload

      with_role("kiln_owner", fn ->
        Repo.query!("ALTER TABLE work_unit_events DISABLE TRIGGER work_unit_events_no_update")
        Repo.query!("ALTER TABLE work_unit_events ENABLE RULE work_unit_events_no_update_rule")
      end)

      try do
        result =
          with_role("kiln_owner", fn ->
            Repo.query!(
              "UPDATE work_unit_events SET payload = '{\"k\":\"tampered\"}'::jsonb WHERE id = $1",
              [Ecto.UUID.dump!(event.id)]
            )
          end)

        assert %Postgrex.Result{num_rows: 0} = result

        reloaded = Repo.get!(WorkUnitEvent, event.id)
        assert reloaded.payload == original
      after
        with_role("kiln_owner", fn ->
          Repo.query!("ALTER TABLE work_unit_events DISABLE RULE work_unit_events_no_update_rule")
          Repo.query!("ALTER TABLE work_unit_events ENABLE TRIGGER work_unit_events_no_update")
        end)
      end
    end
  end

  describe "INSERT path — schema + bounded kinds" do
    test "insert as connecting user succeeds" do
      assert %WorkUnitEvent{} = insert_work_unit_event!(%{actor_role: :planner})
    end

    test "event_kind and occurred_at round-trip" do
      t = ~U[2026-04-20 12:00:00.000000Z]
      ev = insert_work_unit_event!(%{event_kind: :claimed, occurred_at: t, actor_role: :coder})
      reloaded = Repo.get!(WorkUnitEvent, ev.id)
      assert reloaded.event_kind == :claimed
      assert DateTime.compare(reloaded.occurred_at, t) == :eq
    end
  end
end
