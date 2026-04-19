defmodule Kiln.BootChecks.Error do
  @moduledoc """
  Raised by `Kiln.BootChecks.run!/0` when a boot-time invariant fails.
  The BEAM exits with this exception's `message/1` printed to stderr, so
  the operator sees exactly which invariant tripped and how to repair it
  without grepping the supervisor's crash log for a `:shutdown` tuple.

  Fields:
    * `:invariant` — atom naming the failing invariant (one of
      `:contexts_compiled`, `:audit_revoke_active`, `:audit_trigger_active`,
      `:required_secrets`).
    * `:details` — map of diagnostic info (the actual SQLSTATE returned,
      the list of missing env vars, etc.).
    * `:remediation_hint` — operator-facing repair instruction string.
      Mirrors Phase 8's typed-block-reason pattern: structured remediation
      beats chat.
  """
  defexception [:invariant, :details, :remediation_hint]

  @impl true
  def message(%__MODULE__{invariant: inv, details: d, remediation_hint: hint}) do
    """

    ┌─────────────────────────────────────────────────────────────┐
    │ Kiln boot check failed — BEAM will NOT start.               │
    └─────────────────────────────────────────────────────────────┘

    Invariant:   #{inspect(inv)}
    Details:     #{inspect(d)}
    Remediation: #{hint || "(see .planning/phases/01-foundation-durability-floor/01-CONTEXT.md D-32)"}
    """
  end
end
