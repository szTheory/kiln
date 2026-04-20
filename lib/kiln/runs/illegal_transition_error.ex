defmodule Kiln.Runs.IllegalTransitionError do
  @moduledoc """
  Raised by `Kiln.Runs.Transitions.transition!/3` (Plan 02-06) when a
  caller attempts a state change that is not in the D-87 allowed-edge
  matrix (or when the run does not exist).

  Message template (per D-89) includes the substrings `"from "`, `"to "`
  and `"allowed from"` so operators see the exact forbidden edge plus the
  set of legal next states. Tests assert on the substring shape, not the
  full rendered message, so minor wording drift does not break them.

  Fields:

    * `:run_id`  — the run UUID the caller asked to transition, or
      `:not_found` when no row exists for that UUID.
    * `:from`    — the current run state (atom) or `:not_found`.
    * `:to`      — the attempted next state (atom).
    * `:allowed` — the list of atoms legal from `:from` per the D-87
      matrix plus the cross-cutting `:escalated`/`:failed` pair.

  Raising path only — the tuple-returning default (`transition/3`) is the
  preferred API everywhere except tests and imperative admin tools
  (per D-88).
  """
  defexception [:run_id, :from, :to, :allowed, :message]

  @impl true
  def exception(fields) do
    fields = Keyword.new(fields)
    run_id = Keyword.get(fields, :run_id)
    from = Keyword.get(fields, :from)
    to = Keyword.get(fields, :to)
    allowed = Keyword.get(fields, :allowed, [])

    msg =
      "illegal run state transition for run_id=#{inspect(run_id)}: " <>
        "from #{inspect(from)} to #{inspect(to)}; " <>
        "allowed from #{inspect(from)}: #{inspect(allowed)}"

    fields =
      fields
      |> Keyword.put_new(:allowed, allowed)
      |> Keyword.put(:message, msg)

    struct!(__MODULE__, fields)
  end
end
