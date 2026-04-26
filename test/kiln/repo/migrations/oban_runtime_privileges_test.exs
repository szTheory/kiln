defmodule Kiln.Repo.Migrations.ObanRuntimePrivilegesTest do
  @moduledoc false
  use Kiln.AuditLedgerCase, async: false

  describe "kiln_app runtime role" do
    test "can exercise the Oban tables required for app boot and queue operation" do
      peer_name = "Oban.RuntimePrivilegesTest"
      peer_node = "kiln@test-node"

      with_role("kiln_app", fn ->
        assert %{rows: [[_count]]} = Repo.query!("SELECT count(*) FROM oban_jobs")

        assert %{rows: [[job_id]]} =
                 Repo.query!("""
                 INSERT INTO oban_jobs (
                   state,
                   queue,
                   worker,
                   args,
                   errors,
                   inserted_at,
                   scheduled_at
                 )
                 VALUES (
                   'available',
                   'default',
                   'Kiln.TestWorker',
                   '{}'::jsonb,
                   ARRAY[]::jsonb[],
                   timezone('UTC', now()),
                   timezone('UTC', now())
                 )
                 RETURNING id
                 """)

        assert %{num_rows: 1} =
                 Repo.query!(
                   "UPDATE oban_jobs SET state = 'scheduled' WHERE id = $1",
                   [job_id]
                 )

        assert %{num_rows: 1} =
                 Repo.query!(
                   """
                   INSERT INTO oban_peers (name, node, started_at, expires_at)
                   VALUES ($1, $2, timezone('UTC', now()), timezone('UTC', now()) + interval '30 seconds')
                   """,
                   [peer_name, peer_node]
                 )

        assert %{num_rows: 1} =
                 Repo.query!(
                   "DELETE FROM oban_peers WHERE name = $1 AND node = $2",
                   [peer_name, peer_node]
                 )

        assert %{rows: [[estimate]]} =
                 Repo.query!(
                   "SELECT public.oban_count_estimate($1, $2)",
                   ["available", "default"]
                 )

        assert is_integer(estimate)
      end)
    end
  end
end
