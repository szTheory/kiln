defmodule Kiln.FactoryCircuitBreakerCase do
  @moduledoc """
  ExUnit case template that mirrors `Kiln.StuckDetectorCase` for
  `Kiln.Policies.FactoryCircuitBreaker` (D-139, D-91 precedent —
  scaffold-now-fill-later supervised no-op GenServer). Centralises the
  "start if not started" singleton guard so tests don't hit name
  collisions under async ExUnit, and mirrors the deferred-activation
  pattern established in Phase 2 (the case compiles against a Plan 03-00
  codebase where the real GenServer doesn't exist yet and auto-activates
  once plan 03-04 ships the module).

  Usage:

      use Kiln.FactoryCircuitBreakerCase, async: false

  Composable with `Kiln.DataCase` / `Kiln.ObanCase` — a test can `use`
  both; the circuit-breaker setup runs alongside the DataCase sandbox
  checkout.

  Defensive behaviour:

    * If `Kiln.Policies.FactoryCircuitBreaker` is not yet compiled
      (Wave 0/1 codebase — the GenServer lands in Wave 2), the setup
      block no-ops with a `Logger.debug/1` note.
    * `{:error, {:already_started, pid}}` from `start_link/1` is NOT
      treated as an error — we adopt the existing process.
  """

  use ExUnit.CaseTemplate

  require Logger

  using opts do
    async = Keyword.get(opts, :async, false)

    quote do
      use ExUnit.Case, async: unquote(async)

      alias Kiln.Policies.FactoryCircuitBreaker
    end
  end

  setup _context do
    breaker = Module.concat([Kiln, Policies, FactoryCircuitBreaker])

    case Code.ensure_loaded(breaker) do
      {:module, ^breaker} ->
        ensure_started(breaker)
        allow_sandbox(breaker)

      {:error, _reason} ->
        Logger.debug(
          "FactoryCircuitBreakerCase: Kiln.Policies.FactoryCircuitBreaker " <>
            "not yet compiled — skipping singleton setup (plan 03-04 ships " <>
            "the GenServer)."
        )

        :ok
    end

    :ok
  end

  defp ensure_started(breaker) do
    if Process.whereis(breaker) == nil do
      if function_exported?(breaker, :start_link, 1) do
        case apply(breaker, :start_link, [[]]) do
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

  defp allow_sandbox(breaker) do
    case Process.whereis(breaker) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        try do
          Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, self(), pid)
        rescue
          # Sandbox may not apply if DataCase isn't in the use chain —
          # that's fine, not a sandbox-context test.
          _ -> :ok
        catch
          :exit, _ -> :ok
        end
    end
  end
end
