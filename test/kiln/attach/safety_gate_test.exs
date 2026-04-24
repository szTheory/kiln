defmodule Kiln.Attach.SafetyGateTest do
  use Kiln.DataCase, async: true

  alias Kiln.Attach

  describe "preflight_workspace/3" do
    test "returns ready metadata for a clean local repo with GitHub topology and gh auth" do
      source_repo =
        make_git_repo!("kiln_attach_safety_ready",
          origin: "https://github.com/owner/ready-repo.git"
        )

      workspace_root = temp_path("kiln_attach_safety_ready_root")
      File.mkdir_p!(workspace_root)

      {:ok, source} = Attach.resolve_source(source_repo)

      assert {:ok, hydrated} =
               Attach.hydrate_workspace(source,
                 workspace_root: workspace_root,
                 git_runner: &git_runner/2
               )

      assert {:ok, ready} =
               Attach.preflight_workspace(source, hydrated,
                 git_runner: &git_runner/2,
                 gh_runner: &gh_runner_ready/2
               )

      assert ready.status == :ready
      assert ready.repo_slug == "owner/ready-repo"
      assert ready.base_branch == "main"
      assert ready.workspace_path == hydrated.workspace_path
      assert ready.remote_url == "https://github.com/owner/ready-repo.git"
      assert ready.source_kind == :local_path
    end

    test "blocks dirty local source repos before attach is marked ready" do
      source_repo =
        make_git_repo!("kiln_attach_safety_dirty",
          origin: "https://github.com/owner/dirty-repo.git"
        )

      File.write!(Path.join(source_repo, "uncommitted.txt"), "dirty\n")

      workspace_root = temp_path("kiln_attach_safety_dirty_root")
      File.mkdir_p!(workspace_root)

      {:ok, source} = Attach.resolve_source(source_repo)

      assert {:ok, hydrated} =
               Attach.hydrate_workspace(source,
                 workspace_root: workspace_root,
                 git_runner: &git_runner/2
               )

      assert {:blocked, blocked} =
               Attach.preflight_workspace(source, hydrated,
                 git_runner: &git_runner/2,
                 gh_runner: &gh_runner_ready/2
               )

      assert blocked.status == :blocked
      assert blocked.code == :dirty_worktree
      assert blocked.scope == :source_repo
      assert blocked.probe == "git status --porcelain"
      assert blocked.next_action =~ "Commit, stash, or discard"
    end

    test "blocks detached heads before attach is marked ready" do
      source_repo =
        make_git_repo!("kiln_attach_safety_detached",
          origin: "https://github.com/owner/detached-repo.git"
        )

      head_sha = run_git!(["-C", source_repo, "rev-parse", "HEAD"]) |> String.trim()
      run_git!(["-C", source_repo, "checkout", "--detach", head_sha])

      workspace_root = temp_path("kiln_attach_safety_detached_root")
      File.mkdir_p!(workspace_root)

      {:ok, source} = Attach.resolve_source(source_repo)

      assert {:ok, hydrated} =
               Attach.hydrate_workspace(source,
                 workspace_root: workspace_root,
                 git_runner: &git_runner/2
               )

      assert {:blocked, blocked} =
               Attach.preflight_workspace(source, hydrated,
                 git_runner: &git_runner/2,
                 gh_runner: &gh_runner_ready/2
               )

      assert blocked.code == :detached_head
      assert blocked.scope == :source_repo
      assert blocked.probe == "git symbolic-ref --short HEAD"
      assert blocked.next_action =~ "Check out the branch"
    end

    test "blocks missing gh auth with the operator setup remediation vocabulary" do
      source_repo =
        make_git_repo!("kiln_attach_safety_gh_auth",
          origin: "https://github.com/owner/gh-auth-repo.git"
        )

      workspace_root = temp_path("kiln_attach_safety_gh_auth_root")
      File.mkdir_p!(workspace_root)

      {:ok, source} = Attach.resolve_source(source_repo)

      assert {:ok, hydrated} =
               Attach.hydrate_workspace(source,
                 workspace_root: workspace_root,
                 git_runner: &git_runner/2
               )

      assert {:blocked, blocked} =
               Attach.preflight_workspace(source, hydrated,
                 git_runner: &git_runner/2,
                 gh_runner: &gh_runner_auth_missing/2
               )

      assert blocked.code == :github_auth_missing
      assert blocked.probe == "gh auth status"

      assert blocked.next_action ==
               "Run gh auth login (or equivalent) on this machine, then re-verify."
    end

    test "blocks local repos without a GitHub remote topology for later push and draft PR work" do
      source_repo = make_git_repo!("kiln_attach_safety_topology")
      workspace_root = temp_path("kiln_attach_safety_topology_root")
      File.mkdir_p!(workspace_root)

      {:ok, source} = Attach.resolve_source(source_repo)

      assert {:ok, hydrated} =
               Attach.hydrate_workspace(source,
                 workspace_root: workspace_root,
                 git_runner: &git_runner/2
               )

      assert {:blocked, blocked} =
               Attach.preflight_workspace(source, hydrated,
                 git_runner: &git_runner/2,
                 gh_runner: &gh_runner_ready/2
               )

      assert blocked.code == :github_remote_missing
      assert blocked.probe == "git remote get-url origin"
      assert blocked.next_action =~ "Add a GitHub origin remote"
    end
  end

  defp make_git_repo!(name, opts \\ []) do
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

    if origin = Keyword.get(opts, :origin) do
      run_git!(["-C", repo_root, "remote", "add", "origin", origin])
    end

    repo_root
  end

  defp git_runner(["clone", source, destination], _opts) do
    {output, status} =
      System.cmd("git", ["clone", "--quiet", source, destination], stderr_to_stdout: true)

    case status do
      0 -> {:ok, output}
      _ -> {:error, %{exit_status: status, stderr: output}}
    end
  end

  defp git_runner(argv, opts) do
    cd = Keyword.fetch!(opts, :cd)
    run_git_in_dir(argv, cd)
  end

  defp gh_runner_ready(["auth", "status"], _opts), do: {:ok, "github.com\n  Logged in\n"}

  defp gh_runner_auth_missing(["auth", "status"], _opts) do
    {:error, %{exit_status: 1, stderr: "authentication required; run gh auth login"}}
  end

  defp run_git!(argv) do
    {output, 0} = System.cmd("git", argv, stderr_to_stdout: true)
    output
  end

  defp run_git_in_dir(argv, cd) do
    {output, status} = System.cmd("git", argv, cd: cd, stderr_to_stdout: true)

    case status do
      0 -> {:ok, String.trim(output)}
      _ -> {:error, %{exit_status: status, stderr: output}}
    end
  end

  defp temp_path(name) do
    Path.join(
      System.tmp_dir!(),
      "#{name}_#{System.os_time(:microsecond)}_#{System.unique_integer([:positive, :monotonic])}"
    )
  end
end
