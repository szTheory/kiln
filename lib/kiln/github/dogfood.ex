defmodule Kiln.GitHub.Dogfood do
  @moduledoc """
  Dogfood GitHub PR orchestration (Phase 9 / SC1).

  Every mutating REST call must be preceded by `external_operations`
  via `Kiln.Workers.DogfoodPRWorker` (D-903). Secrets are references only:
  `KILN_DOGFOOD_GITHUB_TOKEN` → `Kiln.Secrets` at boot (`:dogfood_github_token`);
  optional `KILN_DOGFOOD_REPOSITORY` (default `szTheory/kiln`) selects the repo.

  Tests may inject `Application.put_env(:kiln, Kiln.GitHub.Dogfood, sync_fun: fn args -> … end)`.
  """

  @default_allowlist MapSet.new([
                       "lib/kiln/version.ex",
                       "test/kiln/version_test.exs",
                       "README.md"
                     ])

  @spec default_allowlist() :: MapSet.t(String.t())
  def default_allowlist, do: @default_allowlist

  @spec branch_prefix() :: String.t()
  def branch_prefix, do: "kiln/dogfood/"

  @spec label_prefix() :: String.t()
  def label_prefix, do: "kiln-dogfood:"

  @doc """
  Returns `:ok` when every path is on the allowlist; otherwise
  `{:error, {:path_allowlist, rejected}}` (D-904).
  """
  @spec validate_changed_paths!([String.t()]) :: :ok | {:error, {:path_allowlist, [String.t()]}}
  def validate_changed_paths!(paths) when is_list(paths) do
    bad = Enum.reject(paths, &MapSet.member?(@default_allowlist, &1))

    if bad == [] do
      :ok
    else
      {:error, {:path_allowlist, bad}}
    end
  end

  @doc """
  Performs the GitHub side of the dogfood flow. Without credentials this
  returns `{:error, :missing_github_token}` so workers can fail closed.
  """
  @spec sync_pr(map()) :: {:ok, map()} | {:error, term()}
  def sync_pr(args) when is_map(args) do
    case Application.get_env(:kiln, __MODULE__, [])[:sync_fun] do
      fun when is_function(fun, 1) ->
        fun.(args)

      _ ->
        # Live HTTP path records `external_operations` rows only from
        # `Kiln.Workers.DogfoodPRWorker` (two-phase intent → completion).
        with :ok <- ensure_token(),
             {:ok, _repo} <- repo_slug() do
          {:error, :dogfood_http_not_configured}
        end
    end
  end

  defp ensure_token do
    if Kiln.Secrets.present?(:dogfood_github_token),
      do: :ok,
      else: {:error, :missing_github_token}
  end

  defp repo_slug do
    case System.get_env("KILN_DOGFOOD_REPOSITORY", "szTheory/kiln") do
      "" -> {:error, :missing_repository}
      slug -> {:ok, slug}
    end
  end
end
