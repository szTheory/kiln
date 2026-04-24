defmodule Kiln.Attach do
  @moduledoc """
  Public boundary for operator attach-source intake.
  """

  import Ecto.Query

  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.BrownfieldPreflight
  alias Kiln.Attach.Continuity
  alias Kiln.Attach.Delivery
  alias Kiln.Attach.SafetyGate
  alias Kiln.Attach.Source
  alias Kiln.Attach.WorkspaceManager
  alias Kiln.Repo

  @type resolve_result :: {:ok, Source.t()} | {:error, Source.error()}
  @type hydrate_result :: {:ok, WorkspaceManager.result()} | {:error, WorkspaceManager.error()}
  @type persist_result :: {:ok, AttachedRepo.t()} | {:error, Ecto.Changeset.t()}
  @type preflight_result :: SafetyGate.result()
  @type brownfield_report :: BrownfieldPreflight.report()
  @type delivery_result :: {:ok, Delivery.prepared()} | {:error, term()}
  @type continuity_result :: {:ok, Continuity.detail()} | {:error, :not_found}
  @type continuity_update_result ::
          {:ok, AttachedRepo.t()} | {:error, :not_found | Ecto.Changeset.t()}
  @type refresh_result ::
          {:ok,
           %{
             source: Source.t(),
             hydrated: WorkspaceManager.result(),
             attached_repo: AttachedRepo.t(),
             ready: map()
           }}
          | {:blocked, map()}
          | {:error, Ecto.Changeset.t() | map()}

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

  @spec preflight_workspace(Source.t(), WorkspaceManager.result(), keyword()) ::
          preflight_result()
  def preflight_workspace(%Source{} = source, %WorkspaceManager{} = hydrated, opts \\ []) do
    SafetyGate.evaluate(source, hydrated, opts)
  end

  @spec evaluate_brownfield_preflight(AttachedRepo.t(), map(), keyword()) :: brownfield_report()
  def evaluate_brownfield_preflight(%AttachedRepo{} = attached_repo, params, opts \\ [])
      when is_map(params) do
    BrownfieldPreflight.evaluate(attached_repo, params, opts)
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

  @spec list_recent_attached_repos(keyword()) :: [Continuity.recent_repo()]
  def list_recent_attached_repos(opts \\ []) do
    Continuity.list_recent_attached_repos(opts)
  end

  @spec get_repo_continuity(Ecto.UUID.t(), keyword()) :: continuity_result()
  def get_repo_continuity(attached_repo_id, opts \\ []) when is_binary(attached_repo_id) do
    Continuity.get_repo_continuity(attached_repo_id, opts)
  end

  @spec mark_repo_selected(Ecto.UUID.t(), keyword()) :: continuity_update_result()
  def mark_repo_selected(attached_repo_id, opts \\ []) when is_binary(attached_repo_id) do
    Continuity.mark_repo_selected(attached_repo_id, opts)
  end

  @spec mark_run_started(Ecto.UUID.t(), keyword()) :: continuity_update_result()
  def mark_run_started(attached_repo_id, opts \\ []) when is_binary(attached_repo_id) do
    Continuity.mark_run_started(attached_repo_id, opts)
  end

  @spec source_from_attached_repo(AttachedRepo.t()) :: Source.t()
  def source_from_attached_repo(%AttachedRepo{} = attached_repo) do
    %Source{
      kind: attached_repo.source_kind,
      input: attached_repo.canonical_input,
      canonical_input: attached_repo.canonical_input,
      canonical_root: attached_repo.canonical_repo_root,
      repo_identity: %{
        provider: attached_repo.repo_provider,
        host: attached_repo.repo_host,
        owner: attached_repo.repo_owner,
        name: attached_repo.repo_name,
        slug: attached_repo.repo_slug
      },
      remote_metadata: %{
        url: attached_repo.remote_url,
        clone_url: attached_repo.clone_url || attached_repo.remote_url,
        default_branch: attached_repo.default_branch || attached_repo.base_branch,
        head_sha: nil
      }
    }
  end

  @spec refresh_attached_repo(AttachedRepo.t(), keyword()) :: refresh_result()
  def refresh_attached_repo(%AttachedRepo{} = attached_repo, opts \\ []) do
    source = source_from_attached_repo(attached_repo)

    with {:ok, hydrated} <- hydrate_workspace(source, opts),
         {:ok, refreshed_repo} <- create_or_update_attached_repo(source, hydrated),
         {:ok, ready} <- preflight_workspace(source, hydrated, opts) do
      {:ok,
       %{
         source: source,
         hydrated: hydrated,
         attached_repo: refreshed_repo,
         ready: ready
       }}
    end
  end

  @spec prepare_delivery(
          Kiln.Runs.Run.t() | Ecto.UUID.t(),
          Ecto.UUID.t(),
          Ecto.UUID.t(),
          keyword()
        ) ::
          delivery_result()
  def prepare_delivery(run_or_id, attached_repo_id, stage_id, opts \\ []) do
    Delivery.prepare(run_or_id, attached_repo_id, stage_id, opts)
  end

  @spec enqueue_delivery(
          Kiln.Runs.Run.t() | Ecto.UUID.t(),
          Ecto.UUID.t(),
          Ecto.UUID.t(),
          keyword()
        ) ::
          delivery_result()
  def enqueue_delivery(run_or_id, attached_repo_id, stage_id, opts \\ []) do
    Delivery.enqueue_delivery(run_or_id, attached_repo_id, stage_id, opts)
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
