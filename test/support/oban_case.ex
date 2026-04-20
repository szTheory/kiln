defmodule Kiln.ObanCase do
  @moduledoc """
  Shared ExUnit case template for tests that exercise `Oban.Worker`
  implementations against the six-queue taxonomy defined in CONTEXT.md
  D-67..D-69.

  The six Phase 2 Oban queues are:

    * `:default` — ad-hoc / one-offs (deliberately small per D-67)
    * `:stages` — stage dispatch (`Kiln.Stages.StageWorker`)
    * `:github` — git/gh CLI shell-outs (Phase 6 activates)
    * `:audit_async` — non-transactional audit appends
    * `:dtu` — DTU mock contract tests + health polls
    * `:maintenance` — cron destinations (pruner, scrub, GC, stuck-detector)

  Setup:

    * Checks out an Ecto SQL sandbox for `Kiln.Repo`.
    * Switches to **shared sandbox mode** (`{:shared, self()}`) so
      Oban worker processes spawned during `perform_job/2` or
      `Oban.drain_queue/1` share the test's transaction. Per-test
      rollback still applies.
    * Imports `Oban.Testing` helpers (`assert_enqueued/1`, `perform_job/2`,
      `Oban.drain_queue/1`, etc.) and `Oban` itself.
    * `config :kiln, Oban, testing: :manual` (already set in `config/test.exs`)
      means jobs do NOT dispatch at insert time — tests drive dispatch
      explicitly with `perform_job/2` or `drain_queue/1`.

  Usage:

      defmodule Kiln.Stages.StageWorkerTest do
        use Kiln.ObanCase, async: false
        # async: false is required for Oban.Testing + shared sandbox

        test "dispatches a stage" do
          {:ok, _job} = Oban.insert(SomeWorker.new(%{...}))
          assert_enqueued(worker: SomeWorker)
          assert :ok = perform_job(SomeWorker, %{...})
        end
      end
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use Oban.Testing, repo: Kiln.Repo

      alias Kiln.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  setup _tags do
    :ok = Sandbox.checkout(Kiln.Repo)
    # Shared mode — Oban worker processes spawned by `perform_job` or
    # `Oban.drain_queue` are not test-owned, but need to see the sandbox
    # transaction. {:shared, self()} transfers ownership to the test pid.
    Sandbox.mode(Kiln.Repo, {:shared, self()})
    :ok
  end
end
