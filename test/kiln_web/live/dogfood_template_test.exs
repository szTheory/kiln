defmodule KilnWeb.DogfoodTemplateTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.Specs

  test "load dogfood template fills draft body from priv/dogfood/spec.md", %{conn: conn} do
    {:ok, draft} =
      Specs.create_draft(%{
        title: "scratch",
        body: "placeholder-body",
        source: :freeform
      })

    {:ok, view, _html} = live(conn, ~p"/inbox?edit=#{draft.id}")

    assert has_element?(view, "#inbox-load-dogfood-template")

    _ = element(view, "#inbox-load-dogfood-template") |> render_click()

    form_html = element(view, "#inbox-edit-form") |> render()
    assert form_html =~ "Kiln.Version"
    assert form_html =~ "mix check"
    refute form_html =~ "placeholder-body"
  end
end
