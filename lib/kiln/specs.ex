defmodule Kiln.Specs do
  @moduledoc """
  Intent layer — versioned markdown specs and scenario manifests (Phase 5).

  CRUD here is limited to what Plans 05-02+ need before LiveView ships in 05-06.

  Phase 8 adds **inbox drafts** (`spec_drafts`) with promote/archive flows (D-813..D-820).
  """

  import Ecto.Query

  alias Kiln.Audit
  alias Kiln.Repo

  alias Kiln.Specs.{
    GitHubIssueImporter,
    ScenarioCompiler,
    ScenarioParser,
    Spec,
    SpecDraft,
    SpecRevision
  }

  @doc """
  Latest revision for a spec by `inserted_at` (append-only bodies; newest wins).
  """
  @spec latest_revision_for_spec(Ecto.UUID.t()) :: SpecRevision.t() | nil
  def latest_revision_for_spec(spec_id) do
    from(r in SpecRevision,
      where: r.spec_id == ^spec_id,
      order_by: [desc: r.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @spec create_spec(map()) :: {:ok, Spec.t()} | {:error, Ecto.Changeset.t()}
  def create_spec(attrs) do
    %Spec{}
    |> Spec.changeset(attrs)
    |> Repo.insert()
  end

  @spec create_revision(Spec.t(), map()) :: {:ok, SpecRevision.t()} | {:error, Ecto.Changeset.t()}
  def create_revision(%Spec{} = spec, attrs) do
    %SpecRevision{}
    |> SpecRevision.changeset(Map.put(attrs, :spec_id, spec.id))
    |> Repo.insert()
  end

  @spec get_revision!(Ecto.UUID.t()) :: SpecRevision.t()
  def get_revision!(id), do: Repo.get!(SpecRevision, id)

  @doc """
  Parse `revision.body`, compile ExUnit modules under `test/generated/…`, and
  persist `scenario_manifest_sha256` on success.
  """
  @spec compile_revision!(SpecRevision.t()) :: SpecRevision.t()
  def compile_revision!(%SpecRevision{} = rev) do
    case ScenarioParser.parse_document(rev.body) do
      {:error, reason} ->
        raise ArgumentError,
              "compile_revision!: parse failed: #{inspect(reason)}"

      {:ok, ir} ->
        manifest = ScenarioCompiler.manifest_sha256(ir)
        {:ok, _rel} = ScenarioCompiler.compile(rev, ir)

        rev
        |> SpecRevision.changeset(%{scenario_manifest_sha256: manifest})
        |> Repo.update!()

        Repo.get!(SpecRevision, rev.id)
    end
  end

  @doc """
  Inserts an **open** inbox draft (`inbox_state` defaults to `:open`).
  """
  @spec create_draft(map()) :: {:ok, SpecDraft.t()} | {:error, Ecto.Changeset.t()}
  def create_draft(attrs) when is_map(attrs) do
    attrs = Map.put_new(attrs, :inbox_state, :open)

    %SpecDraft{}
    |> SpecDraft.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists drafts in **`inbox_state: :open`**, newest first.
  """
  @spec list_open_drafts() :: [SpecDraft.t()]
  def list_open_drafts do
    from(d in SpecDraft,
      where: d.inbox_state == :open,
      order_by: [desc: d.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Archives an **open** draft (`:archived` + `archived_at`).
  """
  @spec archive_draft(Ecto.UUID.t()) ::
          {:ok, SpecDraft.t()}
          | {:error, :not_found | :invalid_state | Ecto.Changeset.t()}
  def archive_draft(draft_id) when is_binary(draft_id) do
    Repo.transaction(fn ->
      case Repo.get(SpecDraft, draft_id) do
        nil ->
          Repo.rollback(:not_found)

        %SpecDraft{inbox_state: :open} = draft ->
          draft
          |> SpecDraft.changeset(%{
            inbox_state: :archived,
            archived_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
          })
          |> Repo.update()
          |> case do
            {:ok, d} -> d
            {:error, cs} -> Repo.rollback(cs)
          end

        %SpecDraft{} ->
          Repo.rollback(:invalid_state)
      end
    end)
    |> case do
      {:ok, draft} -> {:ok, draft}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Promotes an **open** draft into `specs` + `spec_revisions`, marks the draft
  **`:promoted`**, and appends `:spec_draft_promoted` in the **same** transaction.
  """
  @spec promote_draft(Ecto.UUID.t()) ::
          {:ok, %{draft: SpecDraft.t(), spec: Spec.t(), revision: SpecRevision.t()}}
          | {:error, :not_found | :invalid_state | Ecto.Changeset.t() | term()}
  def promote_draft(draft_id) when is_binary(draft_id) do
    correlation_id = Ecto.UUID.generate()

    Repo.transaction(fn ->
      draft =
        from(d in SpecDraft,
          where: d.id == ^draft_id,
          lock: "FOR UPDATE"
        )
        |> Repo.one()

      case draft do
        nil ->
          Repo.rollback(:not_found)

        %SpecDraft{inbox_state: s} when s != :open ->
          Repo.rollback(:invalid_state)

        %SpecDraft{} = draft ->
          with {:ok, spec} <- insert_spec_from_draft(draft),
               {:ok, rev} <- insert_revision_from_draft(spec, draft),
               {:ok, promoted_draft} <- mark_draft_promoted(draft, spec.id),
               {:ok, _audit} <-
                 Audit.append(%{
                   event_kind: :spec_draft_promoted,
                   correlation_id: correlation_id,
                   payload: %{
                     "draft_id" => uuid_string!(draft.id),
                     "spec_id" => uuid_string!(spec.id),
                     "spec_revision_id" => uuid_string!(rev.id)
                   }
                 }) do
            %{draft: promoted_draft, spec: spec, revision: rev}
          else
            {:error, %Ecto.Changeset{} = cs} -> Repo.rollback(cs)
            {:error, other} -> Repo.rollback(other)
          end
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_spec_from_draft(%SpecDraft{title: title}) do
    %Spec{}
    |> Spec.changeset(%{title: title})
    |> Repo.insert()
  end

  defp insert_revision_from_draft(%Spec{id: spec_id}, %SpecDraft{body: body}) do
    %SpecRevision{}
    |> SpecRevision.changeset(%{spec_id: spec_id, body: body})
    |> Repo.insert()
  end

  defp mark_draft_promoted(%SpecDraft{} = draft, spec_id) do
    draft
    |> SpecDraft.changeset(%{inbox_state: :promoted, promoted_spec_id: spec_id})
    |> Repo.update()
  end

  @doc """
  Import a GitHub issue reference **`owner/repo#N`** into the inbox as a draft.
  """
  @spec import_github_issue_from_slug(String.t(), keyword()) ::
          {:ok, SpecDraft.t()} | {:error, term()}
  def import_github_issue_from_slug(slug, opts \\ []),
    do: GitHubIssueImporter.import_from_slug(slug, opts)

  @doc """
  Import a canonical GitHub issue **`https://github.com/.../issues/N`** URL.
  """
  @spec import_github_issue_from_url(String.t(), keyword()) ::
          {:ok, SpecDraft.t()} | {:error, term()}
  def import_github_issue_from_url(url, opts \\ []),
    do: GitHubIssueImporter.import_from_url(url, opts)

  @doc """
  Re-fetch a GitHub-backed draft using the stored **etag** (`If-None-Match`).
  """
  @spec refresh_github_issue_draft(SpecDraft.t(), keyword()) ::
          {:ok, SpecDraft.t()} | {:error, term()}
  def refresh_github_issue_draft(%SpecDraft{} = draft, opts \\ []),
    do: GitHubIssueImporter.refresh(draft, opts)

  @doc """
  Updates an **open** draft's title/body (operator edit from inbox).
  """
  @spec update_open_draft(Ecto.UUID.t(), map()) ::
          {:ok, SpecDraft.t()} | {:error, :not_found | :invalid_state | Ecto.Changeset.t()}
  def update_open_draft(draft_id, attrs) when is_binary(draft_id) and is_map(attrs) do
    case Repo.get(SpecDraft, draft_id) do
      nil ->
        {:error, :not_found}

      %SpecDraft{inbox_state: :open} = draft ->
        draft
        |> SpecDraft.changeset(attrs)
        |> Repo.update()

      %SpecDraft{} ->
        {:error, :invalid_state}
    end
  end

  defp uuid_string!(id) when is_binary(id) do
    cond do
      byte_size(id) == 16 ->
        case Ecto.UUID.load(id) do
          {:ok, s} -> s
          :error -> raise ArgumentError, "expected uuid binary, got: #{inspect(id)}"
        end

      true ->
        case Ecto.UUID.cast(id) do
          {:ok, s} -> s
          :error -> raise ArgumentError, "expected uuid string, got: #{inspect(id)}"
        end
    end
  end
end
