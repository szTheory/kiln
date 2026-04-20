defmodule Kiln.Stages.StageRun do
  @moduledoc """
  Ecto schema for a row of the `stage_runs` table — one row per
  per-attempt stage execution (D-82). Hot-path metrics columns
  (`tokens_used`, `cost_usd`, `requested_model`, `actual_model_used`)
  live here rather than in `audit_events.payload` so the Phase 7 cost
  dashboard and the Phase 3 silent-fallback detector can index them
  directly.

  The state field tracks the stage attempt's position in its lifecycle:

    * `:pending` — row inserted, not yet scheduled
    * `:dispatching` — claimed by a dispatcher but not yet in the
      Oban queue (tight window between intent and action; D-14 analog)
    * `:running` — Oban worker is executing the stage
    * `:succeeded` — terminal success; results captured in artifacts
    * `:failed` — terminal failure; `error_summary` populated
    * `:cancelled` — terminal cancellation (parent run escalated or
      operator halted)

  Business identity: the `(run_id, workflow_stage_id, attempt)` triple
  is unique (enforced by `stage_runs_run_stage_attempt_idx`). The stage
  dispatcher consults this before scheduling a retry — attempt N must
  not collide with an existing attempt N row.

  FK to `runs` uses `on_delete: :restrict` (D-81) — runs cannot be
  deleted while any stage_runs reference them (forensic preservation).

  The PK is Postgres-generated via `uuid_generate_v7()`; Ecto needs
  `read_after_writes: true` so it issues `RETURNING id` on INSERT.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  # Kept in sync with the migration's CHECK constraints (hard-coded lists —
  # any change here MUST be paired with a migration that drops + re-adds
  # the corresponding `stage_runs_*_check` constraint).
  @kinds ~w(planning coding testing verifying merge)a
  @agent_roles ~w(planner coder tester reviewer uiux qa_verifier mayor)a
  @states ~w(pending dispatching running succeeded failed cancelled)a
  @sandboxes ~w(none readonly readwrite)a

  @derive {Jason.Encoder,
           only: [
             :id,
             :run_id,
             :workflow_stage_id,
             :kind,
             :agent_role,
             :attempt,
             :state,
             :timeout_seconds,
             :sandbox,
             :tokens_used,
             :cost_usd,
             :requested_model,
             :actual_model_used,
             :error_summary,
             :inserted_at,
             :updated_at
           ]}

  schema "stage_runs" do
    field(:run_id, :binary_id)
    # Matches YAML workflow stages[].id (D-58 format: ^[a-z][a-z0-9_]{1,31}$)
    field(:workflow_stage_id, :string)

    field(:kind, Ecto.Enum, values: @kinds)
    field(:agent_role, Ecto.Enum, values: @agent_roles)
    field(:attempt, :integer, default: 1)
    field(:state, Ecto.Enum, values: @states, default: :pending)

    field(:timeout_seconds, :integer)
    field(:sandbox, Ecto.Enum, values: @sandboxes)

    # D-82: hot-path metrics
    field(:tokens_used, :integer, default: 0)
    field(:cost_usd, :decimal, default: Decimal.new("0.0"))

    # OPS-02 adaptive-fallback pair
    field(:requested_model, :string)
    field(:actual_model_used, :string)

    # Populated only when state = :failed
    field(:error_summary, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @required [:run_id, :workflow_stage_id, :kind, :agent_role, :timeout_seconds, :sandbox]
  @optional [
    :attempt,
    :state,
    :tokens_used,
    :cost_usd,
    :requested_model,
    :actual_model_used,
    :error_summary
  ]

  @doc """
  Build a changeset for INSERT or UPDATE. Enforces the four enum
  domains (kind, agent_role, state, sandbox) at the app layer; the DB
  CHECK constraints are defence-in-depth. Also validates
  `attempt` is in 1..10 (D-74 ceiling), and wires the FK /
  unique-key constraint names so `Repo.insert/1` surfaces a clean
  changeset error on violation rather than a raw `Postgrex.Error`.
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(stage_run, attrs) do
    stage_run
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:state, @states)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:agent_role, @agent_roles)
    |> validate_inclusion(:sandbox, @sandboxes)
    |> validate_number(:attempt, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> foreign_key_constraint(:run_id, name: :stage_runs_run_id_fkey)
    |> unique_constraint([:run_id, :workflow_stage_id, :attempt],
      name: :stage_runs_run_stage_attempt_idx
    )
    |> check_constraint(:kind, name: :stage_runs_kind_check)
    |> check_constraint(:agent_role, name: :stage_runs_agent_role_check)
    |> check_constraint(:state, name: :stage_runs_state_check)
    |> check_constraint(:sandbox, name: :stage_runs_sandbox_check)
    |> check_constraint(:attempt, name: :stage_runs_attempt_range)
    |> check_constraint(:cost_usd, name: :stage_runs_cost_nonneg)
  end

  @doc "The canonical 6-state enum, in logical progression order."
  @spec states() :: [atom(), ...]
  def states, do: @states

  @doc "The five stage kinds (D-58). Mirrors `priv/stage_contracts/v1/<kind>.json`."
  @spec kinds() :: [atom(), ...]
  def kinds, do: @kinds

  @doc "The seven agent roles (D-58)."
  @spec agent_roles() :: [atom(), ...]
  def agent_roles, do: @agent_roles

  @doc "The three sandbox modes (D-58)."
  @spec sandboxes() :: [atom(), ...]
  def sandboxes, do: @sandboxes
end
