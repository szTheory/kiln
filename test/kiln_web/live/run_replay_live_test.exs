defmodule KilnWeb.RunReplayLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kiln.Factory.Run, as: RunFactory

  test "invalid run id in path redirects home", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, "/runs/not-a-uuid/replay")
  end

  test "happy path renders #run-replay and data-run-id", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_replay_lv")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}/replay")

    assert has_element?(view, "#run-replay")
    assert has_element?(view, "[data-run-id]")
    html = render(view)
    doc = LazyHTML.from_fragment(html)
    assert match?(%LazyHTML{}, LazyHTML.query(doc, "#run-replay"))
  end

  test "empty audit spine shows copy", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_replay_empty")

    {:ok, view, _html} = live(conn, ~p"/runs/#{run.id}/replay")

    assert render(view) =~ "No audit events for this run yet."
  end
end
