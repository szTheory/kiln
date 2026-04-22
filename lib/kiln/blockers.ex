defmodule Kiln.Blockers do
  @moduledoc """
  Typed block-reason surface (BLOCK-01 / D-135 / D-136).

  Public API:
    * `raise_block/3` — producers (BudgetGuard, RunDirector, sandbox env
      allowlist) raise a typed `BlockedError` here instead of a freeform
      string. Callers pattern-match on `reason` exhaustively.
    * `fetch/1` / `render/2` — delegate to `Kiln.Blockers.PlaybookRegistry`.
      `render/2` substitutes `{var}` tokens from a caller-provided context
      for operator-facing surfaces (desktop notification in P3, unblock
      panel in P8).

  The enum `Kiln.Blockers.Reason` is the closed SSOT (blocking + advisory
  atoms); the registry `Kiln.Blockers.PlaybookRegistry` proves compile-time
  that every atom has a corresponding playbook markdown file.

  This module is a sub-facade under the `Kiln.Policies` bounded context —
  it is NOT itself one of the 13 bounded contexts pinned by D-97 (the
  blockers subsystem is a policy concern that lives alongside `BudgetGuard`
  and `StuckDetector`).
  """

  alias Kiln.Blockers.{BlockedError, PlaybookRegistry, Reason}

  @doc """
  Raises `Kiln.Blockers.BlockedError` with the given reason, run_id, and
  context. Validates the reason against `Kiln.Blockers.Reason.valid?/1`
  first — unknown reasons raise `ArgumentError` instead so callers can't
  leak a freeform atom into the block pipeline (T-03-02-01 mitigation).
  """
  @spec raise_block(Reason.t(), term(), map()) :: no_return()
  def raise_block(reason, run_id, context \\ %{}) when is_atom(reason) do
    if not Reason.valid?(reason) do
      raise ArgumentError,
            "Kiln.Blockers.raise_block/3 received unknown reason: #{inspect(reason)}"
    end

    unless Reason.blocking?(reason) do
      raise ArgumentError,
            "Kiln.Blockers.raise_block/3 non-blocking reason #{inspect(reason)} — use advisory/notify paths instead"
    end

    raise BlockedError, reason: reason, run_id: run_id, context: context
  end

  defdelegate fetch(reason), to: PlaybookRegistry
  defdelegate render(reason, context), to: PlaybookRegistry
end
