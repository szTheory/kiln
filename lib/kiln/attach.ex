defmodule Kiln.Attach do
  @moduledoc """
  Public boundary for operator attach-source intake.
  """

  import Ecto.Query

  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.SafetyGate
  alias Kiln.Attach.Source
  alias Kiln.Attach.WorkspaceManager
  alias Kiln.Repo

  @type resolve_result :: {:ok, Source.t()} | {:error, Source.error()}
  @type hydrate_result :: {:ok, WorkspaceManager.result()} | {:error, WorkspaceManager.error()}
  @type persist_result :: {:ok, AttachedRepo.t()} | {:error, Ecto.Changeset.t()}
  @type preflight_result :: SafetyGate.result()

  @spec resolve_source(String.t(), keyword()) :: resolve_result()
  def resolve_source(raw_input, opts \\ []) when is_binary(raw_input) do
    Source.resolve(raw_input, opts)
  end

  @spec validate_source(String.t(), keyword()) :: resolve_result()
  def validate_source(raw_input, opts \\ []) when is_binary(raw_input) do
    Source.resolve(raw_input, opts)
  end

  @spec hydrate_workspace(Source.t(), keyword()) :: hydrate_result()
  def hydrate_workspace(%Source{} = source, opts \\ []) do
    WorkspaceManager.hydrate(source, opts)
  end

  @spec create_or_update_attached_repo(Source.t(), WorkspaceManager.result()) :: persist_result()
  def create_or_update_attached_repo(%Source{} = source, %WorkspaceManager{} = hydrated) do
    attrs = attached_repo_attrs(source, hydrated)

    %AttachedRepo{}
    |> AttachedRepo.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :source_fingerprint,
      returning: true
    )
  end

  @spec preflight_workspace(Source.t(), WorkspaceManager.result(), keyword()) :: preflight_result()
  def preflight_workspace(%Source{} = source, %WorkspaceManager{} = hydrated, opts \\ []) do
    SafetyGate.evaluate(source, hydrated, opts)
  end

  @spec get_attached_repo(Ecto.UUID.t()) :: {:ok, AttachedRepo.t()} | {:error, :not_found}
  def get_attached_repo(id) when is_binary(id) do
    case Repo.get(AttachedRepo, id) do
      %AttachedRepo{} = attached_repo -> {:ok, attached_repo}
      nil -> {:error, :not_found}
    end
  end

  @spec get_attached_repo_by_workspace_key(String.t()) ::
          {:ok, AttachedRepo.t()} | {:error, :not_found}
  def get_attached_repo_by_workspace_key(workspace_key) when is_binary(workspace_key) do
    case Repo.one(from(a in AttachedRepo, where: a.workspace_key == ^workspace_key)) do
      %AttachedRepo{} = attached_repo -> {:ok, attached_repo}
      nil -> {:error, :not_found}
    end
  end

  defp attached_repo_attrs(source, hydrated) do
    %{
      source_kind: source.kind,
      repo_provider: source.repo_identity.provider,
      repo_host: source.repo_identity.host,
      repo_owner: source.repo_identity.owner,
      repo_name: source.repo_identity.name,
      repo_slug: source.repo_identity.slug,
      canonical_input: source.canonical_input,
      canonical_repo_root: source.canonical_root,
      source_fingerprint: source_fingerprint(source),
      workspace_key: hydrated.workspace_key,
      workspace_path: hydrated.workspace_path,
      remote_url: hydrated.remote_url,
      clone_url: source.remote_metadata.clone_url,
      default_branch: hydrated.base_branch,
      base_branch: hydrated.base_branch
    }
  end

  defp source_fingerprint(%Source{kind: :local_path, canonical_root: canonical_root}) do
    "local_path:#{canonical_root}"
  end

  defp source_fingerprint(%Source{kind: :github_url, canonical_input: canonical_input}) do
    "github_url:#{canonical_input}"
  end
end
