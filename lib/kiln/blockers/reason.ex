defmodule Kiln.Blockers.Reason do
  @moduledoc """
  Closed enum of typed block reasons (D-135 / BLOCK-01).

  ALL 9 atoms ship in Phase 3 so consumers pattern-match exhaustively
  from this phase forward — no atom-at-phase-boundary churn.

  Pattern-matchers must raise explicitly on unknown reasons (Elixir's
  atom-match exhaustiveness warning surfaces the gap under
  `elixirc --warnings-as-errors`).

  Real playbooks ship in `priv/playbooks/v1/<reason>.md` (see
  `Kiln.Blockers.PlaybookRegistry`); stubs carry `owning_phase` frontmatter.
  """

  @reasons [
    :missing_api_key,
    :invalid_api_key,
    :rate_limit_exhausted,
    :quota_exceeded,
    :budget_exceeded,
    :policy_violation,
    :gh_auth_expired,
    :gh_permissions_insufficient,
    :unrecoverable_stage_failure
  ]

  @type t ::
          :missing_api_key
          | :invalid_api_key
          | :rate_limit_exhausted
          | :quota_exceeded
          | :budget_exceeded
          | :policy_violation
          | :gh_auth_expired
          | :gh_permissions_insufficient
          | :unrecoverable_stage_failure

  @doc """
  Returns the canonical list of 9 typed block reason atoms (D-135).
  """
  @spec all :: [t()]
  def all, do: @reasons

  @doc """
  Returns `true` when `atom` is one of the 9 typed block reasons.
  Accepts arbitrary terms; non-atoms return `false`.
  """
  @spec valid?(term()) :: boolean()
  def valid?(atom) when is_atom(atom), do: atom in @reasons
  def valid?(_), do: false

  @doc """
  Guard that narrows a term to `t()`. The atom list is duplicated verbatim
  inside the `when` clause because `defguard` bodies cannot reference
  module attributes like `@reasons` — the guard must be expandable at the
  call site. The `all/0` test enforces parity between the two lists so
  drift surfaces loudly.
  """
  defguard is_reason(atom)
           when atom in [
                  :missing_api_key,
                  :invalid_api_key,
                  :rate_limit_exhausted,
                  :quota_exceeded,
                  :budget_exceeded,
                  :policy_violation,
                  :gh_auth_expired,
                  :gh_permissions_insufficient,
                  :unrecoverable_stage_failure
                ]
end
