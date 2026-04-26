defmodule KilnWeb.DogfoodTemplateTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.Specs
  alias Kiln.Templates

  test "edit-inbox-first for dogfood template fills draft body from template spec", %{conn: conn} do
    template_id = "gameboy-vertical-slice"
    {:ok, entry} = Templates.fetch(template_id)

    {:ok, view, _html} = live(conn, ~p"/templates/#{template_id}")

    _ =
      form(view, "#template-edit-first-form-#{template_id}", %{"template_id" => template_id})
      |> render_submit()

    draft =
      Specs.list_open_drafts()
      |> Enum.find(&(&1.title == entry.title))

    assert draft

    {:ok, inbox, _html} = live(conn, ~p"/inbox?edit=#{draft.id}")
    form_html = element(inbox, "#inbox-edit-form") |> render()

    assert form_html =~ "rust_gb_dogfood_v1"
    assert form_html =~ "compile_gate"
  end
end
