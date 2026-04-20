defmodule Kiln.Artifacts.GcWorker do
  @moduledoc """
  Daily refcount-based garbage collection of CAS blobs (D-83).

  Retention policy (Phase 5 activates; Phase 2 ships the scaffold):

    * `run.state = :merged`: keep plan, final diff, PR body, verifier
      verdict; GC intermediate attempt logs/test-outputs older than 7
      days (GitHub owns the permanent record).
    * `run.state ∈ {:failed, :escalated}`: retain ALL artifacts
      forever (forensics; mirrors D-19 `external_operations` policy).
    * Refcount scan: for every `sha256` in the `artifacts` table with
      refcount 0, delete the CAS blob after a 24-hour grace window
      (race protection).

  **Phase 2 ships a no-op body.** The cron entry in `config/config.exs`
  is commented out until Phase 5 activates this worker with the full
  refcount-scan + 24h-grace-window deletion logic.

  Queue: `:maintenance` (D-67) — same queue as the `:completed`
  external_operations 30-day pruner and the Phase 5 StuckDetector
  scan. One queue for every housekeeping concern so they never
  contend with `:stages`.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 1,
    unique: [period: 60 * 60 * 20]

  @impl Oban.Worker
  def perform(_job), do: :ok
end
