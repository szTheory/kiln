defmodule KilnWeb.Components.RunProgress do
  @moduledoc "UI-08 — compact stage / elapsed / staleness chip for runs."

  use Phoenix.Component

  attr :run, :map, required: true
  attr :stages_done, :integer, required: true
  attr :stages_total, :integer, required: true
  attr :last_activity_at, :any, required: true

  def run_progress(assigns) do
    elapsed_s = elapsed_seconds(assigns.last_activity_at)

    assigns =
      assigns
      |> assign(:stale_class, staleness_class(assigns.last_activity_at))
      |> assign(:elapsed_label, format_elapsed(elapsed_s))

    ~H"""
    <div
      id={"run-progress-#{@run.id}"}
      class={[
        "rounded border px-2 py-1 font-mono text-[10px] leading-tight",
        @stale_class
      ]}
    >
      <div class="text-bone">
        Stages {@stages_done}/{@stages_total}
      </div>
      <div class="mt-0.5 text-[var(--color-smoke)]">
        Elapsed {@elapsed_label}
      </div>
      <div class="mt-0.5 text-[var(--color-smoke)]">
        Not enough history
      </div>
    </div>
    """
  end

  defp elapsed_seconds(%DateTime{} = at) do
    DateTime.diff(DateTime.utc_now(:microsecond), at, :second)
  end

  defp elapsed_seconds(_), do: 0

  defp format_elapsed(s) when s < 60, do: "#{s}s"
  defp format_elapsed(s), do: "#{div(s, 60)}m #{rem(s, 60)}s"

  defp staleness_class(nil), do: "border-ash text-bone"

  defp staleness_class(%DateTime{} = at) do
    diff = DateTime.diff(DateTime.utc_now(:microsecond), at, :second)

    cond do
      diff < 30 -> "border-emerald-700/60 text-bone"
      diff < 300 -> "border-amber-600/70 text-bone"
      true -> "border-[var(--color-clay)] text-bone"
    end
  end
end
