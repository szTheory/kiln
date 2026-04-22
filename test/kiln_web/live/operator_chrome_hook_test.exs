defmodule KilnWeb.OperatorChromeHookTest do
  @moduledoc false
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.ModelRegistry

  test "RunBoardLive mount applies hook; tick message does not crash", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Kiln"

    send(view.pid, :operator_chrome_tick)
    _ = render(view)

    assert length(ModelRegistry.provider_health_snapshots()) == 4
  end
end
