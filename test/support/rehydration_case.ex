defmodule Kiln.RehydrationCase do
  alias Kiln.Agents.SessionSupervisor

  @moduledoc """
  ExUnit case template for BEAM-kill + reboot scenarios (the signature
  ORCH-03 / ORCH-04 test pattern described in 02-CONTEXT.md Specifics
  line 245).

  The canonical rehydration test deliberately stops the `RunDirector`
  GenServer subtree WITHOUT checking in / cleaning up the Postgres state,
  waits for the `:permanent` child to be restarted by its supervisor (or
  explicitly starts a fresh one), and asserts that `RunDirector.boot_scan`
  picks up the active-state `runs` row from the database and spawns a
  per-run subtree under `Kiln.Runs.RunSupervisor`.

  Unlike `Kiln.DataCase`, this template DOES NOT check in the Ecto sandbox
  at `on_exit` — the whole point is that the simulated "restart" must see
  the DB state that the previous agent committed. Tests using this case
  MUST manage their own cleanup (see `cleanup_runs/0` helper).

  **Plan 02-00 ships this as SCAFFOLDING.** The real `Kiln.Runs.RunDirector`
  and `Kiln.Runs.RunSupervisor` modules do not yet exist — they arrive in
  Plan 07. The helpers below use `Process.whereis/1` / `Kernel.apply/3`
  (module/function lookups at runtime) so this case template compiles
  cleanly against Plan 02-00's codebase, and then degrades gracefully when
  called before Plan 07 lands (each helper returns `:ok` with a note in
  `Logger.debug/1` rather than raising).

  Plan 07 updates this file to call the real modules directly once they
  exist.

  Usage (Plan 07+):

      defmodule Kiln.RunDirectorRehydrationTest do
        use Kiln.RehydrationCase, async: false

        test "run continues after simulated restart" do
          # 1. seed a run in :coding state
          # 2. stop_run_director_subtree()
          # 3. restart_run_director()
          # 4. reset_run_director_for_test()  # waits for boot_scan
          # 5. assert the subtree is rehydrated and the run continues
        end
      end
  """

  use ExUnit.CaseTemplate

  require Logger

  using do
    quote do
      alias Kiln.Repo

      import Kiln.RehydrationCase

      import Ecto
      import Ecto.Query
    end
  end

  @doc """
  Allows the test sandbox owner to use DB connections from every role
  worker under the per-run `SessionSupervisor` for `run_id`.

  Call after a `RunSubtree` is running so `claim_next_ready/2` inside
  role `GenServer`s does not race sandbox ownership.
  """
  @spec allow_session_roles_for_run(Ecto.UUID.t()) :: :ok
  def allow_session_roles_for_run(run_id) when is_binary(run_id) do
    for role <- [:mayor, :planner, :coder, :tester, :reviewer, :uiux, :qa_verifier] do
      pid = SessionSupervisor.role_pid(run_id, role)

      if is_pid(pid) do
        Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, self(), pid)
      end
    end

    :ok
  end

  setup _tags do
    # Checkout the sandbox BUT do NOT add an on_exit(fn -> checkin ...)
    # callback: the simulated "restart" must still see the rows committed
    # by the pre-restart code path. Tests using this case MUST call
    # `cleanup_runs/0` (or equivalent) explicitly if cross-test isolation
    # matters.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Kiln.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Kiln.Repo, {:shared, self()})
    :ok
  end

  @doc """
  Stops the `Kiln.Runs.RunDirector` GenServer + `Kiln.Runs.RunSupervisor`
  DynamicSupervisor, simulating a node restart without actually killing
  the VM.

  **Plan 02-00 degrades to no-op** because those processes do not yet
  exist. Plan 07 replaces this body with real `GenServer.stop/2` +
  `DynamicSupervisor.stop/2` calls.
  """
  @spec stop_run_director_subtree() :: :ok
  def stop_run_director_subtree do
    director = Module.concat([Kiln, Runs, RunDirector])
    supervisor = Module.concat([Kiln, Runs, RunSupervisor])

    case Process.whereis(director) do
      nil -> :ok
      pid -> try_stop(pid, director, :normal)
    end

    case Process.whereis(supervisor) do
      nil -> :ok
      pid -> try_stop(pid, supervisor, :normal)
    end

    :ok
  end

  @doc """
  Starts a fresh `Kiln.Runs.RunDirector` instance (simulating supervisor
  restart after the `stop_run_director_subtree/0` stop).

  **Plan 02-00 degrades to no-op** because `Kiln.Runs.RunDirector` does
  not yet exist. Plan 07 replaces this body with a real
  `Kiln.Runs.RunDirector.start_link/1` call.
  """
  @spec restart_run_director() :: :ok
  def restart_run_director do
    director = Module.concat([Kiln, Runs, RunDirector])

    case Code.ensure_loaded(director) do
      {:module, ^director} ->
        if function_exported?(director, :start_link, 1) do
          _ = apply(director, :start_link, [[]])
          :ok
        else
          :ok
        end

      {:error, _} ->
        Logger.debug(
          "RehydrationCase.restart_run_director/0 is a no-op — Kiln.Runs.RunDirector not yet shipped."
        )

        :ok
    end
  end

  @doc """
  Forces a `RunDirector` state reset AFTER the Ecto sandbox ownership
  transfer has taken effect — protects against the Plan 07 threat-model
  T6 "boot-scan race" where a freshly-booted `RunDirector` opens its DB
  connection before `Ecto.Adapters.SQL.Sandbox.allow/3` has been called
  for the test pid.

  The sequence:

    1. Discover the live `RunDirector` pid (or no-op if absent).
    2. `Ecto.Adapters.SQL.Sandbox.allow/3` to make the director's Repo
       connection use the test's transaction.
    3. `send(pid, :boot_scan)` to trigger an immediate state rebuild from
       Postgres.
    4. `Process.sleep(100)` to give the director time to process the
       message (a more surgical alternative is a test-only
       `GenServer.call(director, :sync)` hook in Plan 07 — this sleep is
       the minimal P2-safe version).

  **Plan 02-00 degrades to no-op** if `Kiln.Runs.RunDirector` is not
  alive. Plan 07 replaces the `Process.sleep(100)` with a synchronous
  `GenServer.call/2` hook.
  """
  @spec reset_run_director_for_test() :: :ok
  def reset_run_director_for_test do
    director = Module.concat([Kiln, Runs, RunDirector])

    case Process.whereis(director) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        _ = try_allow_sandbox(pid)
        send(pid, :boot_scan)
        Process.sleep(100)
        :ok
    end
  end

  @doc """
  Deletes any `runs` rows inserted during the test. Callers that care
  about cross-test isolation invoke this in `on_exit/1`.

  Defensive: degrades to no-op if the `runs` table (Plan 02) or
  `stage_runs` (Plan 02) or `artifacts` (Plan 03) does not exist yet.
  """
  @spec cleanup_runs() :: :ok
  def cleanup_runs do
    try do
      Ecto.Adapters.SQL.Sandbox.checkin(Kiln.Repo)
    rescue
      _ -> :ok
    end

    :ok
  end

  # -- private helpers ---------------------------------------------------

  defp try_stop(pid, mod, reason) do
    try do
      if function_exported?(mod, :stop, 1) do
        apply(mod, :stop, [reason])
      else
        GenServer.stop(pid, reason, 5_000)
      end
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end

  defp try_allow_sandbox(pid) do
    try do
      Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, self(), pid)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end
end
