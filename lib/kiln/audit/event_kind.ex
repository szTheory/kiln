defmodule Kiln.Audit.EventKind do
  @moduledoc """
  Single source of truth for the `audit_events.event_kind` taxonomy (D-07, D-08, D-85).

  The list declared here is the authoritative 25-value enum (22 shipped in Phase 1;
  3 added in Phase 2 per D-85: `:stage_input_rejected`, `:artifact_written`,
  `:integrity_violation`). Two consumers import from it:

    * Migration `20260418000003_create_audit_events.exs` — builds the
      `event_kind IN (...)` CHECK constraint from `values_as_strings/0` so the
      constraint text is generated, never typed.
    * `Kiln.Audit.Event` — uses `values/0` as the `Ecto.Enum` domain so any
      unknown kind is rejected at the changeset boundary before it reaches
      Postgres.

  The Phase 1 taxonomy is locked at 22 kinds (ROADMAP decision D-08): kinds that
  don't fire until later phases (e.g. `scenario_runner_verdict` in Phase 5) are
  declared up front because adding a CHECK-constraint value mid-project
  requires a transactional migration and is expensive to evolve incrementally.

  Phase 2 extends the taxonomy by 3 kinds per D-85:

    * `:stage_input_rejected` — D-76 boundary rejection when
      `Kiln.Stages.StageWorker.perform/1` fails `Kiln.Stages.ContractRegistry`
      validation before any agent is invoked.
    * `:artifact_written` — D-80 successful CAS write by `Kiln.Artifacts.put/3`.
    * `:integrity_violation` — D-84 CAS re-hash mismatch on read or scrub.

  The 3 new atoms are APPENDED at the end of `@kinds` so the Phase 1 ordering
  is preserved (migration 20260419000001 drops the old CHECK and re-adds a
  25-entry CHECK generated from `values_as_strings/0`).
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
    :escalation_triggered,
    # Phase 2 D-85 extension — append only, never reorder.
    :stage_input_rejected,
    :artifact_written,
    :integrity_violation
  ]

  @doc """
  Returns the canonical ordered list of event kinds as atoms.
  """
  @spec values() :: [atom(), ...]
  def values, do: @kinds

  @doc """
  Returns the canonical ordered list of event kinds as strings, for migration
  CHECK constraint generation and string-payload callers.
  """
  @spec values_as_strings() :: [String.t(), ...]
  def values_as_strings, do: Enum.map(@kinds, &Atom.to_string/1)

  @doc """
  Returns true when the argument is in the taxonomy. Accepts atoms or strings.
  """
  @spec valid?(atom() | String.t()) :: boolean()
  def valid?(kind) when is_atom(kind), do: kind in @kinds
  def valid?(kind) when is_binary(kind), do: kind in values_as_strings()
end
