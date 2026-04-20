defmodule Kiln.Repo.Migrations.CreateRuns do
  @moduledoc """
  Creates the `runs` table — the top-level execution-layer entity per
  D-86..D-88, D-94. One row per orchestrated run; the 9-state enum (D-86)
  tracks the run's position in the `queued → planning → coding → testing
  → verifying → (merged | failed | escalated)` state machine (plus
  `:blocked` wired now for Phase 3 producers per BLOCK-01).

  Structural clone of `20260418000006_create_external_operations.exs`:
  uuidv7 PK (via `uuid_generate_v7()` default), enum CHECK via
  `Enum.map_join/3`, owner-transfer + kiln_app grants (D-48), partial
  indexes for the RunDirector's `list_active/0` query (D-92).

  Key columns:

    * `workflow_id` + `workflow_version` — composite ref to the YAML
      workflow definition (D-55 versioning)
    * `workflow_checksum` — sha256 of the compiled graph at run start;
      D-94 rehydration-time integrity check surfaces workflow drift
      under a running run
    * `model_profile_snapshot` (jsonb) — D-57 role→model mapping frozen
      at run start so actual cost is attributable even if the registry
      mutates mid-run
    * `caps_snapshot` (jsonb) — D-56 hard caps (retries, USD, elapsed,
      stage duration) frozen at run start
    * `correlation_id` — threads through every audit event + log line
      (OBS-01 propagation)
    * `tokens_used_usd` + `elapsed_seconds` — hot-path counters for
      Phase 5 bounded-autonomy circuit breaker
    * `escalation_reason` + `escalation_detail` — typed payload when
      state reaches `:escalated` (null otherwise)

  Reversibility: `def change` with 2-arg `execute/2` for every DDL
  escape — `mix ecto.rollback` restores a pre-migration schema.
  """

  use Ecto.Migration

  @states ~w(queued planning coding testing verifying blocked merged failed escalated)

  def change do
    create table(:runs, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(:workflow_id, :text, null: false)
      add(:workflow_version, :integer, null: false)
      # D-94: sha256 of the compiled graph at run start; asserted on rehydration
      add(:workflow_checksum, :text, null: false)

      add(:state, :text, null: false, default: "queued")

      # D-57: role→model map frozen at run start
      add(:model_profile_snapshot, :map, null: false, default: %{})
      # D-56: hard caps frozen at run start
      add(:caps_snapshot, :map, null: false, default: %{})

      add(:correlation_id, :text, null: false)

      add(:tokens_used_usd, :decimal, precision: 18, scale: 6, null: false, default: 0)
      add(:elapsed_seconds, :integer, null: false, default: 0)

      # Populated only when state = :escalated
      add(:escalation_reason, :text)
      add(:escalation_detail, :map)

      timestamps(type: :utc_datetime_usec)
    end

    # 9-state enum CHECK (D-86). Reversible via 2-arg execute.
    states_list = Enum.map_join(@states, ", ", &"'#{&1}'")

    execute(
      """
      ALTER TABLE runs
        ADD CONSTRAINT runs_state_check
        CHECK (state IN (#{states_list}))
      """,
      "ALTER TABLE runs DROP CONSTRAINT runs_state_check"
    )

    # D-94: workflow_checksum must be 64-char lowercase hex (sha256 hex form).
    # Validated at app layer too (validate_format on changeset); DB CHECK is
    # the defence-in-depth floor.
    execute(
      "ALTER TABLE runs ADD CONSTRAINT runs_workflow_checksum_format CHECK (workflow_checksum ~ '^[0-9a-f]{64}$')",
      "ALTER TABLE runs DROP CONSTRAINT runs_workflow_checksum_format"
    )

    # Indexes — canonical query shapes:
    # 1. (state) — drives RunDirector's boot-time scan for live state distribution
    create(index(:runs, [:state], name: :runs_state_idx))

    # 2. Partial index on active (non-terminal) states — specifically optimises
    # `Kiln.Runs.list_active/0` which RunDirector calls on boot (D-92) and
    # every 30 seconds defensive scan. Postgres uses this index in preference
    # to the full state index when the query WHERE matches the partial predicate.
    create(
      index(:runs, [:state],
        where: "state IN ('queued','planning','coding','testing','verifying','blocked')",
        name: :runs_active_state_idx
      )
    )

    # 3. (workflow_id, workflow_version) — "show me all runs against this
    # workflow version" (Phase 7 UI + dogfood-phase forensics).
    create(index(:runs, [:workflow_id, :workflow_version], name: :runs_workflow_idx))

    # 4. (correlation_id) — OBS-01 thread-id lookup for cross-run tracing.
    create(index(:runs, [:correlation_id], name: :runs_correlation_id_idx))

    # 5. (inserted_at) — chronological scan for Phase 7 run-board and GC.
    create(index(:runs, [:inserted_at], name: :runs_inserted_at_idx))

    # D-48: ownership + grants. The migration may run as a connecting
    # superuser; owner transfer keeps DDL authority centralised on
    # kiln_owner. kiln_app gets INSERT/SELECT/UPDATE (runs mutate via
    # transitions) but NOT DELETE — runs are a forensic record (terminal
    # runs get GC'd by a separate kiln_owner-role worker in a later phase).
    execute(
      "ALTER TABLE runs OWNER TO kiln_owner",
      "ALTER TABLE runs OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT, UPDATE ON runs TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE ON runs FROM kiln_app"
    )
  end
end
