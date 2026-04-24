defmodule Kiln.Attach.Source do
  @moduledoc """
  Resolves an operator-supplied attach source into one canonical repo contract.
  """

  alias Kiln.Git

  @enforce_keys [
    :kind,
    :input,
    :canonical_input,
    :canonical_root,
    :repo_identity,
    :remote_metadata
  ]
  defstruct [
    :kind,
    :input,
    :canonical_input,
    :canonical_root,
    :repo_identity,
    :remote_metadata
  ]

  @type repo_identity :: %{
          provider: :local | :github,
          host: String.t() | nil,
          owner: String.t() | nil,
          name: String.t(),
          slug: String.t()
        }

  @type remote_metadata :: %{
          url: String.t() | nil,
          clone_url: String.t() | nil,
          default_branch: String.t() | nil,
          head_sha: String.t() | nil
        }

  @type error :: %{
          code: atom(),
          field: :source,
          input: String.t(),
          message: String.t(),
          remediation: String.t()
        }

  @type t :: %__MODULE__{
          kind: :local_path | :github_url,
          input: String.t(),
          canonical_input: String.t(),
          canonical_root: String.t() | nil,
          repo_identity: repo_identity(),
          remote_metadata: remote_metadata()
        }

  @type repo_root_resolver :: (String.t() -> {:ok, String.t()} | {:error, atom()})

  @spec resolve(String.t(), keyword()) :: {:ok, t()} | {:error, error()}
  def resolve(raw_input, opts \\ []) when is_binary(raw_input) do
    input = String.trim(raw_input)

    cond do
      input == "" ->
        {:error,
         error(
           :blank_source,
           raw_input,
           "Enter a local path or GitHub URL.",
           "Provide a local repo path, an existing clone, or a GitHub URL."
         )}

      true ->
        case classify_input(input) do
          :local_path -> resolve_local_path(input, opts)
          :github_url -> resolve_github_url(input)
          :unsupported_url -> unsupported_source(input)
        end
    end
  end

  defp resolve_local_path(input, opts) do
    expanded = Path.expand(input)

    cond do
      not File.exists?(expanded) ->
        {:error,
         error(
           :path_not_found,
           expanded,
           "Path does not exist on this machine.",
           "Check the path and try again, or attach via a GitHub URL."
         )}

      true ->
        resolver = Keyword.get(opts, :repo_root_resolver, &default_repo_root_resolver/1)

        case resolver.(expanded) do
          {:ok, root} ->
            canonical_root = Path.expand(root)
            repo_name = Path.basename(canonical_root)

            {:ok,
             %__MODULE__{
               kind: :local_path,
               input: expanded,
               canonical_input: expanded,
               canonical_root: canonical_root,
               repo_identity: %{
                 provider: :local,
                 host: nil,
                 owner: nil,
                 name: repo_name,
                 slug: repo_name
               },
               remote_metadata: %{
                 url: nil,
                 clone_url: nil,
                 default_branch: nil,
                 head_sha: nil
               }
             }}

          {:error, :not_a_git_repo} ->
            {:error,
             error(
               :not_a_git_repo,
               expanded,
               "Path exists but is not inside a git repository.",
               "Choose a local git repo, an existing clone, or a GitHub URL."
             )}

          {:error, _reason} ->
            {:error,
             error(
               :source_resolution_failed,
               expanded,
               "Could not resolve the repository root.",
               "Try a different path or use a GitHub URL."
             )}
        end
    end
  end

  defp resolve_github_url(input) do
    case parse_github_url(input) do
      {:ok, %{owner: owner, repo: repo, canonical_url: canonical_url}} ->
        {:ok,
         %__MODULE__{
           kind: :github_url,
           input: input,
           canonical_input: canonical_url,
           canonical_root: nil,
           repo_identity: %{
             provider: :github,
             host: "github.com",
             owner: owner,
             name: repo,
             slug: "#{owner}/#{repo}"
           },
           remote_metadata: %{
             url: canonical_url,
             clone_url: "#{canonical_url}.git",
             default_branch: nil,
             head_sha: nil
           }
         }}

      :error ->
        unsupported_source(input)
    end
  end

  defp unsupported_source(input) do
    {:error,
     error(
       :unsupported_source,
       input,
       "Only local paths and GitHub URLs are supported right now.",
       "Use a local repo path, an existing clone, or a GitHub URL."
     )}
  end

  defp classify_input(input) do
    cond do
      github_url?(input) -> :github_url
      url_like?(input) -> :unsupported_url
      true -> :local_path
    end
  end

  defp github_url?(input) do
    String.match?(
      input,
      ~r/^(https?:\/\/github\.com\/|ssh:\/\/git@github\.com\/|git@github\.com:)/
    )
  end

  defp url_like?(input) do
    String.contains?(input, "://") or String.starts_with?(input, "git@")
  end

  defp parse_github_url(input) do
    with {:ok, owner, repo} <- parse_github_segments(input) do
      {:ok,
       %{
         owner: owner,
         repo: repo,
         canonical_url: "https://github.com/#{owner}/#{repo}"
       }}
    end
  end

  defp parse_github_segments("git@github.com:" <> rest), do: parse_owner_repo(rest)

  defp parse_github_segments(input) do
    uri = URI.parse(input)

    case {uri.host, uri.path} do
      {"github.com", path} when is_binary(path) -> parse_owner_repo(path)
      _ -> :error
    end
  end

  defp parse_owner_repo(path) do
    segments =
      path
      |> String.trim("/")
      |> String.replace_suffix(".git", "")
      |> String.split("/", trim: true)

    case segments do
      [owner, repo] when owner != "" and repo != "" -> {:ok, owner, repo}
      _ -> :error
    end
  end

  defp default_repo_root_resolver(path) do
    runner = Git.default_runner()

    case runner.run_git(["rev-parse", "--show-toplevel"], cd: path) do
      {:ok, output} ->
        {:ok, output |> String.trim() |> Path.expand()}

      {:error, %{stderr: stderr}} ->
        if String.contains?(String.downcase(stderr || ""), "not a git repository") do
          {:error, :not_a_git_repo}
        else
          {:error, :repo_root_lookup_failed}
        end
    end
  end

  defp error(code, input, message, remediation) do
    %{
      code: code,
      field: :source,
      input: input,
      message: message,
      remediation: remediation
    }
  end
end
