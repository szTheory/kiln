defmodule Kiln.ExternalOperations.Pruner do
  @moduledoc """
  Periodic Oban worker that deletes `:completed` external_operations
  rows older than 30 days (D-19). `:failed` and `:abandoned` rows are
  retained indefinitely for forensics; the `audit_events` companion
  entries for every row (D-18) live forever regardless of this
  worker's actions.

  Privileges: `kiln_app` (the default runtime role per D-48) is granted
  INSERT/SELECT/UPDATE on `external_operations` but NOT DELETE — that's
  the T-03 mitigation that keeps forensic rows out of application-code
  reach. The Pruner escalates to `kiln_owner` via `SET LOCAL ROLE`
  inside its transaction; the connecting superuser (`kiln`) is granted
  membership in `kiln_owner` by migration 20260418000002 so role
  elevation succeeds without re-authentication.

  Scheduled via `Oban.Plugins.Cron` at `0 3 * * *` (daily at 03:00 UTC)
  — see `config/config.exs`. This worker itself uses bare
  `Oban.Worker` (not `Kiln.Oban.BaseWorker`) because maintenance jobs
  don't participate in the idempotency-key dedupe pattern.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 1,
    unique: [period: 60 * 60 * 6]

  import Ecto.Query

  alias Kiln.ExternalOperations.Operation
  alias Kiln.Repo

  require Logger

  @retention_days 30

  @impl Oban.Worker
  def perform(_job) do
    Repo.transaction(fn ->
      # Elevate to kiln_owner — only kiln_owner has DELETE on
      # external_operations (D-48, T-03). `SET LOCAL` scopes the change
      # to this txn, so the role resets automatically on commit/rollback.
      Repo.query!("SET LOCAL ROLE kiln_owner")

      cutoff =
        DateTime.utc_now()
        |> DateTime.add(-@retention_days * 24 * 60 * 60, :second)

      {count, _} =
        from(o in Operation,
          where: o.state == :completed,
          where: o.completed_at < ^cutoff
        )
        |> Repo.delete_all()

      Logger.info(
        "external_operations.pruner: deleted #{count} completed rows older than #{@retention_days} days"
      )

      count
    end)

    :ok
  end
end
