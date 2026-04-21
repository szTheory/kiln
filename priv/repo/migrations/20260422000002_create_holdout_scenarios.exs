defmodule Kiln.Repo.Migrations.CreateHoldoutScenarios do
  @moduledoc """
  Phase 5 (SPEC-04 prep): `holdout_scenarios` — verifier-only scenario bodies
  linked to a `specs` row (D-S02a).

  **Security:** `kiln_owner` owns the table; **no** `GRANT` to `kiln_app` — the
  runtime role must not read holdout plaintext. Plan 05-04 adds a narrow
  verifier role + `REVOKE SELECT` reinforcement + `VerifierReadRepo`.
  """

  use Ecto.Migration

  def change do
    create table(:holdout_scenarios, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(
        :spec_id,
        references(:specs, type: :binary_id, on_delete: :restrict),
        null: false
      )

      add(:label, :text, null: false)
      add(:body, :text, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      unique_index(:holdout_scenarios, [:spec_id, :label],
        name: :holdout_scenarios_spec_label_uidx
      )
    )

    execute(
      "ALTER TABLE holdout_scenarios OWNER TO kiln_owner",
      "ALTER TABLE holdout_scenarios OWNER TO current_user"
    )
  end
end
