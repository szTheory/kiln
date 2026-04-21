defmodule Kiln.Git do
  @moduledoc """
  Thin boundary around local `git` CLI calls (GIT-01).

  * `ls_remote_tip/3` — reads the remote ref tip for CAS preconditions (D-G16).
  * `push_intent_payload/2` — builds the **exact** `intent_payload` map for
    `external_operations` rows (`expected_remote_sha`, `local_commit_sha`,
    `refspec` as strings).
  * `classify_push_failure/2` — maps `(exit_status, stderr)` to typed atoms
    for `fail_op` / `Transitions` (D-G17).

  Unknown stderr patterns map to `:git_push_rejected` (fail-fast default).

  ## Logging

  Never log raw `git` stderr at `:info` — it may embed remote URLs with
  credentials (SEC-01). This module avoids info-level stderr logging; if
  you add logs, pipe through   `Kiln.Logging.SecretRedactor` or truncate.

  ## cmd_runner injection

  Pass a `Kiln.Git.Cmd` implementation module (default `Kiln.Git.SystemCmdRunner`)
  or an arity-2 **cmd_runner** callback as `runner` to `ls_remote_tip/3` for
  hermetic tests.
  """

  alias Kiln.Git.Cmd

  @type runner ::
          module()
          | ([String.t()], keyword() -> {:ok, String.t()} | {:error, Cmd.error_map()})

  @doc "Returns the default runner module (`Kiln.Git.SystemCmdRunner`)."
  @spec default_runner() :: module()
  def default_runner, do: Kiln.Git.SystemCmdRunner

  @doc """
  Parses the first full SHA from `git ls-remote <remote> <ref>` output.

  `ref` is passed verbatim to `git ls-remote` (e.g. `refs/heads/main`).
  """
  @spec ls_remote_tip(String.t(), String.t(), runner() | nil) ::
          {:ok, String.t()} | {:error, term()}
  def ls_remote_tip(remote, ref, runner \\ nil) when is_binary(remote) and is_binary(ref) do
    runner = normalize_runner(runner)

    case git_call(runner, ["ls-remote", remote, ref], []) do
      {:ok, out} ->
        case first_sha(out) do
          nil -> {:error, :ls_remote_empty}
          sha -> {:ok, sha}
        end

      {:error, %{exit_status: code} = err} ->
        {:error, {:ls_remote_failed, code, err}}
    end
  end

  @doc """
  Builds the canonical CAS intent payload for `git_push` (D-G16).

  Second argument must be a map with string keys `"local_commit_sha"` and
  `"refspec"`.
  """
  @spec push_intent_payload(String.t(), %{String.t() => String.t()}) :: map()
  def push_intent_payload(expected_remote_sha, %{
        "local_commit_sha" => local_commit_sha,
        "refspec" => refspec
      })
      when is_binary(expected_remote_sha) and is_binary(local_commit_sha) and is_binary(refspec) do
    %{
      "expected_remote_sha" => expected_remote_sha,
      "local_commit_sha" => local_commit_sha,
      "refspec" => refspec
    }
  end

  @doc """
  Classifies a failed `git push` using exit status and captured stderr text.

  Returns one of:

    * `:git_non_fast_forward` — rejected non-fast-forward update
    * `:git_remote_advanced` — remote moved unexpectedly vs CAS expectation
    * `:git_push_rejected` — generic rejection / unknown pattern
    * `:ok` — **only** when `exit_status == 0` (success); non-zero never returns `:ok`
  """
  @spec classify_push_failure(non_neg_integer(), String.t()) ::
          :git_non_fast_forward | :git_remote_advanced | :git_push_rejected | :ok
  def classify_push_failure(0, _), do: :ok

  def classify_push_failure(status, stderr)
      when is_integer(status) and is_binary(stderr) and status != 0 do
    s = String.downcase(stderr)

    cond do
      String.contains?(s, "non-fast-forward") ->
        :git_non_fast_forward

      String.contains?(s, "failed to push some refs") and String.contains?(s, "behind") ->
        :git_non_fast_forward

      String.contains?(s, "remote contains work that you do not have locally") ->
        :git_remote_advanced

      String.contains?(s, "stale info") ->
        :git_remote_advanced

      true ->
        :git_push_rejected
    end
  end

  @doc """
  Runs `git push` with argv list `["push", remote | rest...]` — caller supplies tail.

  Options:

    * `:runner` — `Kiln.Git.Cmd` impl or callback (default `default_runner/0`)
    * `:cd` — working directory forwarded to the runner
  """
  @spec run_push([String.t()], keyword()) :: {:ok, String.t()} | {:error, Cmd.error_map()}
  def run_push(argv, opts \\ []) when is_list(argv) do
    runner = normalize_runner(Keyword.get(opts, :runner, default_runner()))
    cd = Keyword.get(opts, :cd)
    runner_opts = if(cd, do: [cd: cd], else: [])

    git_call(runner, argv, runner_opts)
  end

  defp git_call(runner, argv, opts) when is_function(runner, 2), do: runner.(argv, opts)

  defp git_call(runner, argv, opts) when is_atom(runner), do: runner.run_git(argv, opts)

  defp first_sha(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.find_value(fn line ->
      case String.split(line, "\t", parts: 2) do
        [sha, _ref] -> valid_sha40?(sha) && sha
        _ -> nil
      end
    end)
  end

  defp valid_sha40?(<<a::binary-size(40)>>) do
    String.match?(a, ~r/^[0-9a-f]{40}$/)
  end

  defp valid_sha40?(_), do: false

  defp normalize_runner(nil), do: default_runner()
  defp normalize_runner(mod) when is_atom(mod), do: mod
  defp normalize_runner(fun) when is_function(fun, 2), do: fun
end
