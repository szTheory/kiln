defmodule KilnWeb.AuditLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders filter form and empty filters message", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/audit?run_id=00000000-0000-0000-0000-000000000001")

    assert has_element?(view, "#audit-filter-form")
    assert render(view) =~ "No events match these filters"
  end
end
