defmodule KilnWeb.CostLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory

  test "empty spend shows operator copy", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/costs")
    html = render(view)
    assert html =~ "No spend recorded yet"
    assert html =~ "Last updated"
  end

  test "intel tab shows advisory when spend exists in window", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_cost_intel")

    _sr =
      StageRunFactory.insert(:stage_run,
        run_id: run.id,
        cost_usd: Decimal.new("4.25"),
        actual_model_used: "claude-sonnet",
        inserted_at: DateTime.utc_now(:microsecond)
      )

    {:ok, view, _html} = live(conn, ~p"/costs?tab=intel&period=day&pivot=provider")
    html = render(view)

    assert html =~ ~r/You(?:'|&#39;)re spending/
    assert html =~ "Intel"
  end

  test "intel tab shows empty advisory copy without spend", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/costs?tab=intel")
    html = render(view)
    assert html =~ "Not enough history for an advisory yet"
  end
end
