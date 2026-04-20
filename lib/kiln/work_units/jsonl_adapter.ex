defmodule Kiln.WorkUnits.JsonlAdapter do
  @moduledoc """
  Export-only JSONL bridge for work-unit snapshots (Phase 4).

  **No import, delete, reset, prune, or `--force` paths** — federation
  hooks only.
  """

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.WorkUnits.{WorkUnit, WorkUnitEvent}

  @doc """
  Renders a newline-delimited JSON snapshot of work units and their
  events for `run_id` (oldest-first within each unit by `occurred_at`).
  """
  @spec export_run(Ecto.UUID.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def export_run(run_id, _opts \\ []) when is_binary(run_id) do
    units = list_units_ordered(run_id)

    lines =
      Enum.flat_map(units, fn wu ->
        [encode_unit(wu) | encode_events(wu.id)]
      end)

    {:ok, Enum.join(lines, "\n")}
  end

  defp list_units_ordered(run_id) do
    from(w in WorkUnit,
      where: w.run_id == ^run_id,
      order_by: [asc: w.inserted_at]
    )
    |> Repo.all()
  end

  defp encode_unit(%WorkUnit{} = wu) do
    Jason.encode!(%{
      "type" => "work_unit",
      "data" => %{
        "id" => wu.id,
        "run_id" => wu.run_id,
        "agent_role" => wu.agent_role,
        "state" => wu.state,
        "priority" => wu.priority,
        "blockers_open_count" => wu.blockers_open_count
      }
    })
  end

  defp encode_events(work_unit_id) do
    from(e in WorkUnitEvent,
      where: e.work_unit_id == ^work_unit_id,
      order_by: [asc: e.occurred_at, asc: e.id]
    )
    |> Repo.all()
    |> Enum.map(fn ev ->
      Jason.encode!(%{
        "type" => "work_unit_event",
        "data" => %{
          "id" => ev.id,
          "work_unit_id" => ev.work_unit_id,
          "event_kind" => ev.event_kind,
          "actor_role" => ev.actor_role,
          "occurred_at" => ev.occurred_at
        }
      })
    end)
  end
end
