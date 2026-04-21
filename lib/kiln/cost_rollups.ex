defmodule Kiln.CostRollups do
  @moduledoc """
  Read-only spend rollups for the operator cost dashboard (UI-04).

  All windows use **UTC** boundaries: `from` defaults to midnight UTC on the
  current calendar day; `to` defaults to `DateTime.utc_now/0`. Weekly presets
  use ISO week Monday 00:00 UTC through `to`.
  """

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.Runs.Run
  alias Kiln.Stages.StageRun

  @typedoc "Spend window — both ends inclusive on `stage_runs.inserted_at`."
  @type window :: %{optional(:from) => DateTime.t(), optional(:to) => DateTime.t()}

  @spec by_run(window() | keyword()) :: [
          %{key: Ecto.UUID.t(), usd: Decimal.t(), calls: integer()}
        ]
  def by_run(opts \\ []) do
    {from, to} = normalize_window(opts)

    from(sr in StageRun,
      join: r in Run,
      on: sr.run_id == r.id,
      where: sr.inserted_at >= ^from and sr.inserted_at <= ^to,
      group_by: sr.run_id,
      select: %{
        key: sr.run_id,
        usd: coalesce(sum(sr.cost_usd), ^Decimal.new("0")),
        calls: count(sr.id)
      }
    )
    |> Repo.all()
  end

  @spec by_workflow(window() | keyword()) :: [
          %{key: String.t(), usd: Decimal.t(), calls: integer()}
        ]
  def by_workflow(opts \\ []) do
    {from, to} = normalize_window(opts)

    from(sr in StageRun,
      join: r in Run,
      on: sr.run_id == r.id,
      where: sr.inserted_at >= ^from and sr.inserted_at <= ^to,
      group_by: r.workflow_id,
      select: %{
        key: r.workflow_id,
        usd: coalesce(sum(sr.cost_usd), ^Decimal.new("0")),
        calls: count(sr.id)
      }
    )
    |> Repo.all()
  end

  @spec by_agent_role(window() | keyword()) :: [
          %{key: atom(), usd: Decimal.t(), calls: integer()}
        ]
  def by_agent_role(opts \\ []) do
    {from, to} = normalize_window(opts)

    from(sr in StageRun,
      join: r in Run,
      on: sr.run_id == r.id,
      where: sr.inserted_at >= ^from and sr.inserted_at <= ^to,
      group_by: sr.agent_role,
      select: %{
        key: sr.agent_role,
        usd: coalesce(sum(sr.cost_usd), ^Decimal.new("0")),
        calls: count(sr.id)
      }
    )
    |> Repo.all()
  end

  @spec by_provider(window() | keyword()) :: [
          %{key: String.t(), usd: Decimal.t(), calls: integer()}
        ]
  def by_provider(opts \\ []) do
    {from, to} = normalize_window(opts)

    from(sr in StageRun,
      join: r in Run,
      on: sr.run_id == r.id,
      where: sr.inserted_at >= ^from and sr.inserted_at <= ^to,
      group_by: fragment("coalesce(?, 'unpriced')", sr.actual_model_used),
      select: %{
        key: fragment("coalesce(?, 'unpriced')", sr.actual_model_used),
        usd: coalesce(sum(sr.cost_usd), ^Decimal.new("0")),
        calls: count(sr.id)
      }
    )
    |> Repo.all()
  end

  defp normalize_window(%{} = m), do: normalize_window(Keyword.new(m))

  defp normalize_window(opts) when is_list(opts) do
    to = Keyword.get(opts, :to, DateTime.utc_now(:microsecond))
    from = Keyword.get(opts, :from, utc_start_of_day(DateTime.utc_now(:microsecond)))
    {from, to}
  end

  defp utc_start_of_day(%DateTime{} = dt) do
    DateTime.new!(DateTime.to_date(dt), ~T[00:00:00.000000], "Etc/UTC")
  end
end
