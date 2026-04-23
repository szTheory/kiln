defmodule KilnWeb.Layouts do
  @moduledoc """
  HEEx layouts (root + inner) + shared layout components (`app`,
  `flash_group`, `theme_toggle`) embedded from `layouts/*.html.heex`
  and rendered from every Phoenix view.

  **Fonts (Phase 07):** Inter + IBM Plex Mono load from Google Fonts via
  `@import` in `assets/css/app.css` (CSP-friendly `fonts.googleapis.com` /
  `fonts.gstatic.com` only — no inline script in the font path).
  """
  use KilnWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :factory_summary, :map,
    default: %{active: 0, blocked: 0},
    doc: "UI-07 counts from `factory:summary` (see `KilnWeb.FactorySummaryHook`)"

  attr :operator_runtime_mode, :atom,
    default: :unknown,
    doc: "Phase 999.2 demo vs live label (see `Kiln.OperatorRuntime` / `OperatorChromeHook`)"

  attr :operator_snapshots, :list,
    default: [],
    doc:
      "Phase 999.2 provider snapshot rows (see `Kiln.ModelRegistry.provider_health_snapshots/0`)"

  attr :chrome_mode, :atom,
    default: :full,
    values: [:full, :minimal],
    doc:
      "`:minimal` drops operator mode chip / provider readiness / factory header — for onboarding and other first-run surfaces that shouldn't be crowded by ops telemetry."

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="kiln-operator-header border-b">
      <div class="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-2.5 sm:px-6 lg:px-8">
        <div class="flex min-w-0 flex-1 items-center">
          <.link
            navigate={~p"/"}
            class="flex w-fit items-center gap-2 rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ring-focus)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--surface-header)]"
          >
            <img src={~p"/images/logo.svg"} width="32" alt="Kiln" />
            <span class="kiln-brand-mark font-sans text-sm font-semibold tracking-tight">Kiln</span>
          </.link>
        </div>
        <nav class="flex-none" aria-label="Operator">
          <ul class="flex flex-wrap items-center gap-x-1 gap-y-1 sm:gap-x-2">
            <li>
              <.link class="kiln-nav-link font-sans" navigate={~p"/workflows"}>Workflows</.link>
            </li>
            <li>
              <.link class="kiln-nav-link font-sans" navigate={~p"/inbox"}>Inbox</.link>
            </li>
            <li>
              <.link class="kiln-nav-link font-sans" navigate={~p"/costs"}>Costs</.link>
            </li>
            <li>
              <.link class="kiln-nav-link font-sans" navigate={~p"/providers"}>Providers</.link>
            </li>
            <li>
              <.link class="kiln-nav-link font-sans" navigate={~p"/audit"}>Audit</.link>
            </li>
            <li class="hidden sm:list-item">
              <.link class="kiln-nav-link font-sans" navigate={~p"/ops/dashboard"}>
                LiveDashboard
              </.link>
            </li>
            <li class="hidden sm:list-item">
              <.link class="kiln-nav-link font-sans" navigate={~p"/ops/oban"}>Oban</.link>
            </li>
            <li class="pl-1">
              <.theme_toggle />
            </li>
          </ul>
        </nav>
      </div>

      <%= if @chrome_mode == :full do %>
        <div class="kiln-operator-subheader border-t">
          <div class="mx-auto flex max-w-7xl items-center px-4 py-1.5 sm:px-6 lg:px-8">
            <div class="kiln-status-bar w-full">
              <div class="kiln-status-bar__group">
                <.operator_mode_chip mode={@operator_runtime_mode} />
                <.operator_config_presence snapshots={@operator_snapshots} />
              </div>
              <div class="kiln-status-bar__group">
                <.factory_header summary={@factory_summary} />
              </div>
            </div>
          </div>
          <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <.operator_provider_readiness
              mode={@operator_runtime_mode}
              snapshots={@operator_snapshots}
            />
          </div>
        </div>
      <% end %>
    </header>

    <main class="kiln-operator-main min-h-[calc(100vh-8rem)] px-4 py-8 font-sans sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      id="kiln-theme-toggle"
      class="kiln-theme-toggle"
      role="group"
      aria-label="Color theme"
    >
      <span class="kiln-theme-toggle__knob" aria-hidden="true" />
      <button
        type="button"
        class="kiln-theme-toggle__btn"
        aria-label="Use system theme"
        phx-click={JS.dispatch("phx:set-theme", detail: %{"theme" => "system"})}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>
      <button
        type="button"
        class="kiln-theme-toggle__btn"
        aria-label="Use light theme"
        phx-click={JS.dispatch("phx:set-theme", detail: %{"theme" => "light"})}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>
      <button
        type="button"
        class="kiln-theme-toggle__btn"
        aria-label="Use dark theme"
        phx-click={JS.dispatch("phx:set-theme", detail: %{"theme" => "dark"})}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
