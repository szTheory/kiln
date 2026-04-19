defmodule Kiln.Audit.EventKind do
  @moduledoc """
  Single source of truth for the `audit_events.event_kind` taxonomy (D-07, D-08).

  The list declared here is the authoritative 22-value enum. Two consumers
  import from it:

    * Migration `20260418000003_create_audit_events.exs` — builds the
      `event_kind IN (...)` CHECK constraint from `values_as_strings/0` so the
      constraint text is generated, never typed.
    * `Kiln.Audit.Event` — uses `values/0` as the `Ecto.Enum` domain so any
      unknown kind is rejected at the changeset boundary before it reaches
      Postgres.

  The taxonomy is locked at Phase 1 (ROADMAP decision D-08): kinds that don't
  fire until later phases (e.g. `scenario_runner_verdict` in Phase 5) are
  declared up front because adding a CHECK-constraint value mid-project
  requires a transactional migration and is expensive to evolve incrementally.
  """

  @kinds [
    :run_state_transitioned,
    :stage_started,
    :stage_completed,
    :stage_failed,
    :external_op_intent_recorded,
    :external_op_action_started,
    :external_op_completed,
    :external_op_failed,
    :secret_reference_resolved,
    :model_routing_fallback,
    :budget_check_passed,
    :budget_check_failed,
    :stuck_detector_alarmed,
    :scenario_runner_verdict,
    :work_unit_created,
    :work_unit_state_changed,
    :git_op_completed,
    :pr_created,
    :ci_status_observed,
    :block_raised,
    :block_resolved,
    :escalation_triggered
  ]

  @doc """
  Returns the canonical ordered list of event kinds as atoms.
  """
  @spec values() :: [atom()]
  def values, do: @kinds

  @doc """
  Returns the canonical ordered list of event kinds as strings, for migration
  CHECK constraint generation and string-payload callers.
  """
  @spec values_as_strings() :: [String.t()]
  def values_as_strings, do: Enum.map(@kinds, &Atom.to_string/1)

  @doc """
  Returns true when the argument is in the taxonomy. Accepts atoms or strings.
  """
  @spec valid?(atom() | String.t()) :: boolean()
  def valid?(kind) when is_atom(kind), do: kind in @kinds
  def valid?(kind) when is_binary(kind), do: kind in values_as_strings()
end
