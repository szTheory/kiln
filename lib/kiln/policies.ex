defmodule Kiln.Policies do
  @moduledoc """
  Public API for the Policies context. Home of bounded-autonomy caps
  (Phase 5 `BudgetGuard`), typed blocker producers (Phase 3 BLOCK-01),
  and the `Kiln.Policies.StuckDetector` hook wired into
  `Kiln.Runs.Transitions.transition/3` (Plan 02-06 hook path; Phase 5
  sliding-window body per D-91).

  Phase 2 ships only the `StuckDetector` no-op GenServer — the rest of
  the context arrives in Phase 3 / Phase 5.
  """

  alias Kiln.Policies.StuckDetector

  @doc """
  Delegates to `Kiln.Policies.StuckDetector.check/1`. Called from inside
  `Kiln.Runs.Transitions.transition/3` BEFORE the state column is
  updated, INSIDE the same transaction as the `SELECT ... FOR UPDATE`
  lock. Signature stable through Phase 5 per D-91.

  Returns `:ok` in Phase 2 (no-op body); Phase 5 replaces the GenServer
  body with the sliding-window implementation that may return
  `{:halt, :stuck, payload}` to trigger same-tx escalation.
  """
  @spec check_stuck(map()) :: :ok | {:halt, atom(), map()}
  defdelegate check_stuck(ctx), to: StuckDetector, as: :check
end
