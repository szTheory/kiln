defmodule KilnWeb.Components.FactoryHeaderTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  test "renders counts from summary assign" do
    html =
      render_component(&KilnWeb.Components.FactoryHeader.factory_header/1, %{
        summary: %{active: 3, blocked: 1}
      })

    assert html =~ ~s(id="factory-header")
    assert html =~ "Active"
    assert html =~ "Blocked"
    assert html =~ "3"
    assert html =~ "1"
  end
end
