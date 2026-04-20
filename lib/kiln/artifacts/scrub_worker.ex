defmodule Kiln.Artifacts.ScrubWorker do
  @moduledoc """
  Weekly integrity scrub — re-hashes every artifact blob and emits
  `:integrity_violation` audit events for any mismatches (D-84).

  Complement to `Kiln.Artifacts.read!/1` (which integrity-checks on
  every read): the ScrubWorker catches corruption in blobs that are
  put once and rarely read (e.g. archived plans from merged runs).
  Without it, a silent filesystem-level corruption could linger for
  months before a read path surfaced it.

  **Phase 2 ships a no-op body.** The cron entry in `config/config.exs`
  is commented out until Phase 5 activates this worker with the full
  table-walk + re-hash + audit-append logic.

  Queue: `:maintenance` (D-67).
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 1,
    unique: [period: 60 * 60 * 24 * 6]

  @impl Oban.Worker
  def perform(_job), do: :ok
end
