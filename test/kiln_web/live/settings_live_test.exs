defmodule KilnWeb.SettingsLiveTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.OperatorReadiness.ProbeRow
  alias Kiln.Repo

  test "renders configuration checklist and provider matrix", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    assert has_element?(view, "#settings-root")
    assert has_element?(view, "#settings-summary")
    assert has_element?(view, "#settings-current-journey")
    assert has_element?(view, "#settings-provider-matrix")
    assert has_element?(view, "#settings-item-anthropic")
    assert has_element?(view, "#settings-item-github")
    assert has_element?(view, "#settings-item-docker")
  end

  test "re-verification keeps checklist interactive", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    view
    |> element("#settings-verify-docker")
    |> render_click()

    assert render(view) =~ "Docker"
  end

  test "settings shows a return affordance back to the selected template path", %{conn: conn} do
    {:ok, view, _html} =
      live(
        conn,
        "/settings?return_to=%2Ftemplates%2Fhello-kiln&template_id=hello-kiln#settings-item-anthropic"
      )

    assert has_element?(view, "#settings-return-context")

    assert has_element?(
             view,
             "#settings-return-to-template[href=\"/templates/hello-kiln\"]"
           )
  end

  @tag operator_readiness: :keep
  test "missing readiness state shows blockers and stable remediation controls", %{conn: conn} do
    Repo.delete_all(ProbeRow)

    {:ok, view, _html} = live(conn, ~p"/settings")

    assert has_element?(view, "#settings-summary")
    assert has_element?(view, "#settings-item-anthropic")
    assert has_element?(view, "#settings-item-github")
    assert has_element?(view, "#settings-item-docker")
    assert has_element?(view, "#settings-verify-anthropic")
    assert has_element?(view, "#settings-verify-github")
    assert has_element?(view, "#settings-verify-docker")
    assert render(view) =~ "Live mode still has a few missing pieces"
  end
end
