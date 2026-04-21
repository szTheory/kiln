defmodule KilnWeb.PageControllerTest do
  use KilnWeb.ConnCase

  test "GET / serves RunBoardLive (Phase 07)", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "run-board"
  end
end
