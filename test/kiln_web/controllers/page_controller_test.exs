defmodule KilnWeb.PageControllerTest do
  use KilnWeb.ConnCase

  test "GET / redirects to /ops/dashboard (D-04)", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/ops/dashboard"
  end
end
