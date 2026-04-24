defmodule KilnWeb.AttachEntryLiveTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.Attach.AttachedRepo
  alias Kiln.Runs.Run
  alias Kiln.Specs.{Spec, SpecDraft, SpecRevision}

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

  test "ready state renders the bounded attached request form with stable ids", %{conn: conn} do
    repo_root =
      make_git_repo!("kiln_attach_live_request_form",
        origin: "https://github.com/owner/live-request-form.git"
      )

    configure_attach_runtime!("kiln_attach_live_request_form_runtime")
    {:ok, view, _html} = live(conn, ~p"/attach")

    view
    |> form("#attach-source-form", attach_source: %{source: repo_root})
    |> render_submit()

    html = render(view)

    assert has_element?(view, "#attach-ready")
    assert has_element?(view, "#attach-request-form")
    assert has_element?(view, "#attach-request-kind")
    assert has_element?(view, "#attach-request-title")
    assert has_element?(view, "#attach-request-summary")
    assert has_element?(view, "#attach-request-acceptance-1")
    assert has_element?(view, "#attach-request-acceptance-2")
    assert has_element?(view, "#attach-request-acceptance-3")
    assert has_element?(view, "#attach-request-out-of-scope-1")
    assert has_element?(view, "#attach-request-out-of-scope-2")
    assert has_element?(view, "#attach-request-out-of-scope-3")
    assert has_element?(view, "#attach-request-submit")
    assert html =~ ~s(name="attach_request[acceptance_criteria][]")
    assert html =~ ~s(name="attach_request[out_of_scope][]")
    refute has_element?(view, "#attach-run-started")
  end

  test "submitting a vague attached request stays on the form with validation errors", %{
    conn: conn
  } do
    repo_root =
      make_git_repo!("kiln_attach_live_invalid_request",
        origin: "https://github.com/owner/live-invalid-request.git"
      )

    configure_attach_runtime!("kiln_attach_live_invalid_request_runtime")
    {:ok, view, _html} = live(conn, ~p"/attach")

    view
    |> form("#attach-source-form", attach_source: %{source: repo_root})
    |> render_submit()

    html =
      view
      |> form("#attach-request-form",
        attach_request: %{
          request_kind: "",
          title: "   ",
          change_summary: "   ",
          acceptance_criteria: ["   ", "", "   "],
          out_of_scope: ["", "  ", ""]
        }
      )
      |> render_submit()

    assert has_element?(view, "#attach-request-form")
    assert has_element?(view, "#attach-ready")
    refute has_element?(view, "#attach-run-started")
    assert html =~ "can&#39;t be blank"
    assert html =~ "must include at least one item"
  end

  test "submitting a valid attached request promotes the draft and starts the run", %{conn: conn} do
    repo_root =
      make_git_repo!("kiln_attach_live_valid_request",
        origin: "https://github.com/owner/live-valid-request.git"
      )

    parent = self()

    configure_attach_runtime!("kiln_attach_live_valid_request_runtime",
      create_or_update_attached_repo_fn: fn _resolved_source, _hydrated ->
        {:ok, %AttachedRepo{id: "attached-123"}}
      end,
      intake_fn: fn attached_repo_id, attrs ->
        send(parent, {:intake_called, attached_repo_id, attrs})
        {:ok, %SpecDraft{id: "draft-123"}}
      end,
      promote_draft_fn: fn draft_id, opts ->
        send(parent, {:promote_called, draft_id, opts})

        {:ok,
         %{
           draft: %SpecDraft{id: draft_id},
           spec: %Spec{id: "spec-123"},
           revision: %SpecRevision{
             id: "rev-123",
             spec_id: "spec-123",
             attached_repo_id: "attached-123"
           }
         }}
      end,
      start_for_attached_request_fn: fn promoted_request, attached_repo_id, opts ->
        send(parent, {:start_called, promoted_request, attached_repo_id, opts})
        {:ok, %Run{id: "run-123"}}
      end
    )

    {:ok, view, _html} = live(conn, ~p"/attach")

    view
    |> form("#attach-source-form", attach_source: %{source: repo_root})
    |> render_submit()

    html =
      view
      |> form("#attach-request-form",
        attach_request: %{
          request_kind: "feature",
          title: "Tighten attach success flow",
          change_summary: "Add one bounded launch path for ready attached repos.",
          acceptance_criteria: [
            "Ready state shows one bounded request form.",
            "Valid submit starts one attached run.",
            ""
          ],
          out_of_scope: [
            "Repeat-run continuity",
            "Draft PR handoff polish",
            "   "
          ]
        }
      )
      |> render_submit()

    assert_receive {:intake_called, "attached-123", attrs}

    assert attrs["acceptance_criteria"] == [
             "Ready state shows one bounded request form.",
             "Valid submit starts one attached run.",
             ""
           ]

    assert attrs["out_of_scope"] == ["Repeat-run continuity", "Draft PR handoff polish", "   "]
    assert_receive {:promote_called, "draft-123", _opts}

    assert_receive {:start_called,
                    %{spec: %Spec{id: "spec-123"}, revision: %SpecRevision{id: "rev-123"}},
                    "attached-123", _opts}

    assert has_element?(view, "#attach-run-started")
    refute has_element?(view, "#attach-request-form")
    assert html =~ "run-123"
  end

  test "blocked attach start stays on the form without persisting duplicate request records", %{
    conn: conn
  } do
    repo_root =
      make_git_repo!("kiln_attach_live_blocked_request",
        origin: "https://github.com/owner/live-blocked-request.git"
      )

    parent = self()

    configure_attach_runtime!("kiln_attach_live_blocked_request_runtime",
      create_or_update_attached_repo_fn: fn _resolved_source, _hydrated ->
        {:ok, %AttachedRepo{id: "attached-123"}}
      end,
      preflight_attached_request_start_fn: fn ->
        {:blocked,
         %{
           reason: :factory_not_ready,
           blocker: %{label: "Anthropic API key"},
           settings_target: "/settings#settings-item-anthropic"
         }}
      end,
      intake_fn: fn attached_repo_id, attrs ->
        send(parent, {:intake_called, attached_repo_id, attrs})
        {:ok, %SpecDraft{id: "draft-123"}}
      end,
      promote_draft_fn: fn draft_id, opts ->
        send(parent, {:promote_called, draft_id, opts})

        {:ok,
         %{
           draft: %SpecDraft{id: draft_id},
           spec: %Spec{id: "spec-123"},
           revision: %SpecRevision{id: "rev-123"}
         }}
      end
    )

    {:ok, view, _html} = live(conn, ~p"/attach")

    view
    |> form("#attach-source-form", attach_source: %{source: repo_root})
    |> render_submit()

    request_params = %{
      request_kind: "feature",
      title: "Retry-safe blocked launch",
      change_summary: "Do not persist drafts before the run can start.",
      acceptance_criteria: ["Blocked submit stays in place.", "", ""],
      out_of_scope: ["Draft PR polish", "", ""]
    }

    html =
      view
      |> form("#attach-request-form", attach_request: request_params)
      |> render_submit()

    assert has_element?(view, "#attach-request-form")
    refute has_element?(view, "#attach-run-started")
    assert html =~ "operator setup is complete"
    refute_receive {:intake_called, _, _}
    refute_receive {:promote_called, _, _}

    view
    |> form("#attach-request-form", attach_request: request_params)
    |> render_submit()

    refute_receive {:intake_called, _, _}
    refute_receive {:promote_called, _, _}
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

  test "submitting an unsafe local repo renders blocked remediation instead of a false ready state",
       %{
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

  defp configure_attach_runtime!(name, extra_opts \\ []) do
    workspace_root = Path.join(System.tmp_dir!(), "#{name}_#{System.unique_integer([:positive])}")
    File.mkdir_p!(workspace_root)

    Application.put_env(
      :kiln,
      :attach_live_runtime_opts,
      Keyword.merge(
        [
          workspace_root: workspace_root,
          git_runner: &git_runner/2,
          gh_runner: &gh_runner_ready/2,
          preflight_attached_request_start_fn: fn -> :ok end
        ],
        extra_opts
      )
    )
  end

  defp make_git_repo!(name, opts) do
    repo_root =
      Path.join(
        System.tmp_dir!(),
        "#{name}_#{System.os_time(:microsecond)}_#{System.unique_integer([:positive, :monotonic])}"
      )

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
