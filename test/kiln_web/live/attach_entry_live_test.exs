defmodule KilnWeb.AttachEntryLiveTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "mounts the attach orientation surface with stable ids", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/attach")

    assert has_element?(view, "#attach-entry-root")
    assert has_element?(view, "#attach-entry-hero")
    assert has_element?(view, "#attach-supported-sources")
    assert has_element?(view, "#attach-next-step")
    assert has_element?(view, "#attach-back-to-templates")
  end

  test "explains sources and next-step scope without template or git actions", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/attach")

    assert render(view) =~ "Attach existing repo"
    assert render(view) =~ "local path"
    assert render(view) =~ "existing clone"
    assert render(view) =~ "GitHub URL"
    assert render(view) =~ "Validation and workspace safety checks happen in the next step."

    refute html =~ "template_id"
    refute html =~ "return_to"
    refute html =~ "Use template"
    refute html =~ "Start run"
    refute html =~ "Create draft PR"
  end
end
