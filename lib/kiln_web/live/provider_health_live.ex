defmodule KilnWeb.ProviderHealthLive do
  @moduledoc """
  OPS-01 — per-provider health cards at `/providers` (poll refresh, no PubSub).
  """

  use KilnWeb, :live_view

  alias Kiln.ModelRegistry

  @default_poll_ms 5_000

  @impl true
  def mount(_params, _session, socket) do
    poll_ms = @default_poll_ms

    socket =
      socket
      |> assign(:page_title, "Providers")
      |> assign(:poll_ms, poll_ms)
      |> assign(:snapshots, ModelRegistry.provider_health_snapshots())

    if connected?(socket) do
      Process.send_after(self(), :tick, poll_ms)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    _ = allow?(socket)
    {:noreply, assign(socket, :snapshots, ModelRegistry.provider_health_snapshots())}
  end

  @impl true
  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, socket.assigns.poll_ms)

    {:noreply,
     socket
     |> assign(:snapshots, ModelRegistry.provider_health_snapshots())}
  end

  defp allow?(_socket), do: true

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="provider-health" class="space-y-6 text-bone">
        <div class="border-b border-ash pb-4">
          <h1 class="text-xl font-semibold">Providers</h1>
          <p class="mt-1 text-sm text-[var(--color-smoke)]">
            API presence and recent outcomes (poll every {@poll_ms |> div(1000)}s). Keys are never shown.
          </p>
        </div>

        <div class="grid gap-4 md:grid-cols-2">
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
      "rounded border-2 p-4 font-sans",
      @rag
    ]}>
      <h2 class="text-lg font-semibold capitalize">{to_string(@snap.id)}</h2>
      <p class="mt-2 text-sm font-medium">{@status}</p>
      <dl class="mt-4 grid gap-2 text-xs text-[var(--color-smoke)]">
        <div class="flex justify-between gap-2">
          <dt>Spend today (USD)</dt>
          <dd class="font-mono text-bone">{format_usd(@snap.spend_usd_today)}</dd>
        </div>
        <div class="flex justify-between gap-2">
          <dt>Recent error rate</dt>
          <dd class="font-mono text-bone">{format_rate(@snap.recent_error_rate)}</dd>
        </div>
        <div class="flex justify-between gap-2">
          <dt>Last success</dt>
          <dd class="font-mono text-bone">{format_dt(@snap.last_ok_at)}</dd>
        </div>
        <div class="flex justify-between gap-2">
          <dt>Rate-limit headroom</dt>
          <dd class="font-mono text-bone">{format_optional_int(@snap.rate_limit_remaining)}</dd>
        </div>
        <div class="flex justify-between gap-2">
          <dt>Token budget (today)</dt>
          <dd class="font-mono text-bone">{format_budget(@snap.token_budget_remaining_today)}</dd>
        </div>
      </dl>
    </section>
    """
  end

  defp rag_classes(snap) do
    cond do
      snap.recent_error_rate >= 0.5 ->
        "border-red-700/80 bg-char/60"

      !snap.key_configured? ->
        "border-clay bg-char/60"

      true ->
        "border-emerald-700/70 bg-char/60"
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
end
