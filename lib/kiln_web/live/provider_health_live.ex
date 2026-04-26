defmodule KilnWeb.ProviderHealthLive do
  @moduledoc """
  OPS-01 — per-provider health cards at `/providers` (poll refresh, no PubSub).
  """

  use KilnWeb, :live_view

  alias Kiln.ModelRegistry
  alias Kiln.OperatorSetup

  @default_poll_ms 5_000

  @impl true
  def mount(_params, _session, socket) do
    poll_ms = @default_poll_ms

    socket =
      socket
      |> assign(:page_title, "Providers")
      |> assign(:poll_ms, poll_ms)
      |> assign(:setup_summary, OperatorSetup.summary())
      |> assign(:snapshots, ModelRegistry.provider_health_snapshots())

    if connected?(socket) do
      Process.send_after(self(), :tick, poll_ms)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:setup_summary, OperatorSetup.summary())
     |> assign(:snapshots, ModelRegistry.provider_health_snapshots())}
  end

  @impl true
  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, socket.assigns.poll_ms)

    {:noreply,
     socket
     |> assign(:setup_summary, OperatorSetup.summary())
     |> assign(:snapshots, ModelRegistry.provider_health_snapshots())}
  end

  @impl true
  def handle_info({:factory_summary, summary}, socket) do
    {:noreply, assign(socket, :factory_summary, summary)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      factory_summary={@factory_summary}
      operator_runtime_mode={@operator_runtime_mode}
      operator_snapshots={@operator_snapshots}
      operator_demo_scenario={@operator_demo_scenario}
      operator_demo_scenarios={@operator_demo_scenarios}
    >
      <div id="provider-health" class="space-y-6">
        <div class="border-b border-base-300 pb-4">
          <p class="kiln-eyebrow">Operations</p>
          <h1 class="kiln-h1 mt-1">Providers</h1>
          <p class="kiln-meta mt-1">
            API presence and recent outcomes (poll every {@poll_ms |> div(1000)}s). Keys are never shown.
          </p>
        </div>

        <section
          id="provider-health-journey"
          class="rounded-xl border border-base-300 bg-base-200 p-5"
        >
          <p class="kiln-eyebrow">Current journey</p>
          <h2 class="kiln-h2 mt-2">{@operator_demo_scenario.title}</h2>
          <p class="kiln-body mt-2 text-sm">
            {journey_copy(@operator_demo_scenario)}
          </p>
        </section>

        <%= if @operator_runtime_mode == :live and not @setup_summary.ready? do %>
          <section
            id="provider-health-live-hero"
            class="rounded-xl border border-warning/60 bg-warning/10 p-5"
          >
            <p class="kiln-eyebrow">Disconnected live state</p>
            <h2 class="kiln-h2 mt-2">
              Provider health is visible, but live readiness is still incomplete
            </h2>
            <p class="kiln-body mt-2 text-sm">
              This page can show provider presence and recent outcomes, but the rest of the live flow will keep pointing back to settings until the local essentials are ready.
            </p>
            <div class="mt-4 flex flex-wrap gap-3 text-sm">
              <.link navigate={~p"/settings"} class="btn btn-primary btn-sm">
                Open settings checklist
              </.link>
              <.link navigate={~p"/onboarding"} class="link link-primary">
                Return to onboarding
              </.link>
            </div>
          </section>
        <% end %>

        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <%= for snap <- @snapshots do %>
            <.provider_card snapshot={snap} />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :snapshot, :map, required: true

  def provider_card(assigns) do
    snap = assigns.snapshot
    rag = rag_classes(snap)
    status = status_label(snap)

    assigns = assign(assigns, :rag, rag)
    assigns = assign(assigns, :status, status)
    assigns = assign(assigns, :snap, snap)

    ~H"""
    <section class={[
      "card card-bordered bg-base-200 border-2",
      @rag
    ]}>
      <div class="card-body p-5">
        <div class="flex items-start justify-between gap-3">
          <h2 class="kiln-h2 capitalize">{to_string(@snap.id)}</h2>
          <span class={["badge", status_badge_class(@snap)]}>{@status}</span>
        </div>
        <dl class="mt-4 grid gap-2 text-xs">
          <div class="flex justify-between gap-2">
            <dt class="text-base-content/60">Spend today (USD)</dt>
            <dd class="font-mono tabular-nums text-base-content">
              {format_usd(@snap.spend_usd_today)}
            </dd>
          </div>
          <div class="flex justify-between gap-2">
            <dt class="text-base-content/60">Recent error rate</dt>
            <dd class="font-mono tabular-nums text-base-content">
              {format_rate(@snap.recent_error_rate)}
            </dd>
          </div>
          <div class="flex justify-between gap-2">
            <dt class="text-base-content/60">Last success</dt>
            <dd class="font-mono tabular-nums text-base-content">{format_dt(@snap.last_ok_at)}</dd>
          </div>
          <div class="flex justify-between gap-2">
            <dt class="text-base-content/60">Rate-limit headroom</dt>
            <dd class="font-mono tabular-nums text-base-content">
              {format_optional_int(@snap.rate_limit_remaining)}
            </dd>
          </div>
          <div class="flex justify-between gap-2">
            <dt class="text-base-content/60">Token budget (today)</dt>
            <dd class="font-mono tabular-nums text-base-content">
              {format_budget(@snap.token_budget_remaining_today)}
            </dd>
          </div>
        </dl>
      </div>
    </section>
    """
  end

  defp rag_classes(snap) do
    cond do
      snap.recent_error_rate >= 0.5 -> "border-error"
      !snap.key_configured? -> "border-warning"
      true -> "border-success"
    end
  end

  defp status_badge_class(snap) do
    cond do
      snap.recent_error_rate >= 0.5 -> "badge-error"
      !snap.key_configured? -> "badge-warning"
      true -> "badge-success"
    end
  end

  defp status_label(%{recent_error_rate: r}) when r >= 0.5, do: "Degraded"
  defp status_label(%{key_configured?: false}), do: "API key missing"
  defp status_label(_), do: "Operational"

  defp format_usd(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp format_usd(_), do: "0"

  defp format_rate(r) when is_float(r), do: :erlang.float_to_binary(r, decimals: 2)
  defp format_rate(_), do: "0.00"

  defp format_dt(nil), do: "—"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  defp format_optional_int(nil), do: "—"
  defp format_optional_int(n) when is_integer(n), do: Integer.to_string(n)

  defp format_budget(nil), do: "—"
  defp format_budget(%Decimal{} = d), do: Decimal.to_string(d, :normal)

  defp journey_copy(%{id: "operator-triage-readiness"}) do
    "Use this page to confirm that provider presence, missing configuration, and degraded-state cues match the readiness story elsewhere in the shell."
  end

  defp journey_copy(%{id: "gameboy-first-project"}) do
    "This page should make it obvious whether the Game Boy path is still demo-safe only or genuinely ready for live external work."
  end

  defp journey_copy(_) do
    "This page should reassure a first-time operator that demo exploration is cheap while live readiness remains transparent and honest."
  end
end
