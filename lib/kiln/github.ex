defmodule Kiln.GitHub do
  @moduledoc """
  Execution layer — GitHub integration (PR create, check observe, git push).

  Phase 6 wires **`Kiln.GitHub.Cli`**, **`Kiln.GitHub.Checks`**, and Oban workers
  on the `external_operations` taxonomy (`git_push`, `gh_pr_create`,
  `gh_check_observe`).

  This module is a thin delegating façade so callers import one namespace.
  """

  @spec create_pr(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_pr(attrs, opts \\ []), do: Kiln.GitHub.Cli.create_pr(attrs, opts)

  @spec list_check_runs(String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def list_check_runs(repo, pr, opts \\ []), do: Kiln.GitHub.Cli.list_check_runs(repo, pr, opts)

  @spec classify_gh_error(String.t(), integer()) ::
          :gh_auth_expired | :gh_permissions_insufficient | :gh_cli_failed
  def classify_gh_error(stderr, code), do: Kiln.GitHub.Cli.classify_gh_error(stderr, code)

  @spec summarize(map(), map()) :: {:ok, map()} | {:error, :checks_transport_unsupported}
  def summarize(decoded, opts \\ %{}), do: Kiln.GitHub.Checks.summarize(decoded, opts)
end
