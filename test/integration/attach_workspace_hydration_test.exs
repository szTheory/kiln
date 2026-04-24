defmodule Kiln.Integration.AttachWorkspaceHydrationTest do
  @moduledoc false

  use Kiln.DataCase, async: true

  alias Kiln.Attach
  alias Kiln.Attach.WorkspaceManager

  test "one resolved local source hydrates to one reusable managed workspace" do
    source_repo = make_git_repo!("kiln_attach_integration_local")
    workspace_root = temp_path("kiln_attach_integration_root")
    File.mkdir_p!(workspace_root)

    {:ok, source} = Attach.resolve_source(source_repo)

    assert {:ok, first} =
             Attach.hydrate_workspace(source,
               workspace_root: workspace_root,
               git_runner: &git_runner/2
             )

    assert {:ok, second} =
             Attach.hydrate_workspace(source,
               workspace_root: workspace_root,
               git_runner: &git_runner/2
             )

    assert first.workspace_key == second.workspace_key
    assert first.workspace_path == second.workspace_path
    assert first.status == :created
    assert second.status == :reused
    assert String.starts_with?(first.workspace_path, Path.expand(workspace_root))
    assert WorkspaceManager.workspace_key(source) == first.workspace_key
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

  defp run_git_in_dir(argv, cd) do
    {output, status} = System.cmd("git", argv, cd: cd, stderr_to_stdout: true)

    case status do
      0 -> {:ok, String.trim(output)}
      _ -> {:error, %{exit_status: status, stderr: output}}
    end
  end

  defp temp_path(name) do
    unique_suffix = "#{System.os_time(:microsecond)}_#{System.unique_integer([:positive])}"
    Path.join(System.tmp_dir!(), "#{name}_#{unique_suffix}")
  end
end
