defmodule Kiln.Runs.RunSupervisor do
  @moduledoc """
  `DynamicSupervisor` hosting per-run subtrees (D-95).

  Every in-flight run is represented by exactly one child of this
  supervisor — a `Kiln.Runs.RunSubtree` `:transient` supervisor keyed
  by `run_id` via the `Kiln.RunRegistry` `Registry`. `RunDirector`
  (Plan 02-07) adds children here on boot-scan / periodic-scan and
  monitors them so a subtree crash is observed and logged.

  ## `max_children: 10` — D-95 solo-op ceiling

  The cap is the solo-op concurrent-run ceiling per D-95 / D-68's pool
  budget (Oban aggregate 16 + RunDirector + StuckDetector + LiveView
  pressure = ~24 peak pressure vs `pool_size: 20` checkouts — adding
  10 concurrently-live per-run subtrees fits within budget). When the
  ceiling is hit, `DynamicSupervisor.start_child/2` returns
  `{:error, :max_children}`; `RunDirector` logs the failure and leaves
  the overflow run in the DB — the next periodic scan rehydrates it
  as a slot frees. A box needing >10 concurrent runs is a v2 PARA-01
  concern, not a silent-overflow bug.

  ## Strategy

  `:one_for_one` — one run's subtree blowing up MUST NOT cascade into
  other runs' subtrees. Per-run isolation is ORCH-02's core guarantee
  and is exercised end-to-end by
  `test/integration/run_subtree_crash_test.exs`.
  """

  use DynamicSupervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts), do: DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one, max_children: 10)
  end
end
