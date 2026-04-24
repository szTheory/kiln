defmodule Kiln.Attach.SafetyGate do
  @moduledoc """
  Conservative preflight for attached repositories before later git mutation.
  """

  alias Kiln.Attach.Source
  alias Kiln.Attach.WorkspaceManager
  alias Kiln.GitHub.Cli
  alias Kiln.OperatorSetup

  @type ready :: %{
          status: :ready,
          source_kind: :local_path | :github_url,
          repo_slug: String.t(),
          workspace_path: String.t(),
          remote_url: String.t(),
          base_branch: String.t()
        }

  @type blocked_code ::
          :dirty_worktree | :detached_head | :github_auth_missing | :github_remote_missing

  @type blocked_scope :: :source_repo | :attached_workspace | :github_cli

  @type blocked :: %{
          status: :blocked,
          code: blocked_code(),
          scope: blocked_scope(),
          title: String.t(),
          message: String.t(),
          why: String.t(),
          probe: String.t(),
          next_action: String.t(),
          workspace_path: String.t(),
          repo_slug: String.t()
        }

  @type result :: {:ok, ready()} | {:blocked, blocked()}
  @type git_runner ::
          module()
          | ([String.t()], keyword() -> {:ok, String.t()} | {:error, map()})
  @type gh_runner ::
          module()
          | ([String.t()], keyword() -> {:ok, String.t()} | {:error, map()})

  @spec evaluate(Source.t(), WorkspaceManager.result(), keyword()) :: result()
  def evaluate(%Source{} = source, %WorkspaceManager{} = hydrated, opts \\ []) do
    with :ok <- ensure_clean_repo(source, hydrated, opts),
         :ok <- ensure_attached_workspace_ready(hydrated, opts),
         {:ok, remote} <- ensure_github_remote(source, hydrated, opts),
         :ok <- ensure_github_auth(hydrated, opts) do
      {:ok,
       %{
         status: :ready,
         source_kind: source.kind,
         repo_slug: remote.slug,
         workspace_path: hydrated.workspace_path,
         remote_url: remote.clone_url,
         base_branch: hydrated.base_branch || remote.default_branch || "main"
       }}
    end
  end

  defp ensure_clean_repo(%Source{kind: :local_path, canonical_root: path} = source, hydrated, opts) do
    with :ok <- ensure_clean_path(path, :source_repo, source, hydrated, opts),
         :ok <- ensure_branch_path(path, :source_repo, source, hydrated, opts) do
      :ok
    end
  end

  defp ensure_clean_repo(%Source{}, _hydrated, _opts), do: :ok

  defp ensure_attached_workspace_ready(hydrated, opts) do
    with :ok <-
           ensure_clean_path(
             hydrated.workspace_path,
             :attached_workspace,
             nil,
             hydrated,
             opts
           ),
         :ok <-
           ensure_branch_path(
             hydrated.workspace_path,
             :attached_workspace,
             nil,
             hydrated,
             opts
           ) do
      :ok
    end
  end

  defp ensure_clean_path(path, scope, source, hydrated, opts) do
    case git_call(opts, ["status", "--porcelain"], cd: path) do
      {:ok, ""} ->
        :ok

      {:ok, _dirty} ->
        {:blocked, dirty_worktree(scope, source, hydrated)}

      {:error, _reason} ->
        {:blocked, dirty_worktree(scope, source, hydrated)}
    end
  end

  defp ensure_branch_path(path, scope, source, hydrated, opts) do
    case git_call(opts, ["symbolic-ref", "--short", "HEAD"], cd: path) do
      {:ok, branch} when branch != "" ->
        :ok

      {:ok, _} ->
        {:blocked, detached_head(scope, source, hydrated)}

      {:error, _reason} ->
        {:blocked, detached_head(scope, source, hydrated)}
    end
  end

  defp ensure_github_remote(%Source{kind: :github_url} = source, hydrated, _opts) do
    {:ok,
     %{
       slug: source.repo_identity.slug,
       clone_url: source.remote_metadata.clone_url,
       default_branch: hydrated.base_branch || source.remote_metadata.default_branch
     }}
  end

  defp ensure_github_remote(%Source{canonical_root: canonical_root} = source, hydrated, opts) do
    case git_call(opts, ["remote", "get-url", "origin"], cd: canonical_root) do
      {:ok, origin} ->
        origin
        |> String.trim()
        |> parse_github_remote()
        |> case do
          {:ok, remote} -> {:ok, remote}
          :error -> {:blocked, github_remote_missing(source, hydrated)}
        end

      {:error, _reason} ->
        {:blocked, github_remote_missing(source, hydrated)}
    end
  end

  defp ensure_github_auth(hydrated, opts) do
    case gh_call(opts, ["auth", "status"], cd: hydrated.workspace_path) do
      {:ok, _} ->
        :ok

      {:error, %{exit_status: status, stderr: stderr}} ->
        case Cli.classify_gh_error(stderr || "", status) do
          :gh_auth_expired -> {:blocked, github_auth_missing(hydrated)}
          :gh_permissions_insufficient -> {:blocked, github_auth_missing(hydrated)}
          :gh_cli_failed -> {:blocked, github_auth_missing(hydrated)}
        end

      {:error, _reason} ->
        {:blocked, github_auth_missing(hydrated)}
    end
  end

  defp dirty_worktree(scope, source, hydrated) do
    label =
      case scope do
        :source_repo -> "source repo"
        :attached_workspace -> "managed attach workspace"
        :github_cli -> "GitHub CLI"
      end

    %{
      status: :blocked,
      code: :dirty_worktree,
      scope: scope,
      title: "Uncommitted changes found in the #{label}",
      message: "Kiln refuses to mark this attached repo ready while the #{label} is dirty.",
      why: "Later branch and PR work must start from a clean, inspectable git state.",
      probe: "git status --porcelain",
      next_action:
        "Commit, stash, or discard the pending changes, then re-run attach readiness.",
      workspace_path: hydrated.workspace_path,
      repo_slug: repo_slug(source)
    }
  end

  defp detached_head(scope, source, hydrated) do
    label =
      case scope do
        :source_repo -> "source repo"
        :attached_workspace -> "managed attach workspace"
        :github_cli -> "GitHub CLI"
      end

    %{
      status: :blocked,
      code: :detached_head,
      scope: scope,
      title: "Detached HEAD found in the #{label}",
      message: "Kiln refuses to continue while the #{label} is not on a branch.",
      why: "The next phase needs a stable base branch before it can create a bounded work branch.",
      probe: "git symbolic-ref --short HEAD",
      next_action: "Check out the branch that should receive the future draft PR, then re-run attach readiness.",
      workspace_path: hydrated.workspace_path,
      repo_slug: repo_slug(source)
    }
  end

  defp github_auth_missing(hydrated) do
    github_item =
      OperatorSetup.checklist()
      |> Enum.find(&(&1.id == :github))

    %{
      status: :blocked,
      code: :github_auth_missing,
      scope: :github_cli,
      title: "GitHub CLI authentication is not ready",
      message: "Kiln refuses to advertise this repo as ready until GitHub CLI access is confirmed.",
      why: "Phase 31 will need authenticated GitHub access to push a branch and open a draft PR safely.",
      probe: github_item.probe,
      next_action: github_item.next_action,
      workspace_path: hydrated.workspace_path,
      repo_slug: "unknown"
    }
  end

  defp github_remote_missing(source, hydrated) do
    %{
      status: :blocked,
      code: :github_remote_missing,
      scope: :source_repo,
      title: "GitHub remote topology is missing",
      message: "Kiln found a repo, but it does not have the GitHub remote information needed for later push and draft PR work.",
      why: "The next phase must know which GitHub repo and base branch it is targeting before any git mutation starts.",
      probe: "git remote get-url origin",
      next_action: "Add a GitHub origin remote for this repo, then re-run attach readiness.",
      workspace_path: hydrated.workspace_path,
      repo_slug: repo_slug(source)
    }
  end

  defp repo_slug(%Source{repo_identity: %{slug: slug}}), do: slug
  defp repo_slug(_source), do: "unknown"

  defp git_runner(opts), do: Keyword.get(opts, :git_runner, Kiln.Git.default_runner())
  defp gh_runner(opts), do: Keyword.get(opts, :gh_runner, Cli.default_runner())

  defp git_call(opts, argv, cmd_opts) do
    runner = git_runner(opts)

    case runner do
      fun when is_function(fun, 2) -> fun.(argv, cmd_opts)
      mod when is_atom(mod) -> mod.run_git(argv, cmd_opts)
    end
  end

  defp gh_call(opts, argv, cmd_opts) do
    runner = gh_runner(opts)

    case runner do
      fun when is_function(fun, 2) -> fun.(argv, cmd_opts)
      mod when is_atom(mod) -> mod.run_gh(argv, cmd_opts)
    end
  end

  defp parse_github_remote(remote) when is_binary(remote) do
    cond do
      String.starts_with?(remote, "git@github.com:") ->
        parse_owner_repo(String.replace_prefix(remote, "git@github.com:", ""))

      String.starts_with?(remote, "https://github.com/") ->
        remote
        |> String.replace_prefix("https://github.com/", "")
        |> parse_owner_repo()

      String.starts_with?(remote, "ssh://git@github.com/") ->
        remote
        |> String.replace_prefix("ssh://git@github.com/", "")
        |> parse_owner_repo()

      true ->
        :error
    end
  end

  defp parse_owner_repo(path) do
    case String.trim(path) |> String.trim("/") |> String.replace_suffix(".git", "") |> String.split("/") do
      [owner, repo] when owner != "" and repo != "" ->
        {:ok,
         %{
           slug: "#{owner}/#{repo}",
           clone_url: "https://github.com/#{owner}/#{repo}.git",
           default_branch: nil
         }}

      _ ->
        :error
    end
  end
end
