defmodule Kiln.Runs.Run do
  @moduledoc """
  Ecto schema for a row of the `runs` table — one row per orchestrated
  run (D-86..D-88, D-94). The state field tracks the run's position in
  the 9-state machine:

    * `:queued` — created, awaiting dispatcher
    * `:planning` — Planner agent is preparing the plan
    * `:coding` — Coder agent is implementing against the plan
    * `:testing` — Tester agent is running tests against the code
    * `:verifying` — QA Verifier is evaluating against scenarios
    * `:blocked` — typed-reason halt awaiting operator unblock
      (Phase 3 wires producers; matrix edge lives here now)
    * `:merged` — terminal success (PR merged / build promoted)
    * `:failed` — terminal failure (verification failed beyond retry)
    * `:escalated` — terminal halt (stuck detector / cap-exceeded /
      unrecoverable)

  Per D-87, the full transition matrix is owned by `Kiln.Runs.Transitions`
  (Plan 06) — this schema only exposes the state domain and a
  transition-specific changeset for use by that command module.

  ## Phase 5 — bounded autonomy + stuck detector (ORCH-06 / OBS-04)

  * `governed_attempt_count` — durable counter for governed attempts; only
    `Transitions` (inside a `FOR UPDATE` transaction) may increment it.
  * `stuck_signal_window` — jsonb array of recent failure signals
    (`%{...}` maps) consumed by `Kiln.Policies.StuckWindow`; same write discipline
    as the counter.

  The PK is Postgres-generated via `uuid_generate_v7()` (migration
  20260419000002); Ecto needs `read_after_writes: true` so it issues
  `RETURNING id` on INSERT. This is the same pattern as
  `Kiln.Audit.Event` and `Kiln.ExternalOperations.Operation`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  # D-86: 9-state enum. Kept in sync with the migration's CHECK constraint
  # (hard-coded list — any change here MUST be paired with a migration that
  # drops + re-adds `runs_state_check`).
  @states ~w(queued planning coding testing verifying blocked merged failed escalated)a
  @active_states ~w(queued planning coding testing verifying blocked)a
  @terminal_states ~w(merged failed escalated)a

  @derive {Jason.Encoder,
           only: [
             :id,
             :workflow_id,
             :workflow_version,
             :workflow_checksum,
             :state,
             :model_profile_snapshot,
             :caps_snapshot,
             :correlation_id,
             :tokens_used_usd,
             :elapsed_seconds,
             :governed_attempt_count,
             :stuck_signal_window,
             :escalation_reason,
             :escalation_detail,
             :inserted_at,
             :updated_at
           ]}

  schema "runs" do
    field(:workflow_id, :string)
    field(:workflow_version, :integer)
    # D-94: sha256 hex of compiled graph at run-start; rehydration asserts match
    field(:workflow_checksum, :string)

    field(:state, Ecto.Enum, values: @states, default: :queued)

    # D-57: role→model mapping frozen at run start
    field(:model_profile_snapshot, :map, default: %{})
    # D-56: hard caps frozen at run start
    field(:caps_snapshot, :map, default: %{})

    field(:correlation_id, :string)

    field(:tokens_used_usd, :decimal, default: Decimal.new("0.0"))
    field(:elapsed_seconds, :integer, default: 0)

    field(:governed_attempt_count, :integer, default: 0)
    field(:stuck_signal_window, {:array, :map}, default: [])

    # Populated only when state = :escalated
    field(:escalation_reason, :string)
    field(:escalation_detail, :map)

    # Phase 6 — last GitHub delivery snapshot (PR refs + checks summary) for GIT-03.
    field(:github_delivery_snapshot, :map, default: %{})

    # Phase 19 — last consumed `operator_feedback_received` audit id (FEEDBACK-01).
    field(:operator_nudge_last_audit_id, :binary_id)

    has_one(:post_mortem, Kiln.Runs.PostMortem, foreign_key: :run_id)

    timestamps(type: :utc_datetime_usec)
  end

  @required [:workflow_id, :workflow_version, :workflow_checksum, :correlation_id]
  @optional [
    :state,
    :model_profile_snapshot,
    :caps_snapshot,
    :tokens_used_usd,
    :elapsed_seconds,
    :governed_attempt_count,
    :stuck_signal_window,
    :escalation_reason,
    :escalation_detail,
    :github_delivery_snapshot,
    :operator_nudge_last_audit_id
  ]

  @doc """
  Build a changeset for the insert path (creating a new run). Enforces
  the 9-state enum domain at the app layer; the DB CHECK catches any
  bypass, but this gives a clean changeset-level error before the
  round-trip. Also validates the `workflow_checksum` format (64-char
  lowercase hex) — mirror of the DB CHECK added by migration
  20260419000002.
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:state, @states)
    |> validate_format(:workflow_checksum, ~r/^[0-9a-f]{64}$/)
    |> check_constraint(:state, name: :runs_state_check)
    |> check_constraint(:workflow_checksum, name: :runs_workflow_checksum_format)
  end

  @doc """
  State-transition changeset — used by `Kiln.Runs.Transitions` (Plan 06)
  for pure state-column updates. Narrower than `changeset/2`: only the
  fields that can change during a transition are castable.

  The `_meta` third arg is reserved for Plan 06 to pass transition-time
  context (e.g. `%{reason: :verifier_rejected, stage_run_id: ...}`) that
  a future schema iteration may want to fold into escalation_detail.
  """
  @spec transition_changeset(t() | Ecto.Changeset.t(), map(), map()) :: Ecto.Changeset.t()
  def transition_changeset(run, attrs, _meta \\ %{}) do
    run
    |> cast(attrs, [
      :state,
      :escalation_reason,
      :escalation_detail,
      :tokens_used_usd,
      :elapsed_seconds,
      :governed_attempt_count,
      :stuck_signal_window,
      :github_delivery_snapshot
    ])
    |> validate_required([:state])
    |> validate_inclusion(:state, @states)
    |> check_constraint(:state, name: :runs_state_check)
  end

  @doc "The canonical 9-state enum (D-86), in logical progression order."
  @spec states() :: [atom(), ...]
  def states, do: @states

  @doc "The three terminal states (`:merged`, `:failed`, `:escalated`)."
  @spec terminal_states() :: [atom(), ...]
  def terminal_states, do: @terminal_states

  @doc """
  The six non-terminal states — the domain RunDirector's `list_active/0`
  scan filters on (D-92).
  """
  @spec active_states() :: [atom(), ...]
  def active_states, do: @active_states

  @doc """
  Narrow changeset for Phase 19 operator-nudge consumption cursor updates.
  """
  @spec nudge_cursor_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def nudge_cursor_changeset(run, attrs) do
    run
    |> cast(attrs, [:operator_nudge_last_audit_id])
  end
end
