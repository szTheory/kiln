defmodule KilnWeb.RunDetailLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kiln.Artifacts
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory

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

  test "run detail exposes diagnostics bundle control", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_diag_btn")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}")

    assert has_element?(view, "#bundle-diagnostics-btn")
    assert render(view) =~ "Bundle last 60 minutes"
  end

  test "merged run shows File as follow-up and creates inbox draft", %{conn: conn} do
    run = RunFactory.insert(:run, state: :merged, workflow_id: "wf_follow_up_lv")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}")

    assert has_element?(view, "#follow-up-btn")
    assert render(view) =~ "File as follow-up"

    view |> element("#follow-up-btn") |> render_click()

    assert render(view) =~ "Draft created"
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
