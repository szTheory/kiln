defmodule Kiln.Blockers.Reason do
  @moduledoc """
  Closed enum of typed block reasons (D-135 / BLOCK-01) plus **advisory**
  soft-budget threshold atoms (Phase 18 COST-02).

  The original **9** atoms are **blocking** — they halt the run via
  `Kiln.Blockers.raise_block/3` and `BlockedError`. Two additional atoms
  (`:budget_threshold_50`, `:budget_threshold_80`) are **notify-only**:
  they appear in `all/0` for playbook + desktop wiring but
  `blocking?/1` returns `false` and `raise_block/3` rejects them with
  `ArgumentError` (non-blocking reasons must not impersonate halts).

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
    :unrecoverable_stage_failure,
    # Phase 18 COST-02 — append only, never reorder.
    :budget_threshold_50,
    :budget_threshold_80
  ]

  @blocking_reasons [
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
          | :budget_threshold_50
          | :budget_threshold_80

  @doc """
  Returns the canonical list of typed reason atoms (blocking + advisory).
  """
  @spec all :: [t()]
  def all, do: @reasons

  @doc """
  Returns `true` when `atom` is one of the declared reason atoms.
  Accepts arbitrary terms; non-atoms return `false`.
  """
  @spec valid?(term()) :: boolean()
  def valid?(atom) when is_atom(atom), do: atom in @reasons
  def valid?(_), do: false

  @doc """
  Returns `true` when `reason` is a **blocking** halt reason.

  Advisory soft-threshold reasons return `false` even though `valid?/1`
  is true — they must never flow through `raise_block/3`.
  """
  @spec blocking?(atom()) :: boolean()
  def blocking?(reason) when is_atom(reason), do: reason in @blocking_reasons
  def blocking?(_), do: false

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
                  :unrecoverable_stage_failure,
                  :budget_threshold_50,
                  :budget_threshold_80
                ]
end
