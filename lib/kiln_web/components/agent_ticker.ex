defmodule KilnWeb.Components.AgentTicker do
  @moduledoc """
  UI-09 — shell around the home-surface **`agent_ticker`** stream (`RunBoardLive` only).
  """

  use Phoenix.Component

  slot :inner_block, required: true

  def agent_ticker(assigns) do
    ~H"""
    <section class="mt-8 rounded border border-ash bg-char/80 p-4">
      <h2 class="text-sm font-semibold text-bone">Factory activity</h2>
      <p class="mt-1 text-xs text-[var(--color-smoke)]">
        Recent state transitions (rate-limited per run).
      </p>
      <div class="mt-3">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end
end
