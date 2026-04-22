defmodule Kiln.BudgetAlerts do
  @moduledoc """
  Soft budget threshold evaluation (Phase 18 COST-02).

  Uses the same cap and completed-stage spend semantics as
  `Kiln.Agents.BudgetGuard` (D-138). Threshold crossings are **advisory**;
  halting remains `:budget_exceeded` via `BudgetGuard`.

  Each configured percentage band fires at most once per run until spend
  drops and re-crosses, enforced by consulting existing
  `:budget_threshold_crossed` audit rows for the run.
  """

  require Logger

  alias Kiln.Agents.BudgetGuard
  alias Kiln.Audit
  alias Kiln.Repo
  alias Kiln.Runs

  @default_soft_thresholds_pct [50, 80]

  @doc """
  Returns configured soft threshold percentages (e.g. `[50, 80]` for 50% and
  80% of `max_tokens_usd`).
  """
  @spec threshold_percentages() :: [pos_integer(), ...]
  def threshold_percentages do
    Application.get_env(:kiln, __MODULE__, [])
    |> Keyword.get(:soft_thresholds_pct, @default_soft_thresholds_pct)
  end

  @doc """
  Returns maps describing **new** threshold crossings for `run_id` — bands
  where spend has reached the boundary and no `budget_threshold_crossed`
  audit exists yet for that percentage.

  Pure read/evaluate: does not append audits or send notifications (see Plan 18-02).
  """
  @spec evaluate_crossings(Ecto.UUID.t()) :: [map()]
  def evaluate_crossings(run_id) do
    run = Runs.get!(run_id)
    cap = decimalize(get_in(run.caps_snapshot, ["max_tokens_usd"]) || 0)
    spent = BudgetGuard.sum_completed_stage_spend(run_id)

    recorded = run_id |> crossing_pcts_for_run() |> MapSet.new()

    threshold_percentages()
    |> Enum.flat_map(fn pct ->
      boundary = boundary_usd(cap, pct)

      cond do
        Decimal.compare(cap, Decimal.new(0)) != :gt ->
          []

        Decimal.compare(spent, boundary) == :lt ->
          []

        MapSet.member?(recorded, pct) ->
          []

        true ->
          [
            %{
              pct: pct,
              cap_usd: cap,
              spent_usd: spent,
              boundary_usd: boundary,
              threshold_name: threshold_label(pct),
              band: band_label(pct)
            }
          ]
      end
    end)
  end

  @doc """
  Evaluates soft thresholds for `run_id`, appends `budget_threshold_crossed`
  audits for each **new** crossing, optionally dispatches desktop notifications
  (when the notifications stack is up — see `Kiln.Agents.BudgetGuard`
  parity), then broadcasts `{:budget_alert, payload}` on `run:<id>` for
  LiveView refresh.

  Returns `:ok`. Audit failures are logged and suppress downstream steps.
  """
  @spec notify_run_if_needed(Ecto.UUID.t()) :: :ok
  def notify_run_if_needed(run_id) do
    crossings = evaluate_crossings(run_id)

    if crossings == [] do
      :ok
    else
      correlation_id = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

      case append_crossing_events(run_id, crossings, correlation_id) do
        :ok ->
          maybe_desktop_notify(run_id, crossings)
          broadcast_budget_alert(run_id, crossings)
          :ok

        {:error, reason} ->
          Logger.error(
            "Kiln.BudgetAlerts.notify_run_if_needed/1 audit append failed run_id=#{inspect(run_id)} reason=#{inspect(reason)}"
          )

          :ok
      end
    end
  end

  defp append_crossing_events(run_id, crossings, correlation_id) do
    result =
      Repo.transaction(fn ->
        Enum.each(crossings, fn c ->
          payload = %{
            "pct" => Integer.to_string(c.pct),
            "cap_usd" => Decimal.to_string(c.cap_usd),
            "spent_usd" => Decimal.to_string(c.spent_usd),
            "threshold_name" => c.threshold_name,
            "band" => c.band
          }

          {:ok, _} =
            Audit.append(%{
              event_kind: :budget_threshold_crossed,
              run_id: run_id,
              stage_id: nil,
              correlation_id: correlation_id,
              payload: payload
            })
        end)
      end)

    case result do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_desktop_notify(run_id, crossings) do
    skip? =
      Application.get_env(:kiln, __MODULE__, [])
      |> Keyword.get(:skip_desktop_dispatch, false)

    if skip? or not desktop_ready?() do
      :ok
    else
      Enum.each(crossings, fn c ->
        reason = reason_atom(c.pct)
        severity = desktop_severity(c.pct)

        ctx = %{
          run_id: run_id,
          severity: severity,
          spent_usd: Decimal.to_string(c.spent_usd),
          cap_usd: Decimal.to_string(c.cap_usd),
          pct: Integer.to_string(c.pct)
        }

        _ = Kiln.Notifications.desktop(reason, ctx)
      end)
    end
  end

  defp desktop_ready? do
    Code.ensure_loaded?(Kiln.Notifications) and
      function_exported?(Kiln.Notifications, :desktop, 2) and
      :ets.whereis(Kiln.Notifications.DedupCache) != :undefined
  end

  defp reason_atom(pct) when pct >= 80, do: :budget_threshold_80
  defp reason_atom(_), do: :budget_threshold_50

  defp desktop_severity(pct) when pct >= 80, do: "warning"
  defp desktop_severity(_), do: "info"

  defp broadcast_budget_alert(run_id, crossings) do
    Phoenix.PubSub.broadcast(
      Kiln.PubSub,
      "run:#{run_id}",
      {:budget_alert,
       %{
         run_id: run_id,
         crossings:
           Enum.map(crossings, fn c ->
             %{
               pct: c.pct,
               band: c.band,
               threshold_name: c.threshold_name,
               severity: desktop_severity(c.pct)
             }
           end)
       }}
    )
  end

  defp crossing_pcts_for_run(run_id) do
    run_id
    |> then(&Audit.replay(run_id: &1, event_kind: :budget_threshold_crossed, limit: 500))
    |> Enum.map(&pct_from_payload/1)
    |> Enum.reject(&is_nil/1)
  end

  defp pct_from_payload(%{payload: payload}) when is_map(payload) do
    case Map.get(payload, "pct") || Map.get(payload, :pct) do
      nil -> nil
      p when is_integer(p) -> p
      p when is_binary(p) -> String.to_integer(p)
    end
  rescue
    ArgumentError -> nil
  end

  defp boundary_usd(cap, pct) do
    cap
    |> Decimal.mult(Decimal.new(pct))
    |> Decimal.div(Decimal.new(100))
  end

  defp threshold_label(pct), do: "#{pct}% of cap"

  defp band_label(pct), do: "#{pct}"

  defp decimalize(%Decimal{} = d), do: d
  defp decimalize(s) when is_binary(s), do: Decimal.new(s)
  defp decimalize(n) when is_integer(n), do: Decimal.new(n)
  defp decimalize(n) when is_float(n), do: Decimal.from_float(n)
end
