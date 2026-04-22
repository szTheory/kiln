defmodule KilnWeb.Components.OperatorChrome do
  @moduledoc """
  Phase **999.2** — operator shell chrome: demo vs live chip, provider readiness
  strip, and config presence (names only; SEC-01). Copy locked to `999.2-UI-SPEC.md`.
  """

  use Phoenix.Component
  import KilnWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: KilnWeb.Endpoint,
    router: KilnWeb.Router,
    statics: KilnWeb.static_paths()

  attr :mode, :atom, required: true

  def operator_mode_chip(assigns) do
    ~H"""
    <div
      id="operator-mode-chip"
      class={[
        "rounded border px-3 py-2 text-xs leading-snug",
        @mode == :live && "border-ember/80",
        @mode == :demo && "border-ember/50",
        @mode == :unknown && "border-ash"
      ]}
      aria-label={mode_aria_label(@mode)}
    >
      <%= cond do %>
        <% @mode == :live -> %>
          <div class="text-[12px] font-semibold leading-[1.4] text-bone">Live</div>
          <p class="mt-1 max-w-xl text-[16px] font-normal leading-[1.5] text-[var(--color-smoke)]">
            Runtime credentials apply; external APIs may incur cost.
          </p>
        <% @mode == :demo -> %>
          <div class="text-[12px] font-semibold leading-[1.4] text-bone">Demo</div>
          <p class="mt-1 max-w-xl text-[16px] font-normal leading-[1.5] text-[var(--color-smoke)]">
            Outcomes use fixtures and stubs; no paid provider calls.
          </p>
        <% true -> %>
          <div class="text-[12px] font-semibold leading-[1.4] text-bone">
            Runtime mode unavailable
          </div>
          <p class="mt-1 max-w-xl text-[16px] font-normal leading-[1.5] text-[var(--color-smoke)]">
            The shell could not read demo vs live state. Open provider health to verify providers.
          </p>
          <p class="mt-2">
            <.link navigate={~p"/providers"} class="text-sm font-semibold text-ember underline">
              Open provider health
            </.link>
          </p>
      <% end %>
    </div>
    """
  end

  attr :snapshots, :list, default: []

  def operator_config_presence(assigns) do
    ~H"""
    <div id="operator-config-presence" class="text-xs text-bone">
      <div class="text-[12px] font-semibold leading-[1.4]">Providers</div>
      <ul class="mt-1 flex flex-wrap gap-x-3 gap-y-1 text-[16px] font-normal leading-[1.5] text-[var(--color-smoke)]">
        <%= for snap <- @snapshots do %>
          <li>
            {provider_display_name(snap)}:
            <%= if snap[:key_configured?] do %>
              configured
            <% else %>
              not configured
            <% end %>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  attr :mode, :atom, required: true
  attr :snapshots, :list, default: []

  def operator_provider_readiness(assigns) do
    assigns = assign(assigns, :body, readiness_inner(assigns.mode, assigns.snapshots))

    ~H"""
    <div id="operator-provider-readiness" role="status">
      <%= if @body != :empty do %>
        {@body}
      <% end %>
    </div>
    """
  end

  attr :mode, :atom, required: true
  attr :snapshots, :list, default: []

  def operator_chrome(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <.operator_mode_chip mode={@mode} />
      <.operator_provider_readiness mode={@mode} snapshots={@snapshots} />
      <.operator_config_presence snapshots={@snapshots} />
    </div>
    """
  end

  defp readiness_inner(:demo, snapshots) do
    if demo_readiness_problem?(snapshots) do
      readiness_block(
        "Demo provider offline",
        "This state is simulated; switch to live mode for real connectivity."
      )
    else
      :empty
    end
  end

  defp readiness_inner(:live, snapshots) do
    cond do
      Enum.any?(snapshots, &(not &1[:key_configured?])) ->
        readiness_block(
          "Credential not configured",
          "This provider needs a configured secret reference in the runtime environment."
        )

      Enum.any?(snapshots, &rate_degraded?/1) ->
        readiness_block(
          "Provider not reachable",
          "Runs may stall until connectivity returns."
        )

      true ->
        :empty
    end
  end

  defp readiness_inner(:unknown, _), do: :empty

  defp readiness_block(title, body) do
    assigns = %{title: title, body: body}

    ~H"""
    <div class="rounded border border-amber-700/50 bg-char/80 px-3 py-2">
      <div class="flex items-start gap-2">
        <.icon name="hero-signal-slash" class="mt-0.5 size-4 shrink-0 text-amber-200/90" />
        <div>
          <div class="text-[12px] font-semibold leading-[1.4] text-bone">{@title}</div>
          <p class="mt-1 text-[16px] font-normal leading-[1.5] text-[var(--color-smoke)]">{@body}</p>
          <p class="mt-2">
            <.link navigate={~p"/providers"} class="text-sm font-semibold text-ember underline">
              Open provider health
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp demo_readiness_problem?(snapshots) do
    Enum.any?(snapshots, fn s ->
      not s[:key_configured?] or rate_degraded?(s)
    end)
  end

  defp rate_degraded?(s) do
    rate = s[:recent_error_rate] || 0.0
    rate >= 0.5
  end

  defp mode_aria_label(:live), do: "Live mode, external APIs may be used"
  defp mode_aria_label(:demo), do: "Demo mode, fixtures and stubs without paid provider calls"
  defp mode_aria_label(_), do: "Runtime mode unavailable"

  defp provider_display_name(%{id: :anthropic}), do: "Anthropic"
  defp provider_display_name(%{id: :openai}), do: "OpenAI"
  defp provider_display_name(%{id: :google}), do: "Google"
  defp provider_display_name(%{id: :ollama}), do: "Ollama"
  defp provider_display_name(%{id: id}), do: id |> to_string() |> String.capitalize()
end
