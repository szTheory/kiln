defmodule KilnWeb.OperatorChromeLiveTest do
  @moduledoc false
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    prior = Application.get_env(:kiln, :operator_runtime_mode)

    on_exit(fn ->
      if prior == nil do
        Application.delete_env(:kiln, :operator_runtime_mode)
      else
        Application.put_env(:kiln, :operator_runtime_mode, prior, persistent: false)
      end
    end)

    {:ok, prior_mode: prior}
  end

  test "demo mode shows operator mode chip and Demo copy", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :demo, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")
    html = render(view)

    assert html =~ ~s(id="operator-mode-chip")
    assert html =~ "Demo"
  end

  test "live mode shows Live copy on run board", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :live, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")
    html = render(view)

    assert html =~ "Live"
  end

  test "config presence strip lists Providers", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :demo, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")
    html = render(view)

    assert html =~ ~s(id="operator-config-presence")
    assert html =~ "Providers"
  end

  test "rendered shell does not echo obvious secret-shaped markers", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :demo, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")
    html = render(view)

    refute html =~ "sk-"
    refute html =~ "OPENAI_API_KEY"
  end
end
