defmodule KilnWeb.Router do
  use KilnWeb, :router

  import KilnWeb.UserAuth
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
    plug KilnWeb.Plugs.OnboardingGate
    plug :fetch_current_scope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KilnWeb do
    pipe_through [:browser, :require_authenticated]

    get "/runs/:run_id/diagnostics/bundle.zip", DiagnosticsZipController, :bundle

    live_session :authenticated,
      on_mount: [
        {KilnWeb.UserAuth, :ensure_authenticated},
        {KilnWeb.FactorySummaryHook, :default},
        {KilnWeb.OperatorChromeHook, :default}
      ] do
      live "/onboarding", OnboardingLive, :index
      live "/", RunBoardLive, :index
      live "/attach", AttachEntryLive, :index
      live "/templates", TemplatesLive, :index
      live "/templates/:template_id", TemplatesLive, :show
      live "/inbox", InboxLive, :index
      live "/runs/compare", RunCompareLive, :index
      live "/runs/:run_id/replay", RunReplayLive, :show
      live "/runs/:run_id", RunDetailLive, :show
      live "/workflows", WorkflowLive, :index
      live "/workflows/:workflow_id", WorkflowLive, :show
      live "/costs", CostLive, :index
      live "/providers", ProviderHealthLive, :index
      live "/settings", SettingsLive, :index
      live "/audit", AuditLive, :index
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

  # Sigra authentication

  pipeline :require_authenticated do
    plug :require_authenticated_user
    plug :require_mfa
  end

  pipeline :require_sudo do
    plug Sigra.Plug.RequireSudo, error_handler: KilnWeb.AuthErrorHandler
  end

  # Phase 14 Plan 03: organization-aware pipelines (opt-in).
  # Apps that want to gate routes by active organization membership
  # pipe_through :require_org (any active membership) or
  # :require_org_owner (owner role only). Phase 16 wires these to
  # the organization picker + switcher.
  pipeline :require_org do
    plug Sigra.Plug.RequireMembership, error_handler: KilnWeb.AuthErrorHandler
  end

  pipeline :require_org_owner do
    plug Sigra.Plug.RequireMembership,
      error_handler: KilnWeb.AuthErrorHandler,
      roles: [:owner]
  end

  # MFA challenge (accessible with mfa_pending sessions, D-24)
  scope "/users", KilnWeb do
    pipe_through [:browser]

    get "/mfa", MFAChallengeController, :new
    post "/mfa", MFAChallengeController, :create

  end

  scope "/users", KilnWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    # Phase 10.1.1 B9: login page is a plain controller, not a LiveView.
    get "/log_in", SessionController, :new

    get "/register", RegistrationController, :new
    post "/register", RegistrationController, :create

    post "/log_in", SessionController, :create
    get "/log_in/:token", SessionController, :magic_link

    get "/confirm", ConfirmationController, :new
    post "/confirm", ConfirmationController, :create
    get "/confirm/:token", ConfirmationController, :confirm
    post "/confirm/resend", ConfirmationController, :resend


    get "/reset-password", ResetPasswordController, :new
    post "/reset-password", ResetPasswordController, :create
    get "/reset-password/:token", ResetPasswordController, :edit
    put "/reset-password/:token", ResetPasswordController, :update

  end

  scope "/users", KilnWeb do
    pipe_through [:browser, :require_authenticated]

    delete "/log_out", SessionController, :delete

      get "/sudo", Auth.SudoController, :new
      post "/sudo", Auth.SudoController, :create

    # 36-01 followup stubs — see lib/kiln_web/controllers/sigra_stub_controllers.ex.
    # Routes the Sigra-backed scaffolding emits redirects/links to but were
    # never wired. Stubs return 501; replacement tracked as a 36-01 followup.
    get "/settings", SettingsController, :show
    get "/settings/mfa", MFASettingsController, :show
    get "/settings/mfa/enroll", MFASettingsController, :enroll
    post "/settings/mfa/disable", MFASettingsController, :disable
    post "/settings/mfa/confirm", MFASettingsController, :confirm
    post "/settings/mfa/complete", MFASettingsController, :complete
    post "/settings/mfa/regenerate", MFASettingsController, :regenerate
    post "/settings/mfa/revoke-trust", MFASettingsController, :revoke_trust
    get "/reactivation", ReactivationController, :new
  end

  scope "/users", KilnWeb do
    pipe_through [:browser, :require_authenticated, :require_sudo]

  end


# Sigra passkeys
scope "/users", KilnWeb do
  pipe_through [:browser]

  post "/mfa/passkey", SessionController, :complete_mfa_passkey
  post "/mfa/passkey/options", SessionController, :passkey_mfa_options
end

scope "/users", KilnWeb do
  pipe_through [:browser, :redirect_if_user_is_authenticated]

  post "/log_in/passkey", SessionController, :complete_passkey
  post "/log_in/passkey/options", SessionController, :passkey_authentication_options
end

scope "/users", KilnWeb do
  pipe_through [:browser, :require_authenticated, :require_sudo]

  post "/settings/mfa/passkeys/options", SessionController, :passkey_registration_options
  post "/settings/mfa/passkeys", SessionController, :complete_passkey_registration
  post "/settings/mfa/passkeys/:id/delete", SessionController, :delete_passkey
end

end
