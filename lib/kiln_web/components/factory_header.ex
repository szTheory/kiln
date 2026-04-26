defmodule KilnWeb.Components.FactoryHeader do
  @moduledoc """
  UI-07 — sparse factory summary chrome (counts + blocked badge).

  LiveViews receive assigns via `Layouts.app` / `FactorySummaryHook`, which
  subscribes to the **`factory:summary`** PubSub topic (`{:factory_summary, map()}`).
  """

  use Phoenix.Component

  attr :summary, :map, required: true, doc: "expects %{active: integer(), blocked: integer()}"

  def factory_header(assigns) do
    ~H"""
    <div id="factory-header" class="kiln-status-numeric inline-flex items-center gap-3">
      <span>
        <span class="kiln-status-numeric__label">Active</span>
        <span class="font-semibold tabular-nums">{@summary.active}</span>
      </span>
      <span class="opacity-40" aria-hidden="true">·</span>
      <span>
        <span class="kiln-status-numeric__label">Blocked</span>
        <span class={[
          "font-semibold tabular-nums",
          @summary.blocked > 0 && "text-warning"
        ]}>
          {@summary.blocked}
        </span>
      </span>
    </div>
    """
  end
end
