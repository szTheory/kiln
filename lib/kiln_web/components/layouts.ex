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

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-ash bg-char px-4 sm:px-6 lg:px-8">
      <div class="navbar mx-auto max-w-7xl text-bone">
        <div class="flex-1">
          <.link navigate={~p"/"} class="flex w-fit items-center gap-2">
            <img src={~p"/images/logo.svg"} width="36" alt="Kiln" />
            <span class="font-sans text-sm font-semibold tracking-tight">Kiln</span>
          </.link>
        </div>
        <nav class="flex-none" aria-label="Operator">
          <ul class="flex flex-wrap items-center gap-1 px-1 sm:gap-3">
            <li>
              <.link class="btn btn-ghost btn-sm font-sans text-bone" navigate={~p"/workflows"}>
                Workflows
              </.link>
            </li>
            <li>
              <.link class="btn btn-ghost btn-sm font-sans text-bone" navigate={~p"/inbox"}>
                Inbox
              </.link>
            </li>
            <li>
              <.link class="btn btn-ghost btn-sm font-sans text-bone" navigate={~p"/costs"}>
                Costs
              </.link>
            </li>
            <li>
              <.link class="btn btn-ghost btn-sm font-sans text-bone" navigate={~p"/providers"}>
                Providers
              </.link>
            </li>
            <li>
              <.link class="btn btn-ghost btn-sm font-sans text-bone" navigate={~p"/audit"}>
                Audit
              </.link>
            </li>
            <li>
              <.link class="btn btn-ghost btn-sm font-sans text-bone" navigate={~p"/ops/dashboard"}>
                LiveDashboard
              </.link>
            </li>
            <li>
              <.link class="btn btn-ghost btn-sm font-sans text-bone" navigate={~p"/ops/oban"}>
                Oban
              </.link>
            </li>
            <li>
              <.theme_toggle />
            </li>
          </ul>
        </nav>
      </div>
    </header>

    <main class="bg-coal px-4 py-8 font-sans text-bone sm:px-6 lg:px-8">
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
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
