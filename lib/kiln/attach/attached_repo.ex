defmodule Kiln.Attach.AttachedRepo do
  @moduledoc """
  Durable metadata for one attached repository and its managed workspace.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  @source_kinds ~w(local_path github_url)a
  @repo_providers ~w(local github)a

  schema "attached_repos" do
    field(:source_kind, Ecto.Enum, values: @source_kinds)
    field(:repo_provider, Ecto.Enum, values: @repo_providers)
    field(:repo_host, :string)
    field(:repo_owner, :string)
    field(:repo_name, :string)
    field(:repo_slug, :string)
    field(:canonical_input, :string)
    field(:canonical_repo_root, :string)
    field(:source_fingerprint, :string)
    field(:workspace_key, :string)
    field(:workspace_path, :string)
    field(:remote_url, :string)
    field(:clone_url, :string)
    field(:default_branch, :string)
    field(:base_branch, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @required [
    :source_kind,
    :repo_provider,
    :repo_name,
    :repo_slug,
    :canonical_input,
    :source_fingerprint,
    :workspace_key,
    :workspace_path,
    :base_branch
  ]

  @optional [
    :repo_host,
    :repo_owner,
    :canonical_repo_root,
    :remote_url,
    :clone_url,
    :default_branch
  ]

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(struct_or_cs, attrs) do
    struct_or_cs
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:source_kind, @source_kinds)
    |> validate_inclusion(:repo_provider, @repo_providers)
    |> unique_constraint(:source_fingerprint, name: :attached_repos_source_fingerprint_idx)
    |> unique_constraint(:workspace_key, name: :attached_repos_workspace_key_idx)
  end
end
