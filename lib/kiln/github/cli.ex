defmodule Kiln.GitHub.Cli do
  @moduledoc """
  `gh` CLI boundary (GIT-02) with injectable runner (mirrors `Kiln.Git`).

  * `create_pr/2` — `gh pr create` with `--json` machine output.
  * `list_check_runs/3` — `gh api` transport for check runs (GIT-03).
  * `classify_gh_error/2` — maps stderr + exit to `:gh_auth_expired`,
    `:gh_permissions_insufficient`, or `:gh_cli_failed`.

  Never pass tokens on argv — rely on `gh auth` (SEC-01).
  """

  @type runner ::
          module()
          | ([String.t()], keyword() -> {:ok, String.t()} | {:error, map()})

  defmodule SystemRunner do
    @moduledoc false

    @spec run_gh([String.t()], keyword()) :: {:ok, String.t()} | {:error, map()}
    def run_gh(argv, opts \\ []) when is_list(argv) do
      {cd, cmd_opts} = Keyword.pop(opts, :cd)
      cmd_opts = Keyword.put_new(cmd_opts, :stderr_to_stdout, true)

      cmd_opts =
        if cd do
          Keyword.put(cmd_opts, :cd, cd)
        else
          cmd_opts
        end

      case System.cmd("gh", argv, cmd_opts) do
        {out, 0} -> {:ok, out}
        {out, code} -> {:error, %{exit_status: code, stdout: out, stderr: out}}
      end
    end
  end

  @doc false
  def default_runner, do: SystemRunner

  @doc """
  Creates a PR from a frozen attribute map (string keys only):

    * `"title"`, `"body"`, `"base"`, `"head"`, `"draft"` (boolean),
      `"reviewers"` (list of logins, may be empty)

  Returns `{:ok, map()}` with string keys from `gh --json` on success.
  """
  @spec create_pr(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_pr(attrs, opts \\ []) when is_map(attrs) do
    runner = normalize_runner(Keyword.get(opts, :runner, default_runner()))
    cd = Keyword.get(opts, :cd)
    runner_opts = if(cd, do: [cd: cd], else: [])

    title = Map.fetch!(attrs, "title")
    body = Map.fetch!(attrs, "body")
    base = Map.fetch!(attrs, "base")
    head = Map.fetch!(attrs, "head")
    draft? = Map.fetch!(attrs, "draft")
    reviewers = Map.fetch!(attrs, "reviewers")

    {body_args, cleanup} =
      if String.length(body) < 12_000 do
        {["--body", body], :none}
      else
        path = body_temp_file!(body)
        {["--body-file", path], {:file, path}}
      end

    argv =
      [
        "pr",
        "create",
        "--title",
        title,
        "--base",
        base,
        "--head",
        head
      ] ++ draft_flag(draft?) ++ body_args

    argv =
      Enum.reduce(reviewers, argv, fn login, acc ->
        acc ++ ["--reviewer", login]
      end)

    argv = argv ++ ["--json", "number,url,headRefName,baseRefName,isDraft"]

    try do
      case gh_call(runner, argv, runner_opts) do
        {:ok, out} ->
          case Jason.decode(out) do
            {:ok, %{"number" => _} = decoded} -> {:ok, decoded}
            {:ok, other} -> {:error, {:gh_json_unexpected, other}}
            {:error, _} -> {:error, :gh_cli_failed}
          end

        {:error, %{exit_status: code, stderr: err} = e} ->
          case classify_gh_error(err, code) do
            :gh_cli_failed -> {:error, e}
            other -> {:error, other}
          end
      end
    after
      case cleanup do
        {:file, p} -> _ = File.rm(p)
        :none -> :ok
      end
    end
  end

  defp draft_flag(true), do: ["--draft"]
  defp draft_flag(false), do: ["--no-draft"]

  defp body_temp_file!(body) do
    path =
      Path.join(System.tmp_dir!(), "kiln_gh_pr_body_#{:erlang.unique_integer([:positive])}.md")

    :ok = File.write!(path, body)
    _ = File.chmod!(path, 0o600)
    path
  end

  @doc """
  Lists check runs for a PR via `gh api`.

  `repo` must be `owner/name`.
  """
  @spec list_check_runs(String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def list_check_runs(repo, pr_number, opts \\ [])
      when is_binary(repo) and is_integer(pr_number) do
    runner = normalize_runner(Keyword.get(opts, :runner, default_runner()))
    cd = Keyword.get(opts, :cd)
    runner_opts = if(cd, do: [cd: cd], else: [])

    case String.split(repo, "/", parts: 2) do
      [owner, name] ->
        path = "repos/#{owner}/#{name}/pulls/#{pr_number}/check-runs?per_page=100"

        argv = ["api", "-H", "Accept: application/vnd.github+json", path]

        case gh_call(runner, argv, runner_opts) do
          {:ok, out} ->
            case Jason.decode(out) do
              {:ok, %{"check_runs" => _} = decoded} -> {:ok, decoded}
              {:ok, other} -> {:error, {:gh_check_runs_shape, other}}
              {:error, _} -> {:error, :gh_cli_failed}
            end

          {:error, %{exit_status: code, stderr: err} = e} ->
            case classify_gh_error(err, code) do
              :gh_cli_failed -> {:error, e}
              other -> {:error, other}
            end
        end

      _ ->
        {:error, :invalid_repo}
    end
  end

  @doc """
  Classifies `gh` stderr + exit code into typed atoms.
  """
  @spec classify_gh_error(String.t(), integer()) ::
          :gh_auth_expired | :gh_permissions_insufficient | :gh_cli_failed
  def classify_gh_error(stderr, exit_status)
      when is_binary(stderr) and is_integer(exit_status) do
    s = String.downcase(stderr)

    cond do
      exit_status == 0 ->
        :gh_cli_failed

      String.contains?(s, "authentication") and
          (String.contains?(s, "expired") or String.contains?(s, "log in")) ->
        :gh_auth_expired

      String.contains?(s, "http 401") or String.contains?(s, "401") ->
        :gh_auth_expired

      String.contains?(s, "403") or String.contains?(s, "permission") ->
        :gh_permissions_insufficient

      true ->
        :gh_cli_failed
    end
  end

  defp gh_call(runner, argv, opts) when is_function(runner, 2), do: runner.(argv, opts)

  defp gh_call(runner, argv, opts) when is_atom(runner), do: runner.run_gh(argv, opts)

  defp normalize_runner(nil), do: default_runner()
  defp normalize_runner(m) when is_atom(m), do: m
  defp normalize_runner(f) when is_function(f, 2), do: f
end
