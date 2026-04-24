defmodule KilnWeb.TemplatesLiveTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kiln.OperatorReadiness
  alias Kiln.Secrets

  setup do
    prior = Application.get_env(:kiln, :operator_runtime_mode)

    on_exit(fn ->
      if prior == nil do
        Application.delete_env(:kiln, :operator_runtime_mode)
      else
        Application.put_env(:kiln, :operator_runtime_mode, prior, persistent: false)
      end
    end)

    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, true)
    :ok = Secrets.put(:anthropic_api_key, "test-key")

    on_exit(fn ->
      :ok = Secrets.put(:anthropic_api_key, nil)
    end)

    :ok
  end

  test "catalog lists at least three template cards", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/templates")

    assert has_element?(view, "#templates-first-run-hero")
    assert has_element?(view, "#templates-first-run-hero #template-card-hello-kiln")
    assert has_element?(view, "#template-card-hello-kiln")
    assert has_element?(view, "#template-card-gameboy-vertical-slice")
    assert has_element?(view, "#template-card-markdown-spec-stub")
  end

  test "scenario guidance stays secondary to the hello-kiln first-run hero", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/templates?scenario=gameboy-first-project")

    assert has_element?(view, "#templates-scenario-banner")
    assert has_element?(view, "#templates-first-run-hero")
    refute has_element?(view, "#templates-scenario-banner", "Recommended template:")
    assert has_element?(view, "#template-role-gameboy-vertical-slice")
    assert has_element?(view, "#template-role-markdown-spec-stub")
  end

  test "unknown template_id redirects to catalog", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
             live(conn, ~p"/templates/not-a-real-template")

    assert to == ~p"/templates"
    assert flash["error"] =~ "This template is not available."
  end

  test "use template shows start run control", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/templates/hello-kiln")

    assert has_element?(view, "#template-detail-next-steps")
    refute has_element?(view, "#template-scenario-recommendation")

    view
    |> form("#template-use-form-hello-kiln")
    |> render_submit()

    assert has_element?(view, "#templates-success-panel")
    assert has_element?(view, "#templates-start-run")
    assert has_element?(view, "#templates-watch-hint")
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

    {:ok, run_view, _html} = follow_redirect(result, conn)

    assert has_element?(run_view, "#run-detail")
  end

  test "blocked start routes to the first missing settings anchor with template return context",
       %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :live, persistent: false)

    {:ok, view, _html} = live(conn, ~p"/templates/hello-kiln")

    view
    |> form("#template-use-form-hello-kiln")
    |> render_submit()

    assert has_element?(view, "#templates-start-run-form")

    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, false)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, false)

    result =
      view
      |> form("#templates-start-run-form")
      |> render_submit()

    assert {:error, {:live_redirect, %{to: to}}} = result

    assert to ==
             "/settings?return_to=%2Ftemplates%2Fhello-kiln%3Fscenario%3Dsolo-founder-fast-proof&template_id=hello-kiln#settings-item-anthropic"

    {:ok, settings_view, _html} = follow_redirect(result, conn)

    assert has_element?(settings_view, "#settings-return-context")
    assert has_element?(settings_view, "#settings-return-to-template")
  end

  test "live mode with missing setup shows disconnected state", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :live, persistent: false)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, false)

    {:ok, view, _html} = live(conn, ~p"/templates/hello-kiln")

    assert has_element?(view, "#templates-live-hero")
    assert has_element?(view, "#template-live-disconnected-state")
    assert render(view) =~ "route you to the exact settings step"
  end

  test "live guidance remains visible without disabling the real start-run path", %{conn: conn} do
    Application.put_env(:kiln, :operator_runtime_mode, :live, persistent: false)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, false)

    {:ok, view, _html} = live(conn, ~p"/templates/hello-kiln")

    assert has_element?(view, "#template-live-disconnected-state")
    assert has_element?(view, "#template-use-form-hello-kiln button:not([disabled])")
    refute has_element?(view, "#settings-item-anthropic")

    view
    |> form("#template-use-form-hello-kiln")
    |> render_submit()

    assert has_element?(view, "#templates-start-run-form")
    assert has_element?(view, "#templates-start-run:not([disabled])")
  end
end
