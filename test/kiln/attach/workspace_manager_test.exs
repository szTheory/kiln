defmodule Kiln.Attach.WorkspaceManagerTest do
  use Kiln.DataCase, async: true

  alias Kiln.Attach
  alias Kiln.Attach.WorkspaceManager

  describe "hydrate/2" do
    test "creates and then reuses one managed workspace for a local attached repo" do
      source_repo = make_git_repo!("kiln_attach_workspace_local")
      workspace_root = temp_path("kiln_attach_workspace_root")
      File.mkdir_p!(workspace_root)

      source = local_source!(source_repo)

      assert {:ok, created} =
               WorkspaceManager.hydrate(source,
                 workspace_root: workspace_root,
                 git_runner: &git_runner/2
               )

      assert created.status == :created
      assert created.workspace_key == WorkspaceManager.workspace_key(source)
      assert String.starts_with?(created.workspace_path, Path.expand(workspace_root))
      assert created.managed_root == Path.expand(workspace_root)
      assert created.source_kind == :local_path
      assert created.remote_url == source.canonical_root
      assert created.base_branch == "main"
      assert git_repo?(created.workspace_path)

      assert {:ok, reused} =
               WorkspaceManager.hydrate(source,
                 workspace_root: workspace_root,
                 git_runner: &git_runner/2
               )

      assert reused.status == :reused
      assert reused.workspace_path == created.workspace_path
      assert reused.workspace_key == created.workspace_key
      assert reused.remote_url == created.remote_url
    end

    test "uses the canonical github clone url as the workspace remote" do
      workspace_root = temp_path("kiln_attach_workspace_root_remote")
      File.mkdir_p!(workspace_root)

      source = github_source!("https://github.com/elixir-lang/elixir")

      assert {:ok, hydrated} =
               WorkspaceManager.hydrate(source,
                 workspace_root: workspace_root,
                 git_runner: &github_git_runner/2
               )

      assert hydrated.status == :created
      assert hydrated.source_kind == :github_url
      assert hydrated.remote_url == "https://github.com/elixir-lang/elixir.git"
      assert hydrated.base_branch == "main"
      assert String.starts_with?(hydrated.workspace_path, Path.expand(workspace_root))
    end

    test "rejects workspace roots that are not absolute paths" do
      source_repo = make_git_repo!("kiln_attach_workspace_relative_root")
      source = local_source!(source_repo)

      assert {:error, %{code: :invalid_workspace_root} = error} =
               WorkspaceManager.hydrate(source,
                 workspace_root: "relative/root",
                 git_runner: &git_runner/2
               )

      assert error.message == "Attach workspace root must be an absolute path."
    end

    test "rejects a hydration result that escapes the managed root" do
      source_repo = make_git_repo!("kiln_attach_workspace_escape")
      workspace_root = temp_path("kiln_attach_workspace_escape_root")
      File.mkdir_p!(workspace_root)

      source = local_source!(source_repo)

      assert {:error, %{code: :workspace_path_not_allowed} = error} =
               WorkspaceManager.hydrate(source,
                 workspace_root: workspace_root,
                 workspace_dir_resolver: fn _root, _key ->
                   Path.join(Path.dirname(workspace_root), "escaped")
                 end,
                 git_runner: &git_runner/2
               )

      assert error.message == "Hydrated workspace escaped the managed attach root."
    end
  end

  describe "attached repo persistence" do
    test "persists canonical attached repo metadata for a hydrated local source" do
      source_repo = make_git_repo!("kiln_attach_persist_local")
      workspace_root = temp_path("kiln_attach_persist_root")
      File.mkdir_p!(workspace_root)

      source = local_source!(source_repo)

      {:ok, hydrated} =
        WorkspaceManager.hydrate(source,
          workspace_root: workspace_root,
          git_runner: &git_runner/2
        )

      assert {:ok, attached_repo} = Attach.create_or_update_attached_repo(source, hydrated)
      assert {:ok, fetched} = Attach.get_attached_repo(attached_repo.id)
      assert {:ok, by_key} = Attach.get_attached_repo_by_workspace_key(hydrated.workspace_key)

      assert fetched.id == attached_repo.id
      assert by_key.id == attached_repo.id
      assert attached_repo.source_kind == :local_path
      assert attached_repo.repo_provider == :local
      assert attached_repo.repo_slug == source.repo_identity.slug
      assert attached_repo.repo_name == source.repo_identity.name
      assert attached_repo.repo_owner == nil
      assert attached_repo.repo_host == nil
      assert attached_repo.canonical_input == source.canonical_input
      assert attached_repo.canonical_repo_root == source.canonical_root
      assert attached_repo.workspace_key == hydrated.workspace_key
      assert attached_repo.workspace_path == hydrated.workspace_path
      assert attached_repo.remote_url == hydrated.remote_url
      assert attached_repo.clone_url == nil
      assert attached_repo.default_branch == hydrated.base_branch
      assert attached_repo.base_branch == hydrated.base_branch
    end

    test "updates the existing attached repo row instead of duplicating repo identity" do
      source_repo = make_git_repo!("kiln_attach_persist_update")
      workspace_root = temp_path("kiln_attach_persist_update_root")
      File.mkdir_p!(workspace_root)

      source = local_source!(source_repo)

      {:ok, hydrated} =
        WorkspaceManager.hydrate(source,
          workspace_root: workspace_root,
          git_runner: &git_runner/2
        )

      assert {:ok, first} = Attach.create_or_update_attached_repo(source, hydrated)

      updated_hydrated = %{
        hydrated
        | base_branch: "release/test",
          workspace_path: hydrated.workspace_path
      }

      assert {:ok, second} = Attach.create_or_update_attached_repo(source, updated_hydrated)

      assert second.id == first.id
      assert second.base_branch == "release/test"
      assert second.workspace_key == hydrated.workspace_key
      assert second.workspace_path == hydrated.workspace_path
    end
  end

  defp local_source!(repo_root) do
    {:ok, source} = Attach.resolve_source(repo_root)
    source
  end

  defp github_source!(url) do
    {:ok, source} = Attach.resolve_source(url)
    source
  end

  defp make_git_repo!(name) do
    repo_root = temp_path(name)
    File.mkdir_p!(repo_root)

    run_git!(["init", "--initial-branch=main", repo_root])
    File.write!(Path.join(repo_root, "README.md"), "# #{name}\n")
    run_git!(["-C", repo_root, "add", "README.md"])

    run_git!([
      "-C",
      repo_root,
      "-c",
      "user.name=Kiln Test",
      "-c",
      "user.email=test@example.com",
      "commit",
      "-m",
      "initial"
    ])

    repo_root
  end

  defp run_git!(argv) do
    {output, 0} = System.cmd("git", argv, stderr_to_stdout: true)
    output
  end

  defp git_runner(["clone", source, destination], _opts) do
    {output, status} =
      System.cmd("git", ["clone", "--quiet", source, destination], stderr_to_stdout: true)

    case status do
      0 -> {:ok, output}
      _ -> {:error, %{exit_status: status, stderr: output}}
    end
  end

  defp git_runner(["symbolic-ref", "--short", "HEAD"], opts) do
    cd = Keyword.fetch!(opts, :cd)
    run_git_in_dir(["symbolic-ref", "--short", "HEAD"], cd)
  end

  defp git_runner(["remote", "get-url", "origin"], opts) do
    cd = Keyword.fetch!(opts, :cd)
    run_git_in_dir(["remote", "get-url", "origin"], cd)
  end

  defp git_runner(["rev-parse", "--show-toplevel"], opts) do
    cd = Keyword.fetch!(opts, :cd)
    run_git_in_dir(["rev-parse", "--show-toplevel"], cd)
  end

  defp github_git_runner(["clone", source, destination], _opts) do
    File.mkdir_p!(destination)
    run_git!(["init", "--initial-branch=main", destination])
    run_git!(["-C", destination, "remote", "add", "origin", source])
    {:ok, ""}
  end

  defp github_git_runner(argv, opts), do: git_runner(argv, opts)

  defp run_git_in_dir(argv, cd) do
    {output, status} = System.cmd("git", argv, cd: cd, stderr_to_stdout: true)

    case status do
      0 -> {:ok, String.trim(output)}
      _ -> {:error, %{exit_status: status, stderr: output}}
    end
  end

  defp git_repo?(path) do
    match?({:ok, _}, git_runner(["rev-parse", "--show-toplevel"], cd: path))
  end

  defp temp_path(name) do
    unique_suffix = "#{System.os_time(:microsecond)}_#{System.unique_integer([:positive])}"
    Path.join(System.tmp_dir!(), "#{name}_#{unique_suffix}")
  end
end
