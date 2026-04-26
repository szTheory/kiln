defmodule Kiln.Specs.SpecDraft do
  @moduledoc """
  Ecto schema for `spec_drafts` — inbox / triage rows before promotion into
  `specs` + `spec_revisions` (Phase 8, D-813..D-820).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type inbox_state :: :open | :archived | :promoted
  @type source ::
          :freeform
          | :markdown_import
          | :github_issue
          | :run_follow_up
          | :template
          | :attached_repo_intake
  @type request_kind :: :feature | :bugfix

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  schema "spec_drafts" do
    field(:title, :string)
    field(:body, :string)

    field(:source, Ecto.Enum,
      values: [
        :freeform,
        :markdown_import,
        :github_issue,
        :run_follow_up,
        :template,
        :attached_repo_intake
      ]
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
    belongs_to(:attached_repo, Kiln.Attach.AttachedRepo, foreign_key: :attached_repo_id)
    field(:request_kind, Ecto.Enum, values: [:feature, :bugfix])
    field(:change_summary, :string)
    field(:acceptance_criteria, {:array, :string}, default: [])
    field(:out_of_scope, {:array, :string}, default: [])

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
      :operator_summary,
      :attached_repo_id,
      :request_kind,
      :change_summary,
      :acceptance_criteria,
      :out_of_scope
    ])
    |> validate_required([:title, :body, :source])
    |> validate_number(:github_issue_number, greater_than: 0)
    |> validate_attached_repo_intake_fields()
    |> foreign_key_constraint(:promoted_spec_id)
    |> foreign_key_constraint(:attached_repo_id)
  end

  defp validate_attached_repo_intake_fields(changeset) do
    if get_field(changeset, :source) == :attached_repo_intake do
      changeset
      |> validate_required([
        :attached_repo_id,
        :request_kind,
        :change_summary
      ])
      |> validate_change(:acceptance_criteria, fn :acceptance_criteria, value ->
        if Enum.empty?(value || []) do
          [acceptance_criteria: "must include at least one item"]
        else
          []
        end
      end)
    else
      changeset
    end
  end
end
