defmodule Kiln.Attach.WorkspaceManager do
  @moduledoc """
  Hydrates one managed writable workspace per attached repository.
  """

  alias Kiln.Attach.Source

  @enforce_keys [
    :status,
    :workspace_key,
    :workspace_path,
    :managed_root,
    :source_kind,
    :canonical_repo_root,
    :remote_url,
    :base_branch
  ]
  defstruct [
    :status,
    :workspace_key,
    :workspace_path,
    :managed_root,
    :source_kind,
    :canonical_repo_root,
    :remote_url,
    :base_branch
  ]

  @type status :: :created | :reused
  @type source_kind :: :local_path | :github_url

  @type result :: %__MODULE__{
          status: status(),
          workspace_key: String.t(),
          workspace_path: String.t(),
          managed_root: String.t(),
          source_kind: source_kind(),
          canonical_repo_root: String.t() | nil,
          remote_url: String.t() | nil,
          base_branch: String.t() | nil
        }

  @type error :: %{
          code: atom(),
          message: String.t(),
          remediation: String.t()
        }

  @type git_runner ::
          module()
          | ([String.t()], keyword() -> {:ok, String.t()} | {:error, map()})

  @spec workspace_key(Source.t()) :: String.t()
  def workspace_key(%Source{} = source) do
    fingerprint =
      case source.kind do
        :local_path -> "#{source.kind}:#{source.canonical_root}"
        :github_url -> "#{source.kind}:#{source.canonical_input}"
      end

    hash =
      :sha256
      |> :crypto.hash(fingerprint)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    slug =
      source.repo_identity.slug
      |> String.replace("/", "-")
      |> String.replace(~r/[^a-zA-Z0-9_-]+/, "-")
      |> String.trim("-")
      |> String.slice(0, 48)

    "#{slug}-#{hash}"
  end

  @spec hydrate(Source.t(), keyword()) :: {:ok, result()} | {:error, error()}
  def hydrate(%Source{} = source, opts \\ []) do
    with {:ok, managed_root} <- workspace_root(opts),
         :ok <- ensure_root(managed_root),
         {:ok, workspace_path, workspace_key} <- workspace_path(source, managed_root, opts) do
      if reusable_workspace?(workspace_path, opts) do
        build_result(:reused, source, managed_root, workspace_path, workspace_key, opts)
      else
        create_workspace(source, managed_root, workspace_path, workspace_key, opts)
      end
    end
  end

  defp create_workspace(source, managed_root, workspace_path, workspace_key, opts) do
    parent = Path.dirname(workspace_path)
    :ok = File.mkdir_p!(parent)

    case File.exists?(workspace_path) do
      true ->
        {:error,
         error(
           :workspace_not_usable,
           "Managed workspace path already exists but is not a reusable git repo.",
           "Remove the broken workspace directory or pick a new managed root."
         )}

      false ->
        case git_call(git_runner(opts), ["clone", clone_source(source), workspace_path], []) do
          {:ok, _} ->
            build_result(:created, source, managed_root, workspace_path, workspace_key, opts)

          {:error, reason} ->
            {:error,
             error(
               :hydrate_failed,
               "Could not hydrate the managed attach workspace.",
               "Check repo access and retry attach workspace preparation (#{inspect(reason)})."
             )}
        end
    end
  end

  defp build_result(status, source, managed_root, workspace_path, workspace_key, opts) do
    runner = git_runner(opts)
    remote_url = remote_url(source, workspace_path, runner)
    base_branch = base_branch(source, workspace_path, runner)

    {:ok,
     %__MODULE__{
       status: status,
       workspace_key: workspace_key,
       workspace_path: workspace_path,
       managed_root: managed_root,
       source_kind: source.kind,
       canonical_repo_root: source.canonical_root,
       remote_url: remote_url,
       base_branch: base_branch
     }}
  end

  defp workspace_root(opts) do
    root = Keyword.get(opts, :workspace_root, Application.get_env(:kiln, :attach_workspace_root))

    cond do
      not is_binary(root) or root == "" ->
        {:error,
         error(
           :invalid_workspace_root,
           "Attach workspace root must be configured before hydration.",
           "Set :attach_workspace_root or KILN_ATTACH_WORKSPACE_ROOT."
         )}

      Path.type(root) != :absolute ->
        {:error,
         error(
           :invalid_workspace_root,
           "Attach workspace root must be an absolute path.",
           "Configure one absolute managed root for attached workspaces."
         )}

      true ->
        {:ok, Path.expand(root)}
    end
  end

  defp ensure_root(root) do
    case File.mkdir_p(root) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error,
         error(
           :invalid_workspace_root,
           "Could not prepare the managed attach workspace root.",
           "Verify the configured root is writable (#{inspect(reason)})."
         )}
    end
  end

  defp workspace_path(source, managed_root, opts) do
    key = workspace_key(source)

    resolver =
      Keyword.get(opts, :workspace_dir_resolver, fn root, workspace_key ->
        Path.join(root, workspace_key)
      end)

    path = resolver.(managed_root, key) |> Path.expand()

    if within_root?(path, managed_root) do
      {:ok, path, key}
    else
      {:error,
       error(
         :workspace_path_not_allowed,
         "Hydrated workspace escaped the managed attach root.",
         "Keep attached workspaces inside the configured managed root."
       )}
    end
  end

  defp reusable_workspace?(workspace_path, opts) do
    File.dir?(workspace_path) and git_repo?(workspace_path, git_runner(opts))
  end

  defp git_repo?(workspace_path, runner) do
    match?({:ok, _}, git_call(runner, ["rev-parse", "--show-toplevel"], cd: workspace_path))
  end

  defp clone_source(%Source{kind: :local_path, canonical_root: canonical_root}),
    do: canonical_root

  defp clone_source(%Source{kind: :github_url, remote_metadata: %{clone_url: clone_url}})
       when is_binary(clone_url),
       do: clone_url

  defp remote_url(source, workspace_path, runner) do
    case git_call(runner, ["remote", "get-url", "origin"], cd: workspace_path) do
      {:ok, url} ->
        String.trim(url)

      {:error, _} ->
        fallback_remote_url(source)
    end
  end

  defp fallback_remote_url(%Source{kind: :local_path, canonical_root: canonical_root}),
    do: canonical_root

  defp fallback_remote_url(%Source{remote_metadata: %{clone_url: clone_url}}), do: clone_url

  defp base_branch(source, workspace_path, runner) do
    case git_call(runner, ["symbolic-ref", "--short", "HEAD"], cd: workspace_path) do
      {:ok, branch} ->
        String.trim(branch)

      {:error, _} ->
        source.remote_metadata.default_branch || "main"
    end
  end

  defp git_runner(opts), do: Keyword.get(opts, :git_runner, Kiln.Git.default_runner())

  defp git_call(runner, argv, opts) when is_function(runner, 2), do: runner.(argv, opts)
  defp git_call(runner, argv, opts) when is_atom(runner), do: runner.run_git(argv, opts)

  defp within_root?(path, root) do
    expanded_path = Path.expand(path)
    expanded_root = Path.expand(root)

    expanded_path == expanded_root or String.starts_with?(expanded_path, expanded_root <> "/")
  end

  defp error(code, message, remediation) do
    %{
      code: code,
      message: message,
      remediation: remediation
    }
  end
end
