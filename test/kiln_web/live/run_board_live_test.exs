defmodule KilnWeb.RunBoardLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kiln.Factory.Run, as: RunFactory

  describe "GET /" do
    test "renders run board shell and empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#run-board")
      assert render(view) =~ "No runs in flight"
      assert render(view) =~ "Start a run from the workflow registry when you are ready"
    end

    test "renders factory chrome: header, run progress, agent ticker stream", %{conn: conn} do
      _ =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: "wf-chrome"
        )

      {:ok, view, _html} = live(conn, ~p"/")
      html = render(view)

      assert html =~ ~s(id="factory-header")
      assert html =~ ~s(id="agent-ticker")
      assert html =~ "wf-chrome"
      assert html =~ "Stages"

      Phoenix.PubSub.broadcast(
        Kiln.PubSub,
        "agent_ticker",
        {:agent_ticker_line, %{run_id: "x", stage_id: "coding", line: "hello ticker"}}
      )

      assert render(view) =~ "hello ticker"
    end

    test "renders kanban cards and updates on runs:board PubSub", %{conn: conn} do
      run =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: "wf-pubsub-board"
        )

      {:ok, view, _html} = live(conn, ~p"/")
      html = render(view)
      assert html =~ "wf-pubsub-board"
      assert html =~ "data-state=\"coding\""

      updated = %{run | state: :testing, updated_at: DateTime.utc_now(:microsecond)}
      Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board", {:run_state, updated})
      _ = render(view)

      html2 = render(view)
      assert html2 =~ "wf-pubsub-board"
      assert html2 =~ "data-state=\"testing\""
    end
  end
end
