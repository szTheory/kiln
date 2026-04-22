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

  alias Kiln.Agents.BudgetGuard
  alias Kiln.Audit
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
