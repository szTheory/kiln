defmodule KilnWeb.Router do
  use KilnWeb, :router
  import Phoenix.LiveDashboard.Router
  import Oban.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KilnWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug KilnWeb.Plugs.Scope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KilnWeb do
    pipe_through :browser

    live_session :default, on_mount: [{KilnWeb.LiveScope, :default}] do
      get "/", PageController, :redirect_to_ops
      live "/specs/:id/edit", SpecEditorLive, :edit
    end
  end

  # NOTE (Plan 06 / D-31): `/health` is handled by `Kiln.HealthPlug`,
  # mounted at the Endpoint level BEFORE `Plug.Logger`. The probe
  # short-circuits before the Router pipeline runs — do NOT add a
  # `/health` route here (it would be dead code shadowed by the plug).

  # Ops dashboards (D-02)
  scope "/ops" do
    pipe_through :browser

    live_dashboard "/dashboard", metrics: KilnWeb.Telemetry
    oban_dashboard("/oban")
  end
end
