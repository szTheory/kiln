defmodule Kiln.WorkUnits.ReadyQueryPerfTest do
  use Kiln.DataCase, async: false

  import Ecto.Query

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Repo
  alias Kiln.WorkUnits.ReadyQuery

  @tag timeout: 120_000

  test "ready query uses partial index and executes under 20ms at 1000 rows" do
    run = RunFactory.insert(:run)
    base = DateTime.utc_now(:microsecond)

    entries =
      for i <- 1..1000 do
        t = DateTime.add(base, i, :microsecond)

        %{
          id: Ecto.UUID.generate(),
          run_id: run.id,
          agent_role: :planner,
          state: if(i <= 900, do: :closed, else: :open),
          priority: 100,
          blockers_open_count: 0,
          input_payload: %{},
          result_payload: %{},
          inserted_at: t,
          updated_at: t,
          claimed_by_role: nil,
          claimed_at: nil,
          closed_at: nil,
          external_ref: nil
        }
      end

    {_, _} = Repo.insert_all(Kiln.WorkUnits.WorkUnit, entries)
    Repo.query!("ANALYZE work_units")

    q = ReadyQuery.ready_for_run(run.id) |> limit(50)
    {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, q)

    explain_sql = "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " <> IO.iodata_to_binary(sql)
    assert %Postgrex.Result{rows: [[plans]]} = Repo.query!(explain_sql, params)
    plan = List.first(plans)

    plan_str = Jason.encode!(plan)

    assert plan_str =~ "work_units_ready_partial_idx"

    exec_ms = Map.fetch!(plan, "Execution Time")
    assert exec_ms < 20.0, "expected <20ms execution, got #{exec_ms}ms"
  end
end
