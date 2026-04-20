defmodule Kiln.WorkUnits.ReadyQuery do
  @moduledoc """
  Pure query helpers for the work-unit ready queue (AGENT-04).

  Readiness is **query-driven**: `blockers_open_count == 0`, non-terminal
  active states, run-scoped, ordered by `priority` then `inserted_at`.
  """

  import Ecto.Query

  alias Kiln.WorkUnits.WorkUnit

  @doc """
  Work units eligible to be claimed for `run_id`, optionally filtered to
  `agent_role`.
  """
  @spec ready_for_run(Ecto.UUID.t(), atom() | nil) :: Ecto.Query.t()
  def ready_for_run(run_id, agent_role \\ nil) do
    q =
      from w in WorkUnit,
        where: w.run_id == ^run_id,
        where: w.state in [:open, :blocked],
        where: w.blockers_open_count == 0,
        order_by: [asc: w.priority, asc: w.inserted_at]

    if agent_role do
      from w in q, where: w.agent_role == ^agent_role
    else
      q
    end
  end
end
