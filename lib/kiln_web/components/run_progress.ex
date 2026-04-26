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
      |> assign(:state_label, state_label(assigns.run.state))
      |> assign(:activity_label, activity_label(assigns.run.state, assigns.last_activity_at))

    ~H"""
    <div
      id={"run-progress-#{@run.id}"}
      class={[
        "rounded border px-2 py-1 font-mono text-[10px] leading-tight",
        @stale_class
      ]}
    >
      <div class="text-base-content">
        State {@state_label}
      </div>
      <div class="mt-0.5 text-base-content/60">
        Stages {@stages_done}/{@stages_total}
      </div>
      <div class="mt-0.5 text-base-content/60">
        Elapsed {@elapsed_label}
      </div>
      <div class="mt-0.5 text-base-content/60">
        {@activity_label}
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

  defp state_label(state),
    do: state |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp activity_label(:blocked, _), do: "Needs operator input"
  defp activity_label(state, _) when state in [:merged, :failed, :escalated], do: "Terminal state"
  defp activity_label(_, nil), do: "Waiting for first update"

  defp activity_label(_, %DateTime{} = at) do
    diff = DateTime.diff(DateTime.utc_now(:microsecond), at, :second)

    cond do
      diff < 30 -> "Fresh activity"
      diff < 300 -> "Quiet but moving"
      true -> "Waiting on the next update"
    end
  end

  defp staleness_class(nil), do: "border-base-300 text-base-content"

  defp staleness_class(%DateTime{} = at) do
    diff = DateTime.diff(DateTime.utc_now(:microsecond), at, :second)

    cond do
      diff < 30 -> "border-success/70 text-base-content"
      diff < 300 -> "border-warning/70 text-base-content"
      true -> "border-error text-base-content"
    end
  end
end
