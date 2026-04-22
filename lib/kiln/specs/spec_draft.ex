defmodule Kiln.Specs.SpecDraft do
  @moduledoc """
  Ecto schema for `spec_drafts` — inbox / triage rows before promotion into
  `specs` + `spec_revisions` (Phase 8, D-813..D-820).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type inbox_state :: :open | :archived | :promoted
  @type source :: :freeform | :markdown_import | :github_issue | :run_follow_up

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  schema "spec_drafts" do
    field(:title, :string)
    field(:body, :string)

    field(:source, Ecto.Enum,
      values: [:freeform, :markdown_import, :github_issue, :run_follow_up]
    )

    field(:inbox_state, Ecto.Enum, values: [:open, :archived, :promoted])

    field(:archived_at, :utc_datetime_usec)
    belongs_to(:promoted_spec, Kiln.Specs.Spec, foreign_key: :promoted_spec_id)

    field(:github_node_id, :string)
    field(:github_owner, :string)
    field(:github_repo, :string)
    field(:github_issue_number, :integer)

    field(:etag, :string)
    field(:last_synced_at, :utc_datetime_usec)

    field(:source_run_id, :binary_id)
    field(:artifact_refs, {:array, :map}, default: [])
    field(:operator_summary, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [
      :title,
      :body,
      :source,
      :inbox_state,
      :archived_at,
      :promoted_spec_id,
      :github_node_id,
      :github_owner,
      :github_repo,
      :github_issue_number,
      :etag,
      :last_synced_at,
      :source_run_id,
      :artifact_refs,
      :operator_summary
    ])
    |> validate_required([:title, :body, :source])
    |> validate_number(:github_issue_number, greater_than: 0)
    |> foreign_key_constraint(:promoted_spec_id)
  end
end
