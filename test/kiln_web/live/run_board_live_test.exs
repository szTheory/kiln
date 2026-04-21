defmodule KilnWeb.RunBoardLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "GET /" do
    test "renders run board shell and empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#run-board")
      assert render(view) =~ "No runs in flight"
      assert render(view) =~ "Start a run from the workflow registry when you are ready"
    end
  end
end
