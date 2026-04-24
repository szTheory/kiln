defmodule KilnWeb.AttachEntryLiveTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    Application.delete_env(:kiln, :attach_live_runtime_opts)

    on_exit(fn ->
      Application.delete_env(:kiln, :attach_live_runtime_opts)
    end)

    :ok
  end

  test "mounts the attach intake surface with stable ids and untouched guidance", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/attach")

    assert has_element?(view, "#attach-entry-root")
    assert has_element?(view, "#attach-entry-hero")
    assert has_element?(view, "#attach-supported-sources")
    assert has_element?(view, "#attach-source-form")
    assert has_element?(view, "#attach-source-input")
    assert has_element?(view, "#attach-source-submit")
    assert has_element?(view, "#attach-source-untouched")
    assert has_element?(view, "#attach-next-step")
    assert has_element?(view, "#attach-back-to-templates")
    refute has_element?(view, "#attach-source-resolved")
    refute has_element?(view, "#attach-source-error")
    assert html =~ "Supports a local path, an existing clone, or a GitHub URL."
  end

  test "submitting a safe local repo renders the attach ready summary", %{conn: conn} do
    repo_root =
      make_git_repo!("kiln_attach_live_valid",
        origin: "https://github.com/owner/live-ready.git"
      )

    configure_attach_runtime!("kiln_attach_live_ready_runtime")
    {:ok, view, _html} = live(conn, ~p"/attach")

    html =
      view
      |> form("#attach-source-form", attach_source: %{source: repo_root})
      |> render_submit()

    assert has_element?(view, "#attach-ready")
    assert has_element?(view, "#attach-ready-summary")
    refute has_element?(view, "#attach-blocked")
    assert html =~ "Attach ready for the next branch and draft PR phase"
    assert html =~ "owner/live-ready"
  end

  test "submitting an unsupported source renders typed remediation feedback", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/attach")

    html =
      view
      |> form("#attach-source-form", attach_source: %{source: "https://gitlab.com/example/kiln"})
      |> render_submit()

    assert html =~ "Only local paths and GitHub URLs are supported right now."
    assert html =~ "Use a local repo path, an existing clone, or a GitHub URL."
    assert has_element?(view, "#attach-source-error")
    refute has_element?(view, "#attach-source-resolved")
    refute html =~ "template_id"
    refute html =~ "return_to"
    refute html =~ "Start run"
    refute html =~ "Create draft PR"
  end

  test "submitting an unsafe local repo renders blocked remediation instead of a false ready state", %{
    conn: conn
  } do
    repo_root =
      make_git_repo!("kiln_attach_live_blocked",
        origin: "https://github.com/owner/live-blocked.git"
      )

    File.write!(Path.join(repo_root, "dirty.txt"), "dirty\n")
    configure_attach_runtime!("kiln_attach_live_blocked_runtime")
    {:ok, view, _html} = live(conn, ~p"/attach")

    view
    |> form("#attach-source-form", attach_source: %{source: repo_root})
    |> render_submit()

    html = render(view)

    assert has_element?(view, "#attach-blocked")
    assert has_element?(view, "#attach-remediation-summary")
    refute has_element?(view, "#attach-ready")
    assert html =~ "Kiln refuses to mark this attached repo ready"
    assert html =~ "Commit, stash, or discard the pending changes"
  end

  defp configure_attach_runtime!(name) do
    workspace_root = Path.join(System.tmp_dir!(), "#{name}_#{System.unique_integer([:positive])}")
    File.mkdir_p!(workspace_root)

    Application.put_env(:kiln, :attach_live_runtime_opts,
      workspace_root: workspace_root,
      git_runner: &git_runner/2,
      gh_runner: &gh_runner_ready/2
    )
  end

  defp make_git_repo!(name, opts) do
    repo_root =
      Path.join(System.tmp_dir!(), "#{name}_#{System.unique_integer([:positive, :monotonic])}")
    File.mkdir_p!(repo_root)

    {_, 0} = System.cmd("git", ["init", "--quiet", "--initial-branch=main", repo_root])
    File.write!(Path.join(repo_root, "README.md"), "# #{name}\n")
    {_, 0} = System.cmd("git", ["-C", repo_root, "add", "README.md"])

    {_, 0} =
      System.cmd("git", [
        "-C",
        repo_root,
        "-c",
        "user.name=Kiln Test",
        "-c",
        "user.email=test@example.com",
        "commit",
        "--quiet",
        "-m",
        "initial"
      ])

    if origin = Keyword.get(opts, :origin) do
      {_, 0} = System.cmd("git", ["-C", repo_root, "remote", "add", "origin", origin])
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
    {output, status} = System.cmd("git", argv, cd: cd, stderr_to_stdout: true)

    case status do
      0 -> {:ok, String.trim(output)}
      _ -> {:error, %{exit_status: status, stderr: output}}
    end
  end

  defp gh_runner_ready(["auth", "status"], _opts), do: {:ok, "github.com\n  Logged in\n"}
end
