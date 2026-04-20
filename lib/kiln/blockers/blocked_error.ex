defmodule Kiln.Blockers.BlockedError do
  @moduledoc """
  Typed exception raised from producer sites (BudgetGuard, RunDirector,
  sandbox env allowlist, etc.) when a run hits a block condition.

  Callers should convert this into a
  `Kiln.Runs.Transitions.transition(..., :blocked, ...)` plus render a
  playbook for the operator via `Kiln.Blockers.PlaybookRegistry.render/2`.

  Mirrors the shape of `Kiln.Runs.IllegalTransitionError` (Plan 02-06).

  Fields:
    * `:reason`  — one of the 9 atoms in `Kiln.Blockers.Reason.all/0`
    * `:run_id`  — the run UUID the block was raised against, or `nil`
    * `:context` — caller-supplied context map used for playbook `{var}`
      substitution
    * `:message` — rendered operator-facing message
  """

  defexception [:reason, :run_id, :context, :message]

  @type t :: %__MODULE__{
          reason: Kiln.Blockers.Reason.t(),
          run_id: term() | nil,
          context: map(),
          message: String.t()
        }

  @impl true
  def exception(fields) do
    reason = Keyword.fetch!(fields, :reason)
    run_id = Keyword.get(fields, :run_id)
    context = Keyword.get(fields, :context, %{})

    msg =
      "run blocked — reason=#{inspect(reason)} run_id=#{inspect(run_id)} context=#{inspect(context)}"

    struct!(__MODULE__,
      reason: reason,
      run_id: run_id,
      context: context,
      message: msg
    )
  end
end
