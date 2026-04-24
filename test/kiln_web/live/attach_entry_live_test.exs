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

  test "route-backed continuity renders recent repos and carried-forward request context", %{
    conn: conn
  } do
    attached_repo = attached_repo_fixture("attached-continuity-123")
    attached_repo_id = attached_repo.id
    recent_repo = recent_repo_summary(attached_repo.id)
    parent = self()

    configure_attach_runtime!("kiln_attach_live_continuity_runtime",
      list_recent_attached_repos_fn: fn _opts -> [recent_repo] end,
      get_repo_continuity_fn: fn attached_repo_id, opts ->
        send(parent, {:continuity_loaded, attached_repo_id, opts})
        {:ok, continuity_fixture(attached_repo)}
      end,
      mark_repo_selected_fn: fn attached_repo_id, _opts ->
        send(parent, {:repo_selected, attached_repo_id})
        {:ok, attached_repo}
      end
    )

    {:ok, view, _html} = live(conn, ~p"/attach?attached_repo_id=#{attached_repo.id}")

    assert_receive {:continuity_loaded, ^attached_repo_id, []}
    assert_receive {:repo_selected, ^attached_repo_id}
    assert has_element?(view, "#attach-recent-repos")
    assert has_element?(view, "#attach-recent-repo-#{attached_repo.id}")
    assert has_element?(view, "#attach-continuity")
    assert has_element?(view, "#attach-continuity-card")
    assert has_element?(view, "#attach-continuity-carried-forward")
    assert has_element?(view, "#attach-start-blank")
    assert has_element?(view, "#attach-request-acceptance-1[value='Keep prior context']")

    html = render(view)
    assert html =~ "Continuity request title"
    assert html =~ "Carry forward from the most recent promoted request."
  end

  test "start blank clears carried-forward request fields and restore brings them back", %{
    conn: conn
  } do
    attached_repo = attached_repo_fixture("attached-continuity-blank-123")

    configure_attach_runtime!("kiln_attach_live_blank_runtime",
      list_recent_attached_repos_fn: fn _opts -> [recent_repo_summary(attached_repo.id)] end,
      get_repo_continuity_fn: fn _, _ -> {:ok, continuity_fixture(attached_repo)} end,
      mark_repo_selected_fn: fn _, _ -> {:ok, attached_repo} end
    )

    {:ok, view, _html} = live(conn, ~p"/attach?attached_repo_id=#{attached_repo.id}")

    assert has_element?(view, "#attach-request-acceptance-1[value='Keep prior context']")

    view
    |> element("#attach-start-blank")
    |> render_click()

    refute has_element?(view, "#attach-request-acceptance-1[value='Keep prior context']")
    assert has_element?(view, "#attach-continue-carried-forward")
    assert render(view) =~ "Start blank for this repo."

    view
    |> element("#attach-continue-carried-forward")
    |> render_click()

    assert has_element?(view, "#attach-request-acceptance-1[value='Keep prior context']")
    refute has_element?(view, "#attach-continue-carried-forward")
  end

  test "continuity submit refreshes the repo before starting a repeat run and records launch metadata",
       %{conn: conn} do
    attached_repo = attached_repo_fixture("attached-continuity-submit-123")
    attached_repo_id = attached_repo.id
    refreshed_repo = %{attached_repo | workspace_path: "/tmp/refreshed-kiln"}
    refreshed_repo_id = refreshed_repo.id
    parent = self()

    configure_attach_runtime!("kiln_attach_live_submit_runtime",
      list_recent_attached_repos_fn: fn _opts -> [recent_repo_summary(attached_repo.id)] end,
      get_repo_continuity_fn: fn _, _ -> {:ok, continuity_fixture(attached_repo)} end,
      mark_repo_selected_fn: fn _, _ -> {:ok, attached_repo} end,
      refresh_attached_repo_fn: fn repo, _opts ->
        send(parent, {:refresh_called, repo.id})
        {:ok, %{attached_repo: refreshed_repo}}
      end,
      intake_fn: fn attached_repo_id, attrs ->
        send(parent, {:intake_called, attached_repo_id, attrs})
        {:ok, %SpecDraft{id: "draft-123"}}
      end,
      promote_draft_fn: fn draft_id, _opts ->
        send(parent, {:promote_called, draft_id})

        {:ok,
         %{
           draft: %SpecDraft{id: draft_id},
           spec: %Spec{id: "spec-123"},
           revision: %SpecRevision{
             id: "rev-123",
             spec_id: "spec-123",
             attached_repo_id: refreshed_repo.id
           }
         }}
      end,
      start_for_attached_request_fn: fn promoted_request, attached_repo_id, _opts ->
        send(parent, {:start_called, promoted_request, attached_repo_id})
        {:ok, %Run{id: "run-123"}}
      end,
      mark_run_started_fn: fn attached_repo_id, _opts ->
        send(parent, {:run_marked, attached_repo_id})
        {:ok, refreshed_repo}
      end
    )

    {:ok, view, _html} = live(conn, ~p"/attach?attached_repo_id=#{attached_repo.id}")

    html =
      view
      |> form("#attach-request-form",
        attach_request: %{
          request_kind: "feature",
          title: "Repeat continuity launch",
          change_summary: "Rerun a bounded request after rechecking the repo.",
          acceptance_criteria: ["refresh happens first", "run launch stays linked", ""],
          out_of_scope: ["new repo resolution", "", ""]
        }
      )
      |> render_submit()

    assert_receive {:refresh_called, ^attached_repo_id}
    assert_receive {:intake_called, ^refreshed_repo_id, attrs}
    assert attrs["title"] == "Repeat continuity launch"
    assert_receive {:promote_called, "draft-123"}

    assert_receive {:start_called,
                    %{spec: %Spec{id: "spec-123"}, revision: %SpecRevision{id: "rev-123"}},
                    ^refreshed_repo_id}

    assert_receive {:run_marked, ^refreshed_repo_id}
    assert has_element?(view, "#attach-run-started")
    assert html =~ "run-123"
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
      end,
      mark_run_started_fn: fn attached_repo_id, _opts ->
        send(parent, {:mark_run_started_called, attached_repo_id})
        {:ok, %AttachedRepo{id: attached_repo_id}}
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

    assert_receive {:mark_run_started_called, "attached-123"}

    assert has_element?(view, "#attach-run-started")
    refute has_element?(view, "#attach-request-form")
    assert html =~ "run-123"
  end

  test "warning-only findings render a distinct narrowing state and accept the suggested request",
       %{conn: conn} do
    repo_root =
      make_git_repo!("kiln_attach_live_warning_request",
        origin: "https://github.com/owner/live-warning-request.git"
      )

    parent = self()

    configure_attach_runtime!("kiln_attach_live_warning_request_runtime",
      create_or_update_attached_repo_fn: fn _resolved_source, _hydrated ->
        {:ok,
         %AttachedRepo{
           id: "attached-123",
           repo_slug: "owner/live-warning-request",
           base_branch: "main"
         }}
      end,
      brownfield_preflight_fn: fn attached_repo, params, _opts ->
        case params["title"] || params[:title] do
          "Narrow attach success flow" ->
            brownfield_clear_report(attached_repo, params)

          _ ->
            send(parent, {:warning_report_requested, attached_repo.id})
            brownfield_warning_report(attached_repo, params)
        end
      end,
      intake_fn: fn attached_repo_id, attrs ->
        send(parent, {:warning_intake_called, attached_repo_id, attrs})
        {:ok, %SpecDraft{id: "draft-warning-123"}}
      end,
      promote_draft_fn: fn draft_id, _opts ->
        {:ok,
         %{
           draft: %SpecDraft{id: draft_id},
           spec: %Spec{id: "spec-warning-123"},
           revision: %SpecRevision{id: "rev-warning-123", spec_id: "spec-warning-123"}
         }}
      end,
      start_for_attached_request_fn: fn promoted_request, attached_repo_id, _opts ->
        send(parent, {:warning_start_called, promoted_request, attached_repo_id})
        {:ok, %Run{id: "run-warning-123"}}
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
          acceptance_criteria: ["Ready state shows one bounded request form.", "", ""],
          out_of_scope: ["Draft PR polish", "", ""]
        }
      )
      |> render_submit()

    assert_receive {:warning_report_requested, "attached-123"}
    assert has_element?(view, "#attach-warning")
    assert has_element?(view, "#attach-warning-findings")
    assert has_element?(view, "#attach-narrowing-accept")
    assert has_element?(view, "#attach-warning-edit")
    assert has_element?(view, "#attach-warning-inspect-possible_overlap")
    refute has_element?(view, "#attach-blocked")
    refute_receive {:warning_start_called, _, _}
    assert html =~ "request should be narrowed first"

    view
    |> element("#attach-warning-inspect-possible_overlap")
    |> render_click()

    assert has_element?(view, "#attach-warning-inspect-panel")
    assert render(view) =~ "Prior draft"

    view
    |> element("#attach-narrowing-accept")
    |> render_click()

    assert has_element?(view, "#attach-request-title[value='Narrow attach success flow']")

    html =
      view
      |> form("#attach-request-form",
        attach_request: %{
          request_kind: "feature",
          title: "Narrow attach success flow",
          change_summary: "Limit launch to one bounded attached-repo path.",
          acceptance_criteria: ["Ready state shows one bounded request form.", "", ""],
          out_of_scope: ["Draft PR polish", "", ""]
        }
      )
      |> render_submit()

    assert_receive {:warning_intake_called, "attached-123", attrs}
    assert attrs["title"] == "Narrow attach success flow"
    assert_receive {:warning_start_called, _, "attached-123"}
    assert has_element?(view, "#attach-run-started")
    assert html =~ "run-warning-123"
  end

  test "fatal brownfield findings stop before run start and render the blocked state", %{
    conn: conn
  } do
    repo_root =
      make_git_repo!("kiln_attach_live_fatal_request",
        origin: "https://github.com/owner/live-fatal-request.git"
      )

    parent = self()

    configure_attach_runtime!("kiln_attach_live_fatal_request_runtime",
      create_or_update_attached_repo_fn: fn _resolved_source, _hydrated ->
        {:ok,
         %AttachedRepo{
           id: "attached-fatal-123",
           repo_slug: "owner/live-fatal-request",
           base_branch: "main"
         }}
      end,
      brownfield_preflight_fn: fn attached_repo, params, _opts ->
        brownfield_fatal_report(attached_repo, params)
      end,
      start_for_attached_request_fn: fn promoted_request, attached_repo_id, _opts ->
        send(parent, {:fatal_start_called, promoted_request, attached_repo_id})
        {:ok, %Run{id: "run-fatal-123"}}
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
          acceptance_criteria: ["Ready state shows one bounded request form.", "", ""],
          out_of_scope: ["Draft PR polish", "", ""]
        }
      )
      |> render_submit()

    assert has_element?(view, "#attach-blocked")
    assert has_element?(view, "#attach-blocked-findings")
    refute has_element?(view, "#attach-warning")
    refute_receive {:fatal_start_called, _, _}
    assert html =~ "active same-lane run"
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
          brownfield_preflight_fn: fn attached_repo, params, _opts ->
            brownfield_clear_report(attached_repo, params)
          end,
          mark_run_started_fn: fn attached_repo_id, _opts ->
            {:ok, %AttachedRepo{id: attached_repo_id}}
          end,
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

  defp brownfield_clear_report(attached_repo, params) do
    %{
      attached_repo_id: attached_repo.id,
      repo_slug: attached_repo.repo_slug,
      base_branch: attached_repo.base_branch,
      request: brownfield_request(params),
      findings: [],
      suggested_request: nil
    }
  end

  defp brownfield_warning_report(attached_repo, params) do
    request = brownfield_request(params)

    %{
      attached_repo_id: attached_repo.id,
      repo_slug: attached_repo.repo_slug,
      base_branch: attached_repo.base_branch,
      request: request,
      findings: [
        %{
          severity: :warning,
          code: :possible_overlap,
          title: "This request may overlap a prior draft",
          why: "Kiln found a recent same-repo draft with similar scope.",
          next_action: "Inspect the prior draft and narrow the request before starting.",
          evidence: %{
            repo_slug: attached_repo.repo_slug,
            base_branch: attached_repo.base_branch,
            draft_id: "draft-prior-123"
          }
        }
      ],
      suggested_request: %{
        request_kind: :feature,
        title: "Narrow attach success flow",
        change_summary: "Limit launch to one bounded attached-repo path.",
        acceptance_criteria: ["Ready state shows one bounded request form."],
        out_of_scope: ["Draft PR polish"]
      }
    }
  end

  defp brownfield_fatal_report(attached_repo, params) do
    request = brownfield_request(params)

    %{
      attached_repo_id: attached_repo.id,
      repo_slug: attached_repo.repo_slug,
      base_branch: attached_repo.base_branch,
      request: request,
      findings: [
        %{
          severity: :fatal,
          code: :same_lane_ambiguity,
          title: "Kiln already has an active same-lane run",
          why: "A same-lane run is already targeting this repo and base branch.",
          next_action: "Finish or cancel the active lane before starting another run.",
          evidence: %{
            repo_slug: attached_repo.repo_slug,
            base_branch: attached_repo.base_branch,
            run_id: "run-prior-123"
          }
        }
      ],
      suggested_request: nil
    }
  end

  defp brownfield_request(params) do
    %{
      request_kind:
        case params["request_kind"] || params[:request_kind] do
          "bugfix" -> :bugfix
          :bugfix -> :bugfix
          _ -> :feature
        end,
      title: params["title"] || params[:title],
      change_summary: params["change_summary"] || params[:change_summary],
      acceptance_criteria: params["acceptance_criteria"] || params[:acceptance_criteria] || [],
      out_of_scope: params["out_of_scope"] || params[:out_of_scope] || []
    }
  end

  defp attached_repo_fixture(id) do
    %AttachedRepo{
      id: id,
      repo_slug: "jon/kiln",
      workspace_path: "/tmp/kiln-workspace",
      base_branch: "main"
    }
  end

  defp continuity_fixture(attached_repo) do
    %{
      attached_repo: attached_repo,
      last_run: %{id: "run-prior-123", state: :completed},
      last_request: %{
        kind: :promoted_request,
        source_id: "revision-prior-123",
        draft_id: nil,
        run_id: nil,
        spec_id: "spec-prior-123",
        spec_revision_id: "revision-prior-123",
        title: "Continuity request title",
        request_kind: :feature,
        change_summary: "Carry forward from the most recent promoted request.",
        acceptance_criteria: ["Keep prior context", "Start from known repo state"],
        out_of_scope: ["Re-attach a new repo"],
        inserted_at: DateTime.utc_now()
      },
      selected_target: %{
        kind: :promoted_request,
        source_id: "revision-prior-123",
        draft_id: nil,
        run_id: nil,
        spec_id: "spec-prior-123",
        spec_revision_id: "revision-prior-123",
        title: "Continuity request title",
        request_kind: :feature,
        change_summary: "Carry forward from the most recent promoted request.",
        acceptance_criteria: ["Keep prior context", "Start from known repo state"],
        out_of_scope: ["Re-attach a new repo"],
        inserted_at: DateTime.utc_now()
      },
      carry_forward: %{
        source: :promoted_request,
        source_id: "revision-prior-123",
        title: "Continuity request title",
        request_kind: :feature,
        change_summary: "Carry forward from the most recent promoted request.",
        acceptance_criteria: ["Keep prior context", "Start from known repo state"],
        out_of_scope: ["Re-attach a new repo"]
      }
    }
  end

  defp recent_repo_summary(id) do
    %{
      id: id,
      repo_slug: "jon/kiln",
      workspace_path: "/tmp/kiln-workspace",
      base_branch: "main",
      last_activity_at: DateTime.utc_now()
    }
  end
end
