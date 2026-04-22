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
    <div
      id="factory-header"
      class="mb-3 flex flex-wrap items-center justify-between gap-3 rounded border border-ash bg-iron/30 px-3 py-2 text-xs text-bone"
    >
      <div class="font-mono tabular-nums">
        <span class="text-[var(--color-smoke)]">Active</span>
        <span class="ml-1 font-semibold text-bone">{@summary.active}</span>
        <span class="ml-4 text-[var(--color-smoke)]">Blocked</span>
        <span class={[
          "ml-1 font-semibold tabular-nums",
          @summary.blocked > 0 && "text-[var(--color-clay)]",
          @summary.blocked == 0 && "text-bone"
        ]}>
          {@summary.blocked}
        </span>
      </div>
    </div>
    """
  end
end
