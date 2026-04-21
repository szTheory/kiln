defmodule KilnWeb.Components.UnblockPanel do
  @moduledoc """
  BLOCK-02 — typed unblock surface for blocked runs (`RunDetailLive`).
  """

  use Phoenix.Component

  alias Kiln.Blockers

  attr :run, :map, required: true
  attr :block_reason, :atom, required: true

  def unblock_panel(assigns) do
    ctx = %{
      run_id: to_string(assigns.run.id),
      workflow_id: assigns.run.workflow_id,
      estimated_usd: "0.00",
      remaining_usd: "0.00",
      new_cap_usd: "0.00"
    }

    text =
      case Blockers.render(assigns.block_reason, ctx) do
        {:ok, rp} ->
          cmds =
            rp.commands
            |> Enum.map_join("\n", fn c -> "#{c.label}: #{c.command}" end)

          Enum.join(
            [
              rp.title,
              "",
              rp.short_message,
              "",
              "Commands:",
              cmds,
              "",
              rp.body_markdown
            ],
            "\n"
          )

        {:error, _} ->
            "Playbook unavailable for #{inspect(assigns.block_reason)}."
      end

    assigns = assign(assigns, :playbook_text, text)

    ~H"""
    <section
      id="unblock-panel"
      class="space-y-4 rounded border border-clay bg-char/80 p-4 text-bone"
      aria-label="Unblock"
    >
      <h2 class="text-lg font-semibold text-bone">Run blocked</h2>
      <div class="rounded border border-ash bg-iron/40 p-3">
        <pre class="whitespace-pre-wrap font-mono text-xs text-bone phx-no-curly-interpolation">{@playbook_text}</pre>
      </div>
      <button
        type="button"
        id="unblock-retry-btn"
        phx-click="unblock_retry"
        phx-value-to="planning"
        class="rounded border border-ember px-4 py-2 text-sm font-semibold text-ember transition-colors hover:bg-ember/10"
      >
        I fixed it — retry
      </button>
    </section>
    """
  end
end
