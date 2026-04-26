defmodule KilnWeb.Components.AgentTicker do
  @moduledoc """
  UI-09 — shell around the home-surface **`agent_ticker`** stream (`RunBoardLive` only).
  """

  use Phoenix.Component

  slot :inner_block, required: true

  def agent_ticker(assigns) do
    ~H"""
    <section class="card card-bordered bg-base-200 border-base-300 mt-8">
      <div class="card-body p-5">
        <h2 class="kiln-eyebrow">Factory activity</h2>
        <p class="kiln-meta mt-1">
          Recent state transitions (rate-limited per run).
        </p>
        <div class="mt-3">
          {render_slot(@inner_block)}
        </div>
      </div>
    </section>
    """
  end
end
