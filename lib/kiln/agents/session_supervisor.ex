defmodule Kiln.Agents.SessionSupervisor do
  @moduledoc """
  Per-run agent-session `DynamicSupervisor` (D-141 child #3 of the
  Phase-3 supervision-tree additions).

  **MVP EMPTY in Phase 3** — this module ships the supervisor shape so
  downstream plans (especially Phase 4's work-unit / agent-role tree)
  can hang `Mayor / Planner / Coder / Tester / Reviewer / UIUX /
  QAVerifier` agent processes under it without a supervision-tree
  migration.

  Mirrors `Kiln.Runs.RunSupervisor` exactly — `:one_for_one` strategy,
  transient children registered at runtime. Phase 4 adds
  `max_children` and registry wiring.
  """

  use DynamicSupervisor

  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
