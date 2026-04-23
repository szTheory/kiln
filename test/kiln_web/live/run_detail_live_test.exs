defmodule KilnWeb.RunDetailLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kiln.Artifacts
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.Runs.Transitions

  test "shows run detail shell and select-stage copy without stage param", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_detail_shell")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}")

    assert has_element?(view, "#run-detail")
    assert render(view) =~ "Select a stage"
  end

  test "invalid stage query shows not found", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_detail_bad_stage")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}?stage=bogus")

    assert render(view) =~ "Stage not found"
  end

  test "blocked run shows unblock panel and can resume to planning", %{conn: conn} do
    run = RunFactory.insert(:run, state: :planning, workflow_id: "wf_blocked_lv")
    assert {:ok, _} = Transitions.transition(run.id, :blocked, %{reason: :budget_exceeded})

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}")

    assert has_element?(view, "#unblock-panel")
    assert render(view) =~ "Run blocked"

    view |> element("#unblock-retry-btn") |> render_click()

    assert render(view) =~ "Resumed run at planning"
  end

  test "run detail exposes diagnostics bundle control", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_diag_btn")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}")

    assert has_element?(view, "#bundle-diagnostics-btn")
    assert render(view) =~ "Bundle last 60 minutes"
  end

  test "merged run shows post-mortem panel", %{conn: conn} do
    run = RunFactory.insert(:run, state: :merged, workflow_id: "wf_post_mortem_lv")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}")

    assert has_element?(view, "#post-mortem-panel")
  end

  test "active run shows operator nudge composer", %{conn: conn} do
    run = RunFactory.insert(:run, state: :planning, workflow_id: "wf_nudge_lv")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}")

    assert has_element?(view, "#operator-nudge-form")
  end

  test "merged run shows File as follow-up and creates inbox draft", %{conn: conn} do
    run = RunFactory.insert(:run, state: :merged, workflow_id: "wf_follow_up_lv")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}")

    assert has_element?(view, "#follow-up-btn")
    assert render(view) =~ "File as follow-up"

    view |> element("#follow-up-btn") |> render_click()

    assert render(view) =~ "Draft created"
  end

  test "cost hint panel shows disclaimer chips for succeeded stage", %{conn: conn} do
    run =
      RunFactory.insert(:run,
        workflow_id: "wf_cost_hint",
        caps_snapshot: %{
          "max_retries" => 3,
          "max_tokens_usd" => "10",
          "max_elapsed_seconds" => 600,
          "max_stage_duration_seconds" => 300
        }
      )

    _ =
      StageRunFactory.insert(:stage_run,
        run_id: run.id,
        workflow_stage_id: "stage_cost_hint",
        state: :succeeded,
        cost_usd: "0.12",
        requested_model: "sonnet-class",
        actual_model_used: "haiku-class"
      )

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}?stage=stage_cost_hint")

    html = render(view)
    assert html =~ "Advisory — does not change run caps"
    assert html =~ "Spend follows routed model"
    assert html =~ "Cap headroom"
  end

  test "budget_alert pubsub shows banner until dismissed", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_budget_banner")

    _ =
      StageRunFactory.insert(:stage_run,
        run_id: run.id,
        workflow_stage_id: "stage_bb",
        state: :succeeded
      )

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}?stage=stage_bb")

    Phoenix.PubSub.broadcast(
      Kiln.PubSub,
      "run:#{run.id}",
      {:budget_alert,
       %{
         crossings: [
           %{pct: 50, band: "50", threshold_name: "50% of cap", severity: "info"}
         ]
       }}
    )

    html = render(view)
    assert html =~ "Budget notice: half of run cap reached"
    assert has_element?(view, "#run-detail-budget-banner-dismiss")

    view |> element("#run-detail-budget-banner-dismiss") |> render_click()

    refute render(view) =~ "Budget notice: half of run cap reached"
  end

  test "diff pane shows truncated marker for oversized artifact", %{conn: conn} do
    run =
      RunFactory.insert(:run,
        workflow_id: "wf_detail_diff",
        workflow_checksum: String.duplicate("b", 64)
      )

    sr =
      StageRunFactory.insert(:stage_run,
        run_id: run.id,
        workflow_stage_id: "stage_diff",
        state: :succeeded
      )

    huge = String.duplicate("x", 600_000)

    assert {:ok, _} =
             Artifacts.put(sr.id, "out.diff", [huge],
               content_type: :"text/plain",
               run_id: run.id
             )

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}?stage=stage_diff&pane=diff")

    assert render(view) =~ "[truncated at 512 KiB]"
  end
end
