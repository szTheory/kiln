defmodule KilnWeb.TemplatesLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "catalog lists at least three template cards", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/templates")

    assert has_element?(view, "#template-card-hello-kiln")
    assert has_element?(view, "#template-card-gameboy-vertical-slice")
    assert has_element?(view, "#template-card-markdown-spec-stub")
  end

  test "unknown template_id redirects to catalog", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
             live(conn, ~p"/templates/not-a-real-template")

    assert to == ~p"/templates"
    assert flash["error"] =~ "This template is not available."
  end

  test "use template shows start run control", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/templates/hello-kiln")

    view
    |> form("#template-use-form-hello-kiln")
    |> render_submit()

    html = render(view)
    assert html =~ "Spec promoted"
    assert has_element?(view, "#templates-start-run")
  end

  test "start run navigates to run detail", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/templates/hello-kiln")

    view
    |> form("#template-use-form-hello-kiln")
    |> render_submit()

    assert has_element?(view, "#templates-start-run")

    result =
      view
      |> form("#templates-start-run-form")
      |> render_submit()

    assert {:error, {:live_redirect, %{to: to}}} = result
    assert to =~ "/runs/"
  end
end
