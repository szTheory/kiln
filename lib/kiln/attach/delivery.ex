defmodule Kiln.Attach.Delivery do
  @moduledoc """
  Thin orchestration boundary for attached-repo branch, push, and draft PR delivery.
  """

  alias Kiln.Attach
  alias Kiln.Attach.AttachedRepo
  alias Kiln.Git
  alias Kiln.GitHub.{OpenPRWorker, PushWorker}
  alias Kiln.Runs
  alias Kiln.Runs.Run

  @type prepared :: %{
          snapshot: map(),
          push_args: map(),
          pr_args: map()
        }

  @spec prepare(Run.t() | Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), keyword()) ::
          {:ok, prepared()} | {:error, term()}
  def prepare(run_or_id, attached_repo_id, stage_id, opts \\ [])
      when is_binary(attached_repo_id) and is_binary(stage_id) do
    runner = Keyword.get(opts, :git_runner, Git.default_runner())

    with {:ok, %Run{} = run} <- fetch_run(run_or_id),
         {:ok, %AttachedRepo{} = attached_repo} <- Attach.get_attached_repo(attached_repo_id),
         {:ok, frozen} <- freeze_snapshot(run, attached_repo, runner),
         :ok <-
           Git.ensure_local_branch(frozen["workspace_path"], frozen["branch"], runner: runner) do
      {:ok,
       %{
         snapshot: frozen_snapshot_fragment(frozen),
         push_args: push_args(run.id, stage_id, frozen),
         pr_args: pr_args(run.id, stage_id, frozen)
       }}
    end
  end

  @spec enqueue_delivery(Run.t() | Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), keyword()) ::
          {:ok, prepared()} | {:error, term()}
  def enqueue_delivery(run_or_id, attached_repo_id, stage_id, opts \\ [])
      when is_binary(attached_repo_id) and is_binary(stage_id) do
    with {:ok, prepared} <- prepare(run_or_id, attached_repo_id, stage_id, opts),
         {:ok, _push_job} <- enqueue_push(prepared.push_args, opts),
         {:ok, _pr_job} <- enqueue_pr(prepared.pr_args, opts) do
      {:ok, prepared}
    end
  end

  defp fetch_run(%Run{} = run), do: {:ok, run}

  defp fetch_run(run_id) when is_binary(run_id) do
    case Runs.get(run_id) do
      %Run{} = run -> {:ok, run}
      nil -> {:error, :run_not_found}
    end
  end

  defp freeze_snapshot(run, attached_repo, runner) do
    existing = run.github_delivery_snapshot || %{}

    case existing do
      %{"attach" => %{} = attach, "pr" => %{} = pr} ->
        {:ok,
         %{
           "attached_repo_id" => Map.get(attach, "attached_repo_id", attached_repo.id),
           "repo_slug" => Map.get(attach, "repo_slug", attached_repo.repo_slug),
           "workspace_path" => Map.get(attach, "workspace_path", attached_repo.workspace_path),
           "remote_url" => Map.get(attach, "remote_url", attached_repo.remote_url),
           "base_branch" => Map.get(attach, "base_branch", attached_repo.base_branch || "main"),
           "branch" => Map.fetch!(attach, "branch"),
           "expected_remote_sha" =>
             Map.get(attach, "expected_remote_sha", Git.missing_remote_sha()),
           "local_commit_sha" => Map.fetch!(attach, "local_commit_sha"),
           "title" => Map.fetch!(pr, "title"),
           "body" => Map.fetch!(pr, "body")
         }}

      _ ->
        create_snapshot(run, attached_repo, runner)
    end
  end

  defp create_snapshot(run, attached_repo, runner) do
    base_branch = attached_repo.base_branch || attached_repo.default_branch || "main"
    branch = delivery_branch_name(attached_repo, run.id)

    with :ok <- Git.validate_branch_name(branch, runner: runner),
         {:ok, local_commit_sha} <- Git.head_sha(attached_repo.workspace_path, runner: runner),
         frozen <- %{
           "attached_repo_id" => attached_repo.id,
           "repo_slug" => attached_repo.repo_slug,
           "workspace_path" => attached_repo.workspace_path,
           "remote_url" => attached_repo.remote_url,
           "base_branch" => base_branch,
           "branch" => branch,
           "expected_remote_sha" => Git.missing_remote_sha(),
           "local_commit_sha" => local_commit_sha,
           "title" => draft_pr_title(attached_repo, run.id),
           "body" => draft_pr_body(attached_repo, run.id, branch, base_branch)
         },
         {:ok, _run} <- Runs.promote_github_snapshot(run.id, frozen_snapshot_fragment(frozen)) do
      {:ok, frozen}
    end
  end

  defp frozen_snapshot_fragment(frozen) do
    %{
      "attach" => %{
        "attached_repo_id" => frozen["attached_repo_id"],
        "repo_slug" => frozen["repo_slug"],
        "workspace_path" => frozen["workspace_path"],
        "remote_url" => frozen["remote_url"],
        "base_branch" => frozen["base_branch"],
        "branch" => frozen["branch"],
        "expected_remote_sha" => frozen["expected_remote_sha"],
        "local_commit_sha" => frozen["local_commit_sha"],
        "frozen" => true
      },
      "pr" => %{
        "title" => frozen["title"],
        "body" => frozen["body"],
        "base" => frozen["base_branch"],
        "head" => frozen["branch"],
        "draft" => true,
        "reviewers" => [],
        "frozen" => true
      }
    }
  end

  defp push_args(run_id, stage_id, frozen) do
    %{
      "idempotency_key" => "run:#{run_id}:stage:#{stage_id}:git_push",
      "run_id" => run_id,
      "stage_id" => stage_id,
      "workspace_dir" => frozen["workspace_path"],
      "remote" => "origin",
      "refspec" => "refs/heads/#{frozen["branch"]}",
      "expected_remote_sha" => frozen["expected_remote_sha"],
      "local_commit_sha" => frozen["local_commit_sha"]
    }
  end

  defp pr_args(run_id, stage_id, frozen) do
    %{
      "idempotency_key" => "run:#{run_id}:stage:#{stage_id}:gh_pr_create",
      "run_id" => run_id,
      "stage_id" => stage_id,
      "title" => frozen["title"],
      "body" => frozen["body"],
      "base" => frozen["base_branch"],
      "head" => frozen["branch"],
      "draft" => true,
      "reviewers" => []
    }
  end

  defp enqueue_push(args, opts) do
    oban = Keyword.get(opts, :oban, Oban)
    oban.insert(PushWorker.new(args))
  end

  defp enqueue_pr(args, opts) do
    oban = Keyword.get(opts, :oban, Oban)
    oban.insert(OpenPRWorker.new(args))
  end

  defp delivery_branch_name(attached_repo, run_id) do
    slug =
      attached_repo.repo_slug
      |> String.replace("/", "-")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9-]+/, "-")
      |> String.trim("-")
      |> case do
        "" -> "repo"
        value -> String.slice(value, 0, 40)
      end

    "kiln/attach/#{slug}-r#{short_run_id(run_id)}"
  end

  defp draft_pr_title(attached_repo, run_id) do
    "draft: #{attached_repo.repo_name}: attached repo update (#{short_run_id(run_id)})"
  end

  defp draft_pr_body(attached_repo, run_id, branch, base_branch) do
    """
    Kiln opened this as a draft attached-repo PR.

    ## Why
    - Keep attached-repo delivery bounded to one conservative draft PR.

    ## What changed
    - Repo: `#{attached_repo.repo_slug}`
    - Branch: `#{branch}`
    - Base branch: `#{base_branch}`

    ## Verification
    - Attach workspace was marked ready before delivery.
    - This PR stays draft-first for operator inspection.

    ## Kiln context
    - Run: `#{run_id}`
    - Attached repo: `#{attached_repo.id}`

    kiln-run: #{run_id}
    """
  end

  defp short_run_id(run_id), do: run_id |> String.replace("-", "") |> binary_part(0, 8)
end
