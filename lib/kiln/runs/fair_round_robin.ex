defmodule Kiln.Runs.FairRoundRobin do
  @moduledoc """
  Deterministic **round-robin** ordering over active runs (PARA-01 / D-01).

  Used by `Kiln.Runs.RunDirector` so scan-order admission is not strict FIFO
  by insertion alone: among the current active set, the next run after the
  persisted **`cursor`** (a `run_id` string) is considered first, wrapping.

  ## Algorithm

  1. **Stable sort** by `{inserted_at asc, id asc}`.
  2. If **`cursor` is `nil`**, return the sorted list (degenerate RR = FIFO
     under the tie-break).
  3. If **`cursor`** is set, find its index in the sorted list. If missing
     (stale cursor), treat as **`nil`** (same as step 2).
  4. **Rotate** so the element **after** the cursor is first:
     `drop(sorted, idx + 1) ++ take(sorted, idx + 1)`.
  """

  alias Kiln.Runs.Run

  @spec order([Run.t()], String.t() | nil) :: [Run.t()]
  def order(runs, cursor)

  def order([], _cursor), do: []

  def order(runs, cursor) when is_list(runs) do
    sorted = Enum.sort_by(runs, fn r -> {r.inserted_at, r.id} end)

    case cursor do
      nil ->
        sorted

      cur when is_binary(cur) ->
        case Enum.find_index(sorted, &(&1.id == cur)) do
          nil -> sorted
          idx -> Enum.drop(sorted, idx + 1) ++ Enum.take(sorted, idx + 1)
        end
    end
  end
end
