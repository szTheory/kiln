defmodule KilnWeb.OnboardingLiveTest do
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

    :ok
  end

  test "renders wizard shell", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/onboarding")
    assert render(view) =~ "Set up Kiln"
    assert has_element?(view, "#onboarding-wizard")
    assert has_element?(view, "#onboarding-next-path")
    assert has_element?(view, "#onboarding-scenarios")
    assert has_element?(view, "#onboarding-scenario-detail")
    assert has_element?(view, "#onboarding-start-from-template")
    assert has_element?(view, "#onboarding-continue-runs")
    assert render(view) =~ "Explore without paying for providers first"
  end

  test "scenario selection updates the detail panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/onboarding")

    view
    |> element("#scenario-card-gameboy-first-project")
    |> render_click()

    assert render(view) =~ "Game Boy first project"
    assert render(view) =~ "dogfood constraints"
  end

  test "live mode with missing setup shows the disconnected hero", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :live, persistent: false)

    {:ok, _} = Kiln.OperatorReadiness.mark_step(:docker, false)

    {:ok, view, _html} = live(conn, ~p"/onboarding")

    assert has_element?(view, "#onboarding-live-hero")
    assert render(view) =~ "Open settings checklist"
  end
end
