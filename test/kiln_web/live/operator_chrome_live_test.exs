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

  test "mode control renders and updates runtime mode copy", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :demo, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#operator-mode-form")
    assert has_element?(view, "#operator-mode-select")

    view
    |> form("#operator-mode-form", %{"runtime_mode" => %{"operator_mode" => "live"}})
    |> render_change()

    assert render(view) =~ "Runtime credentials apply; external APIs may incur cost."
  end

  test "scenario control renders and updates journey copy", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :demo, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#operator-scenario-form")
    assert has_element?(view, "#operator-scenario-select")
    assert render(view) =~ "Solo founder fast proof"

    view
    |> form("#operator-scenario-form", %{"journey" => %{"scenario_id" => "gameboy-first-project"}})
    |> render_change()

    html = render(view)
    assert html =~ "Game Boy first project"
    assert html =~ "Game Boy vertical slice"
  end

  test "live mode shows Live copy on run board", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :live, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")
    html = render(view)

    assert html =~ ~s(id="operator-mode-chip")
    assert html =~ "Runtime credentials apply; external APIs may incur cost."
  end

  test "config presence strip lists Providers", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :demo, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")
    html = render(view)

    assert html =~ ~s(id="operator-config-presence")
    assert html =~ "Providers"
    assert html =~ "Runtime mode"
  end

  test "rendered shell does not echo obvious secret-shaped markers", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :demo, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/")
    html = render(view)

    refute html =~ "sk-"
    refute html =~ "OPENAI_API_KEY"
  end
end
