defmodule Kiln.Policies.FactoryCircuitBreaker do
  @moduledoc """
  Global cost-runaway circuit breaker (D-139). **Scaffolded no-op in
  Phase 3** — same scaffold-now-fill-later pattern as
  `Kiln.Policies.StuckDetector` (D-91 precedent, D-139 application).

  Phase 5 replaces ONLY the `handle_call/3` body with the sliding-window
  threshold logic: read aggregate spend over the last 60 minutes from
  audit events / `external_operations` `result_payload`s, compare to a
  configurable threshold, and on breach emit `factory_circuit_opened`
  audit event + halt the run via `Kiln.Blockers.raise_block/3` with
  reason `:budget_exceeded` (factory-wide, distinct from per-run
  `:budget_exceeded` raised by `Kiln.Agents.BudgetGuard`).

  The audit event kinds `factory_circuit_opened` / `factory_circuit_closed`
  are already declared in `Kiln.Audit.EventKind` (Plan 03-03 / D-145), so
  Phase 5 fills the body without a new schema migration.

  Stable contract for callers (BudgetGuard, etc.):

      check(ctx :: map()) :: :ok | {:halt, reason :: atom(), payload :: map()}

  Supervision: `:permanent` singleton under `Kiln.Supervisor` (child spec
  added in Plan 03-11 / Wave 5 supervision-tree wiring per D-141). This
  plan only ships the module.
  """

  use GenServer

  @doc """
  Starts the singleton. Intended to be called once from
  `Kiln.Application.start/2` (Plan 03-11); tests that need the breaker
  alive should `use Kiln.FactoryCircuitBreakerCase` which handles the
  start-if-not-started dance and tolerates
  `{:error, {:already_started, _}}` so async test suites don't collide
  on the globally-registered name.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Synchronous hook intended to be called from inside
  `Kiln.Agents.BudgetGuard.check!/2` (pre-LLM-call hook — D-139). Returns
  `:ok` in Phase 3 (no-op body); Phase 5 replaces only the
  `handle_call/3` body with the sliding-window threshold logic.

  Signature is locked through Phase 5 — callers never change.
  """
  @spec check(map()) :: :ok | {:halt, atom(), map()}
  def check(ctx) when is_map(ctx) do
    GenServer.call(__MODULE__, {:check, ctx})
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:check, _ctx}, _from, state) do
    # Phase 3: no-op — the hook PATH is the behavior to exercise. Phase 5
    # fills the sliding-window body. Stable return shape:
    #   :ok | {:halt, reason :: atom(), payload :: map()}
    # Callers (Kiln.Agents.BudgetGuard) will decode `{:halt, _, _}` as a
    # typed-block raise via Kiln.Blockers.raise_block/3.
    {:reply, :ok, state}
  end

  # Defensive catch-all so the :permanent breaker doesn't crash on stray
  # messages delivered to its mailbox (mirrors the RunDirector /
  # StuckDetector pattern for long-lived, named singletons).
  @impl true
  def handle_info(_msg, state), do: {:noreply, state}
end
