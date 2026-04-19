defmodule Kiln.Policies do
  @moduledoc """
  Control layer — policy evaluation (budget caps, retries, stuck
  detection per ARCHITECTURE.md §4). Phase 5 ships the
  `Kiln.Policies.StuckDetector` GenServer + `BudgetGuard` + typed
  `BLOCK-01` reasons.

  P1 placeholder — see `Kiln.Specs` for the naming-contract rationale.
  """
end
