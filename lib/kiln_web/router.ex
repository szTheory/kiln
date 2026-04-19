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

    get "/", PageController, :redirect_to_ops
  end

  # Health endpoint (Plug mounted in Endpoint BEFORE Plug.Logger in Plan 06; this is the
  # Phoenix route placeholder — returns a P1 stub until Plan 06 ships Kiln.HealthPlug).
  scope "/", KilnWeb do
    pipe_through :api

    get "/health", HealthController, :show
  end

  # Ops dashboards (D-02)
  scope "/ops" do
    pipe_through :browser

    live_dashboard "/dashboard", metrics: KilnWeb.Telemetry
    oban_dashboard("/oban")
  end
end
