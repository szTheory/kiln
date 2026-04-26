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
    <span
      id="operator-mode-chip"
      class={[
        "kiln-chip",
        @mode == :live && "kiln-chip--live",
        @mode == :demo && "kiln-chip--demo",
        @mode == :unknown && "kiln-chip--warn"
      ]}
      aria-label={mode_aria_label(@mode)}
      title={mode_tooltip(@mode)}
    >
      <span class="kiln-chip__dot" aria-hidden="true" />
      {mode_label(@mode)}
    </span>
    """
  end

  attr :mode, :atom, required: true

  def operator_mode_control(assigns) do
    mode_value =
      case assigns.mode do
        :live -> "live"
        _ -> "demo"
      end

    assigns =
      assigns
      |> assign(:mode_value, mode_value)
      |> assign(
        :mode_form,
        Phoenix.Component.to_form(%{"operator_mode" => mode_value}, as: :runtime_mode)
      )

    ~H"""
    <.form
      for={@mode_form}
      id="operator-mode-form"
      phx-change="operator:set_mode_form"
      phx-hook="OperatorModeControl"
      data-current-mode={@mode_value}
      class="min-w-[12rem]"
    >
      <label for="operator-mode-select" class="kiln-status-numeric__label mb-1 block">
        Runtime mode
      </label>
      <select
        id="operator-mode-select"
        name={@mode_form[:operator_mode].name}
        class="select select-bordered h-10 w-full border-base-300 bg-base-100 text-sm"
      >
        <option value="demo" selected={@mode_value == "demo"}>Demo</option>
        <option value="live" selected={@mode_value == "live"}>Live</option>
      </select>
    </.form>
    """
  end

  attr :scenario, :map, default: nil
  attr :scenarios, :list, default: []

  def operator_scenario_control(%{scenario: nil} = assigns) do
    ~H""
  end

  def operator_scenario_control(%{scenarios: []} = assigns) do
    ~H""
  end

  def operator_scenario_control(assigns) do
    assigns =
      assigns
      |> assign(
        :scenario_form,
        Phoenix.Component.to_form(%{"scenario_id" => assigns.scenario.id}, as: :journey)
      )

    ~H"""
    <.form
      for={@scenario_form}
      id="operator-scenario-form"
      phx-change="operator:set_scenario_form"
      phx-hook="OperatorScenarioControl"
      data-current-scenario={@scenario.id}
      class="min-w-[15rem]"
    >
      <label for="operator-scenario-select" class="kiln-status-numeric__label mb-1 block">
        Demo journey
      </label>
      <select
        id="operator-scenario-select"
        name={@scenario_form[:scenario_id].name}
        class="select select-bordered h-10 w-full border-base-300 bg-base-100 text-sm"
      >
        <option
          :for={scenario <- @scenarios}
          value={scenario.id}
          selected={scenario.id == @scenario.id}
        >
          {scenario.title}
        </option>
      </select>
    </.form>
    """
  end

  attr :snapshots, :list, default: []

  def operator_config_presence(assigns) do
    configured = Enum.count(assigns.snapshots, &(&1[:key_configured?] == true))
    total = length(assigns.snapshots)

    assigns =
      assigns
      |> assign(:configured, configured)
      |> assign(:total, total)

    ~H"""
    <details
      id="operator-config-presence"
      class="kiln-status-numeric inline-flex items-center"
    >
      <summary class="inline-flex cursor-pointer list-none items-center gap-1 outline-none">
        <span class="kiln-status-numeric__label">Providers</span>
        <span class="tabular-nums">{@configured}/{@total}</span>
        <span class="kiln-status-numeric__label ml-1">configured</span>
      </summary>
      <ul class="kiln-meta mt-1.5 flex flex-wrap gap-x-3 gap-y-0.5 pl-2">
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
    </details>
    """
  end

  attr :mode, :atom, required: true
  attr :snapshots, :list, default: []

  def operator_provider_readiness(assigns) do
    assigns = assign(assigns, :body, readiness_inner(assigns.mode, assigns.snapshots))

    ~H"""
    <div id="operator-provider-readiness" role="status" class="mt-1.5">
      <%= if @body != :empty do %>
        {@body}
      <% end %>
    </div>
    """
  end

  attr :mode, :atom, required: true
  attr :scenario, :map, default: nil
  attr :scenarios, :list, default: []
  attr :snapshots, :list, default: []

  def operator_chrome(assigns) do
    ~H"""
    <div class="kiln-status-bar">
      <div class="kiln-status-bar__group">
        <.operator_mode_control mode={@mode} />
        <.operator_scenario_control scenario={@scenario} scenarios={@scenarios} />
        <.operator_mode_chip mode={@mode} />
        <.operator_config_presence snapshots={@snapshots} />
      </div>
      <.operator_provider_readiness mode={@mode} snapshots={@snapshots} />
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
    <div class="kiln-readiness-banner">
      <.icon name="hero-signal-slash" class="mt-0.5 size-4 shrink-0" />
      <div class="flex-1">
        <div class="kiln-readiness-banner__title">{@title}</div>
        <p class="kiln-readiness-banner__body">{@body}</p>
        <p class="mt-1.5">
          <.link navigate={~p"/providers"} class="link link-primary text-[13px]">
            Open provider health
          </.link>
        </p>
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

  defp mode_label(:live), do: "Live"
  defp mode_label(:demo), do: "Demo"
  defp mode_label(_), do: "Runtime unavailable"

  defp mode_tooltip(:live),
    do: "Runtime credentials apply; external APIs may incur cost."

  defp mode_tooltip(:demo),
    do: "Outcomes use fixtures and stubs; no paid provider calls."

  defp mode_tooltip(_),
    do: "The shell could not read demo vs live state."

  defp provider_display_name(%{id: :anthropic}), do: "Anthropic"
  defp provider_display_name(%{id: :openai}), do: "OpenAI"
  defp provider_display_name(%{id: :google}), do: "Google"
  defp provider_display_name(%{id: :ollama}), do: "Ollama"
  defp provider_display_name(%{id: id}), do: id |> to_string() |> String.capitalize()
end
