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
      class="card card-bordered border-warning bg-base-200"
      aria-label="Unblock"
    >
      <div class="card-body p-5 space-y-4">
        <div class="flex items-center gap-2">
          <span class="badge badge-warning badge-soft">Blocked</span>
          <h2 class="kiln-h2">Run blocked</h2>
        </div>
        <div class="rounded-md border border-base-300 bg-base-100 p-3">
          <pre class="whitespace-pre-wrap kiln-mono text-xs phx-no-curly-interpolation">{@playbook_text}</pre>
        </div>
        <button
          type="button"
          id="unblock-retry-btn"
          phx-click="unblock_retry"
          phx-value-to="planning"
          class="btn btn-sm btn-primary"
        >
          I fixed it — retry
        </button>
      </div>
    </section>
    """
  end
end
