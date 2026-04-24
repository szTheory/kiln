defmodule Kiln.Attach.Continuity do
  @moduledoc """
  Repo-centric continuity queries for repeat attached-repo work.
  """

  import Ecto.Query

  alias Kiln.Attach.AttachedRepo
  alias Kiln.Repo
  alias Kiln.Runs
  alias Kiln.Runs.Run
  alias Kiln.Specs
  alias Kiln.Specs.{Spec, SpecDraft, SpecRevision}

  @type recent_repo :: %{
          id: Ecto.UUID.t(),
          repo_slug: String.t(),
          workspace_path: String.t(),
          base_branch: String.t() | nil,
          last_selected_at: DateTime.t() | nil,
          last_run_started_at: DateTime.t() | nil,
          last_activity_at: DateTime.t()
        }

  @type request_target :: %{
          kind: :draft | :promoted_request | :run,
          source_id: Ecto.UUID.t(),
          draft_id: Ecto.UUID.t() | nil,
          run_id: Ecto.UUID.t() | nil,
          spec_id: Ecto.UUID.t() | nil,
          spec_revision_id: Ecto.UUID.t() | nil,
          title: String.t(),
          request_kind: SpecDraft.request_kind() | nil,
          change_summary: String.t() | nil,
          acceptance_criteria: [String.t()],
          out_of_scope: [String.t()],
          inserted_at: DateTime.t() | nil
        }

  @type run_context :: %{
          id: Ecto.UUID.t(),
          state: atom(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          branch: String.t() | nil,
          base_branch: String.t() | nil
        }

  @type carry_forward :: %{
          source: :draft | :promoted_request | :run | :blank,
          source_id: Ecto.UUID.t() | nil,
          title: String.t() | nil,
          request_kind: SpecDraft.request_kind() | nil,
          change_summary: String.t() | nil,
          acceptance_criteria: [String.t()],
          out_of_scope: [String.t()]
        }

  @type detail :: %{
          attached_repo: AttachedRepo.t(),
          last_run: run_context() | nil,
          last_request: request_target() | nil,
          selected_target: request_target() | nil,
          carry_forward: carry_forward()
        }

  @spec list_recent_attached_repos(keyword()) :: [recent_repo()]
  def list_recent_attached_repos(opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    AttachedRepo
    |> select([repo], %{
      id: repo.id,
      repo_slug: repo.repo_slug,
      workspace_path: repo.workspace_path,
      base_branch: repo.base_branch,
      last_selected_at: repo.last_selected_at,
      last_run_started_at: repo.last_run_started_at,
      inserted_at: repo.inserted_at
    })
    |> Repo.all()
    |> Enum.map(fn repo ->
      Map.put(repo, :last_activity_at, last_activity_at(repo))
    end)
    |> Enum.sort(fn left, right ->
      case DateTime.compare(left.last_activity_at, right.last_activity_at) do
        :gt -> true
        :lt -> false
        :eq -> DateTime.compare(left.inserted_at, right.inserted_at) != :lt
      end
    end)
    |> Enum.take(limit)
  end

  @spec get_repo_continuity(Ecto.UUID.t(), keyword()) :: {:ok, detail()} | {:error, :not_found}
  def get_repo_continuity(attached_repo_id, opts \\ []) when is_binary(attached_repo_id) do
    case Repo.get(AttachedRepo, attached_repo_id) do
      nil ->
        {:error, :not_found}

      %AttachedRepo{} = attached_repo ->
        last_run = latest_run(attached_repo_id)
        last_request = latest_request_target(attached_repo_id)
        selected_target = selected_target(attached_repo_id, opts, last_request)

        {:ok,
         %{
           attached_repo: attached_repo,
           last_run: last_run && run_context(last_run),
           last_request: last_request,
           selected_target: selected_target,
           carry_forward: carry_forward(selected_target)
         }}
    end
  end

  @spec mark_repo_selected(Ecto.UUID.t(), keyword()) ::
          {:ok, AttachedRepo.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mark_repo_selected(attached_repo_id, opts \\ []) when is_binary(attached_repo_id) do
    update_usage_timestamp(attached_repo_id, :last_selected_at, opts)
  end

  @spec mark_run_started(Ecto.UUID.t(), keyword()) ::
          {:ok, AttachedRepo.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mark_run_started(attached_repo_id, opts \\ []) when is_binary(attached_repo_id) do
    update_usage_timestamp(attached_repo_id, :last_run_started_at, opts)
  end

  defp update_usage_timestamp(attached_repo_id, field, opts) do
    timestamp = Keyword.get(opts, :at, DateTime.utc_now() |> DateTime.truncate(:microsecond))

    case Repo.get(AttachedRepo, attached_repo_id) do
      nil ->
        {:error, :not_found}

      %AttachedRepo{} = attached_repo ->
        attached_repo
        |> AttachedRepo.changeset(%{field => timestamp})
        |> Repo.update()
    end
  end

  defp selected_target(attached_repo_id, opts, fallback) do
    cond do
      draft_id = Keyword.get(opts, :draft_id) ->
        explicit_draft(attached_repo_id, draft_id) || fallback

      run_id = Keyword.get(opts, :run_id) ->
        explicit_run(attached_repo_id, run_id) || fallback

      true ->
        fallback
    end
  end

  defp latest_request_target(attached_repo_id) do
    latest_open_draft(attached_repo_id) ||
      latest_promoted_request(attached_repo_id) ||
      latest_run_request(attached_repo_id)
  end

  defp explicit_draft(attached_repo_id, draft_id) do
    attached_repo_id
    |> Specs.get_open_attached_draft(draft_id)
    |> case do
      %SpecDraft{} = draft -> draft_target(draft)
      nil -> nil
    end
  end

  defp explicit_run(attached_repo_id, run_id) do
    attached_repo_id
    |> Runs.get_for_attached_repo(run_id)
    |> run_target()
  end

  defp latest_open_draft(attached_repo_id) do
    attached_repo_id
    |> Specs.latest_open_attached_draft()
    |> case do
      %SpecDraft{} = draft -> draft_target(draft)
      nil -> nil
    end
  end

  defp latest_promoted_request(attached_repo_id) do
    case Specs.latest_promoted_attached_request(attached_repo_id) do
      %{revision: %SpecRevision{} = revision, spec: %Spec{} = spec} ->
        revision_target(revision, spec)

      nil ->
        nil
    end
  end

  defp latest_run_request(attached_repo_id) do
    attached_repo_id
    |> latest_run()
    |> run_target()
  end

  defp latest_run(attached_repo_id) do
    attached_repo_id
    |> Runs.list_recent_for_attached_repo(limit: 1)
    |> List.first()
  end

  defp draft_target(%SpecDraft{} = draft) do
    %{
      kind: :draft,
      source_id: draft.id,
      draft_id: draft.id,
      run_id: nil,
      spec_id: draft.promoted_spec_id,
      spec_revision_id: nil,
      title: draft.title,
      request_kind: draft.request_kind,
      change_summary: draft.change_summary,
      acceptance_criteria: draft.acceptance_criteria || [],
      out_of_scope: draft.out_of_scope || [],
      inserted_at: draft.inserted_at
    }
  end

  defp revision_target(%SpecRevision{} = revision, %Spec{} = spec) do
    %{
      kind: :promoted_request,
      source_id: revision.id,
      draft_id: nil,
      run_id: nil,
      spec_id: revision.spec_id,
      spec_revision_id: revision.id,
      title: spec.title,
      request_kind: revision.request_kind,
      change_summary: revision.change_summary,
      acceptance_criteria: revision.acceptance_criteria || [],
      out_of_scope: revision.out_of_scope || [],
      inserted_at: revision.inserted_at
    }
  end

  defp run_target(nil), do: nil

  defp run_target(%Run{} = run) do
    case {run.spec_revision, run.spec} do
      {%SpecRevision{} = revision, %Spec{} = spec} ->
        %{
          kind: :run,
          source_id: run.id,
          draft_id: nil,
          run_id: run.id,
          spec_id: revision.spec_id,
          spec_revision_id: revision.id,
          title: spec.title,
          request_kind: revision.request_kind,
          change_summary: revision.change_summary,
          acceptance_criteria: revision.acceptance_criteria || [],
          out_of_scope: revision.out_of_scope || [],
          inserted_at: run.inserted_at
        }

      _ ->
        nil
    end
  end

  defp run_context(%Run{} = run) do
    %{
      id: run.id,
      state: run.state,
      inserted_at: run.inserted_at,
      updated_at: run.updated_at,
      branch: get_in(run.github_delivery_snapshot, ["attach", "branch"]),
      base_branch: get_in(run.github_delivery_snapshot, ["attach", "base_branch"])
    }
  end

  defp carry_forward(nil) do
    %{
      source: :blank,
      source_id: nil,
      title: nil,
      request_kind: nil,
      change_summary: nil,
      acceptance_criteria: [],
      out_of_scope: []
    }
  end

  defp carry_forward(target) do
    %{
      source: target.kind,
      source_id: target.source_id,
      title: target.title,
      request_kind: target.request_kind,
      change_summary: target.change_summary,
      acceptance_criteria: target.acceptance_criteria,
      out_of_scope: target.out_of_scope
    }
  end

  defp last_activity_at(repo) do
    [repo.last_selected_at, repo.last_run_started_at, repo.inserted_at]
    |> Enum.reject(&is_nil/1)
    |> Enum.max(DateTime)
  end
end
