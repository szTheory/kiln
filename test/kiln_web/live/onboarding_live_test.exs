defmodule KilnWeb.OnboardingLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders wizard shell", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/onboarding")
    assert render(view) =~ "Set up Kiln"
    assert has_element?(view, "#onboarding-wizard")
  end
end
