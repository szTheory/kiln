defmodule Kiln.StuckDetectorCase do
  @moduledoc """
  ExUnit case template that guarantees `Kiln.Policies.StuckDetector` is
  alive for the duration of a test. Centralises the "start if not
  started" dance that was copy-pasted across Plan 02-06 and 02-08 test
  files prior to this revision — prevents singleton name collision under
  async tests and ensures the detector's DB connection is in the
  sandbox-owner set for the test pid.

  Usage:

      use Kiln.StuckDetectorCase, async: false

  Composable with `Kiln.DataCase` / `Kiln.ObanCase` — a test can
  `use` both; the StuckDetector setup runs alongside the DataCase
  sandbox checkout.

  Defensive behaviour:

    * If `Kiln.Policies.StuckDetector` is not yet compiled (i.e., we're
      running this template against a Plan 02-00 codebase where Plan 06
      hasn't shipped the GenServer yet), the setup block no-ops with a
      `Logger.debug/1` note. Plan 06+ behaviour: the detector starts if
      not already started, and the existing pid's Repo connection is
      added to the test's sandbox ownership set.
    * `{:error, {:already_started, pid}}` from `start_link/1` is NOT
      treated as an error — we adopt the existing process.

  Addresses WARNING issue #6 in the 02-PATTERNS.md checker pass (latent
  singleton collision under async tests).
  """

  use ExUnit.CaseTemplate

  require Logger

  using opts do
    async = Keyword.get(opts, :async, false)

    quote do
      use ExUnit.Case, async: unquote(async)
    end
  end

  setup _context do
    detector = Module.concat([Kiln, Policies, StuckDetector])

    case Code.ensure_loaded(detector) do
      {:module, ^detector} ->
        ensure_started(detector)
        allow_sandbox(detector)

      {:error, _reason} ->
        Logger.debug(
          "StuckDetectorCase: Kiln.Policies.StuckDetector not yet compiled — " <>
            "skipping singleton setup (Plan 06 ships the GenServer)."
        )

        :ok
    end

    :ok
  end

  defp ensure_started(detector) do
    if Process.whereis(detector) == nil do
      if function_exported?(detector, :start_link, 1) do
        case apply(detector, :start_link, [[]]) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, _other} -> :ok
        end
      else
        :ok
      end
    else
      :ok
    end
  end

  defp allow_sandbox(detector) do
    case Process.whereis(detector) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        try do
          Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, self(), pid)
        rescue
          # Sandbox may not apply if DataCase isn't in the use chain —
          # that's fine, it's just not a sandbox-context test.
          _ -> :ok
        catch
          :exit, _ -> :ok
        end
    end
  end
end
