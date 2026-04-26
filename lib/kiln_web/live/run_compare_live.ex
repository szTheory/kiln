defmodule KilnWeb.RunCompareLive do
  @moduledoc """
  PARA-02 — side-by-side run comparison at `/runs/compare?baseline=&candidate=`.

  Query ids are validated as UUIDs; invalid values mirror `RunDetailLive` with
  flash **\"Invalid run id\"** and redirect to `/`.
  """

  use KilnWeb, :live_view

  alias Decimal
  alias Kiln.Runs
  alias Kiln.Stages.StageRun

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Compare runs")
     |> assign(:baseline_id_str, "")
     |> assign(:candidate_id_str, "")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    baseline_raw = params["baseline"]
    candidate_raw = params["candidate"]

    cond do
      uuid_param_invalid?(baseline_raw) or uuid_param_invalid?(candidate_raw) ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid run id")
         |> push_navigate(to: ~p"/")}

      true ->
        baseline_id = uuid_param_assignment(baseline_raw)
        candidate_id = uuid_param_assignment(candidate_raw)

        baseline_trim = if is_binary(baseline_raw), do: String.trim(baseline_raw), else: ""
        candidate_trim = if is_binary(candidate_raw), do: String.trim(candidate_raw), else: ""

        {snapshot, baseline_id_str, candidate_id_str} =
          case {baseline_id, candidate_id} do
            {{:ok, b}, {:ok, c}} ->
              {Runs.compare_snapshot(b, c), baseline_trim, candidate_trim}

            _ ->
              {nil, "", ""}
          end

        socket =
          socket
          |> assign(:baseline_id, baseline_id)
          |> assign(:candidate_id, candidate_id)
          |> assign(:baseline_id_str, baseline_id_str)
          |> assign(:candidate_id_str, candidate_id_str)
          |> assign(:snapshot, snapshot)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("noop", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("swap_sides", _params, socket) do
    case {socket.assigns.baseline_id, socket.assigns.candidate_id} do
      {{:ok, b}, {:ok, c}} ->
        q =
          URI.encode_query(%{
            "baseline" => uuid_string!(c),
            "candidate" => uuid_string!(b)
          })

        {:noreply, push_patch(socket, to: "/runs/compare?" <> q)}

      _ ->
        {:noreply, socket}
    end
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
      <div
        id="run-compare"
        class="space-y-6"
        data-union-count={@snapshot && length(@snapshot.union_stage_ids)}
        data-baseline-id={@baseline_id_str}
        data-candidate-id={@candidate_id_str}
      >
        <%= if not (match?({:ok, _}, @baseline_id) and match?({:ok, _}, @candidate_id)) do %>
          <p class="text-sm text-base-content/60">
            Add baseline and candidate query parameters.
          </p>
        <% else %>
          <%= if duplicate_compare?(@baseline_id, @candidate_id) do %>
            <div
              class="rounded border border-warning bg-base-200 p-3 text-sm text-base-content"
              role="status"
            >
              Baseline and candidate are the same run — comparison is for link sharing only.
            </div>
          <% end %>

          <div class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 pb-3">
            <p class="kiln-eyebrow">Factory</p>
            <h1 class="kiln-h1 mt-1">Compare runs</h1>
            <button
              type="button"
              id="run-compare-swap"
              phx-click="swap_sides"
              class="rounded border border-base-300 px-3 py-1.5 text-sm text-base-content transition-colors hover:border-primary hover:text-primary"
            >
              Swap
            </button>
          </div>

          <%= if @snapshot do %>
            <section class="grid gap-4 rounded border border-base-300 bg-base-200 p-4 lg:grid-cols-2">
              <.identity_column title="Baseline" run={@snapshot.baseline_run} />
              <.identity_column title="Candidate" run={@snapshot.candidate_run} />
            </section>

            <section class="rounded border border-base-300 bg-base-200 p-4">
              <h2 class="kiln-eyebrow">
                Cost summary
              </h2>
              <div class="mt-2 grid gap-4 font-mono text-sm tabular-nums text-base-content md:grid-cols-2">
                <div>
                  <p class="text-base-content/60">Baseline USD</p>
                  <p>{format_decimal(sum_cost(@snapshot.rows, :baseline_stage))}</p>
                  <p class="mt-1 text-base-content/60">Tokens</p>
                  <p>{sum_tokens(@snapshot.rows, :baseline_stage)}</p>
                </div>
                <div>
                  <p class="text-base-content/60">Candidate USD</p>
                  <p>{format_decimal(sum_cost(@snapshot.rows, :candidate_stage))}</p>
                  <p class="mt-1 text-base-content/60">Tokens</p>
                  <p>{sum_tokens(@snapshot.rows, :candidate_stage)}</p>
                </div>
              </div>
            </section>

            <section class="rounded border border-base-300 bg-base-200 p-4">
              <h2 class="kiln-eyebrow">
                Stages
              </h2>
              <div class="mt-3 space-y-2">
                <%= for stage_id <- @snapshot.union_stage_ids do %>
                  <% row = Enum.find(@snapshot.rows, &(&1.workflow_stage_id == stage_id)) %>
                  <div
                    class="grid gap-2 rounded border border-base-300 bg-base-300/60 p-3 md:grid-cols-2"
                    data-stage-key={stage_id}
                  >
                    <.stage_cell label="Baseline" row={row} side={:baseline} />
                    <.stage_cell label="Candidate" row={row} side={:candidate} />
                  </div>
                <% end %>
              </div>
            </section>

            <section class="rounded border border-base-300 bg-base-200 p-4">
              <h2 class="kiln-eyebrow">
                Artifacts
              </h2>
              <ul class="mt-3 space-y-2 text-sm text-base-content">
                <%= for art <- @snapshot.artifact_rows do %>
                  <li class="rounded border border-base-300 bg-base-300/40 p-2">
                    <div class="font-mono text-xs text-base-content/60">{art.logical_key}</div>
                    <div class="mt-1 flex flex-wrap gap-3 text-xs">
                      <span>{artifact_equality_label(art.equality)}</span>
                      <%= if art.baseline_meta && art.workflow_stage_id do %>
                        <.link
                          class="text-primary underline"
                          navigate={
                            artifact_diff_href(art.baseline_meta.run_id, art.workflow_stage_id)
                          }
                        >
                          Open diff (baseline)
                        </.link>
                      <% end %>
                      <%= if art.candidate_meta && art.workflow_stage_id do %>
                        <.link
                          class="text-primary underline"
                          navigate={
                            artifact_diff_href(art.candidate_meta.run_id, art.workflow_stage_id)
                          }
                        >
                          Open diff (candidate)
                        </.link>
                      <% end %>
                    </div>
                  </li>
                <% end %>
              </ul>
            </section>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :run, :any, required: true

  def identity_column(assigns) do
    ~H"""
    <div class="space-y-2">
      <h3 class="kiln-eyebrow">
        {@title}
      </h3>
      <%= if @run do %>
        <p class="font-mono text-xs tabular-nums text-base-content">{short8(@run.id)}</p>
        <p class="text-sm text-base-content">{@run.workflow_id}</p>
        <p class="text-xs text-base-content/60">{inspect(@run.state)}</p>
      <% else %>
        <p class="text-sm font-semibold text-base-content">Run not found</p>
        <p class="text-xs text-base-content/60">Check the id or return to the board.</p>
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :row, :map, required: true
  attr :side, :atom, required: true

  def stage_cell(assigns) do
    {stage, gap_copy} =
      case assigns.side do
        :baseline ->
          b = assigns.row.baseline_stage
          c = assigns.row.candidate_stage

          cond do
            match?(%StageRun{}, b) ->
              {b, nil}

            match?(%StageRun{}, c) ->
              {nil, "Present only in candidate"}

            true ->
              {nil, nil}
          end

        :candidate ->
          b = assigns.row.baseline_stage
          c = assigns.row.candidate_stage

          cond do
            match?(%StageRun{}, c) ->
              {c, nil}

            match?(%StageRun{}, b) ->
              {nil, "Present only in baseline"}

            true ->
              {nil, nil}
          end
      end

    assigns =
      assigns
      |> assign(:stage, stage)
      |> assign(:gap_copy, gap_copy)

    ~H"""
    <div class="text-xs">
      <p class="font-semibold text-base-content/60">{@label}</p>
      <%= cond do %>
        <% match?(%StageRun{}, @stage) -> %>
          <p class="mt-1 font-mono text-base-content tabular-nums">{@stage.workflow_stage_id}</p>
          <p class="mt-1 text-base-content/60">{inspect(@stage.state)}</p>
        <% is_binary(@gap_copy) -> %>
          <p class="mt-1 text-base-content/60">{@gap_copy}</p>
        <% true -> %>
          <p class="mt-1 text-base-content/60">—</p>
      <% end %>
    </div>
    """
  end

  defp duplicate_compare?({:ok, a}, {:ok, a}), do: true
  defp duplicate_compare?(_, _), do: false

  defp short8(uuid_bin) when is_binary(uuid_bin) do
    uuid_string!(uuid_bin) |> String.slice(0, 8)
  end

  defp uuid_string!(raw) when byte_size(raw) == 16 do
    h = Base.encode16(raw, case: :lower)

    String.slice(h, 0, 8) <>
      "-" <>
      String.slice(h, 8, 4) <>
      "-" <>
      String.slice(h, 12, 4) <>
      "-" <>
      String.slice(h, 16, 4) <>
      "-" <>
      String.slice(h, 20, 12)
  end

  defp uuid_string!(s) when is_binary(s) do
    case Ecto.UUID.cast(s) do
      {:ok, canonical} when is_binary(canonical) -> canonical
      :error -> ""
    end
  end

  defp sum_cost(rows, key) do
    Enum.reduce(rows, Decimal.new("0"), fn row, acc ->
      case Map.get(row, key) do
        %StageRun{cost_usd: %Decimal{} = c} -> Decimal.add(acc, c)
        _ -> acc
      end
    end)
  end

  defp sum_tokens(rows, key) do
    Enum.reduce(rows, 0, fn row, acc ->
      case Map.get(row, key) do
        %StageRun{tokens_used: n} when is_integer(n) -> acc + n
        _ -> acc
      end
    end)
  end

  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp format_decimal(_), do: "0"

  defp artifact_equality_label(:same), do: "Same digest (SHA-256)"
  defp artifact_equality_label(:different), do: "Different bytes"
  defp artifact_equality_label(:baseline_only), do: "Present only in baseline"
  defp artifact_equality_label(:candidate_only), do: "Present only in candidate"
  defp artifact_equality_label(_), do: "Unknown"

  defp artifact_diff_href(run_id, workflow_stage_id) do
    ~p"/runs/#{run_id}?#{URI.encode_query(%{"stage" => workflow_stage_id, "pane" => "diff"})}"
  end

  defp uuid_param_invalid?(raw) when is_binary(raw) do
    t = String.trim(raw)
    t != "" and match?(:error, Ecto.UUID.cast(t))
  end

  defp uuid_param_invalid?(_), do: false

  defp uuid_param_assignment(nil), do: nil

  defp uuid_param_assignment(raw) when is_binary(raw) do
    case String.trim(raw) do
      "" ->
        nil

      t ->
        case Ecto.UUID.cast(t) do
          {:ok, uuid} -> {:ok, uuid}
          :error -> nil
        end
    end
  end

  defp uuid_param_assignment(_), do: nil
end
