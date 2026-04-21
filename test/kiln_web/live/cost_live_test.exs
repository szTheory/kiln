defmodule KilnWeb.CostLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "empty spend shows operator copy", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/costs")
    html = render(view)
    assert html =~ "No spend recorded yet"
    assert html =~ "Last updated"
  end
end
