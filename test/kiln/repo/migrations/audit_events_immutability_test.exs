defmodule Kiln.Repo.Migrations.AuditEventsImmutabilityTest do
  @moduledoc """
  Proves the three-layer D-12 INSERT-only enforcement is active.

  Each describe block targets one layer and verifies it **independently**:
  if all three layers were stacked in a single test, bypassing the first
  two wouldn't prove the third is actually pulling its weight. The point
  of defense-in-depth is that removing any single layer must not silently
  open the mutation path.
  """

  use Kiln.AuditLedgerCase, async: false

  alias Kiln.Audit

  describe "AUD-01 Layer 1 (REVOKE) — kiln_app role" do
    test "UPDATE as kiln_app raises Postgrex.Error with :insufficient_privilege" do
      event = insert_event!()

      caught =
        try do
          with_role("kiln_app", fn ->
            Repo.query!(
              "UPDATE audit_events SET actor_id = 'tampered' WHERE id = $1",
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
      event = insert_event!()

      caught =
        try do
          with_role("kiln_app", fn ->
            Repo.query!("DELETE FROM audit_events WHERE id = $1", [Ecto.UUID.dump!(event.id)])
          end)

          :no_error_raised
        rescue
          e in Postgrex.Error -> {:caught, e.postgres.code}
        end

      assert {:caught, :insufficient_privilege} = caught
    end
  end

  describe "AUD-02 Layer 2 (trigger) — kiln_owner role, REVOKE bypassed" do
    test "UPDATE as kiln_owner raises with 'audit_events is append-only'" do
      event = insert_event!()

      caught =
        try do
          with_role("kiln_owner", fn ->
            Repo.query!(
              "UPDATE audit_events SET actor_id = 'tampered' WHERE id = $1",
              [Ecto.UUID.dump!(event.id)]
            )
          end)

          :no_error_raised
        rescue
          e in Postgrex.Error -> {:caught, e.postgres.message}
        end

      assert {:caught, msg} = caught
      assert msg =~ "audit_events is append-only"
    end

    test "DELETE as kiln_owner raises with 'audit_events is append-only'" do
      event = insert_event!()

      caught =
        try do
          with_role("kiln_owner", fn ->
            Repo.query!("DELETE FROM audit_events WHERE id = $1", [Ecto.UUID.dump!(event.id)])
          end)

          :no_error_raised
        rescue
          e in Postgrex.Error -> {:caught, e.postgres.message}
        end

      assert {:caught, msg} = caught
      assert msg =~ "audit_events is append-only"
    end
  end

  describe "AUD-03 Layer 3 (RULE) — trigger disabled, RULE enabled" do
    # The RULE is shipped DISABLED (see migration 20260418000004) because
    # Postgres query rewriting runs before triggers — an active
    # `DO INSTEAD NOTHING` RULE would mask Layer 2. This test explicitly
    # enables the RULE for the AUD-03 verification and disables it after.
    test "UPDATE with trigger disabled + RULE enabled is silent no-op (num_rows: 0)" do
      event = insert_event!(%{actor_id: "original"})
      original_actor = event.actor_id

      with_role("kiln_owner", fn ->
        Repo.query!("ALTER TABLE audit_events DISABLE TRIGGER audit_events_no_update")
        Repo.query!("ALTER TABLE audit_events ENABLE RULE audit_events_no_update_rule")
      end)

      try do
        result =
          with_role("kiln_owner", fn ->
            Repo.query!(
              "UPDATE audit_events SET actor_id = 'tampered' WHERE id = $1",
              [Ecto.UUID.dump!(event.id)]
            )
          end)

        assert %Postgrex.Result{num_rows: 0} = result

        reloaded = Repo.get!(Kiln.Audit.Event, event.id)
        assert reloaded.actor_id == original_actor
      after
        with_role("kiln_owner", fn ->
          Repo.query!("ALTER TABLE audit_events DISABLE RULE audit_events_no_update_rule")
          Repo.query!("ALTER TABLE audit_events ENABLE TRIGGER audit_events_no_update")
        end)
      end
    end
  end

  describe "INSERT path — kiln_app can append via Kiln.Audit.append/1" do
    test "kiln_app INSERT succeeds (proves GRANT INSERT is active)" do
      assert {:ok, _event} =
               Audit.append(%{
                 event_kind: :stage_started,
                 payload: %{"stage_kind" => "coding", "attempt" => 1},
                 correlation_id: Ecto.UUID.generate(),
                 actor_id: "test:insert"
               })
    end
  end
end
