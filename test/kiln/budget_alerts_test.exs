defmodule Kiln.BudgetAlertsTest do
  use Kiln.DataCase, async: true

  alias Kiln.Agents.BudgetGuard
  alias Kiln.Audit
  alias Kiln.BudgetAlerts
  alias Kiln.Repo
  alias Kiln.Runs.Run
  alias Kiln.Stages.StageRun

  setup do
    correlation_id = Ecto.UUID.generate()

    Logger.metadata(correlation_id: correlation_id)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)

    %{correlation_id: correlation_id}
  end

  describe "threshold_percentages/0" do
    test "defaults to [50, 80]" do
      assert BudgetAlerts.threshold_percentages() == [50, 80]
    end
  end

  describe "evaluate_crossings/1" do
    test "returns empty when cap is zero", %{correlation_id: cid} do
      run = insert_run!(%{"max_tokens_usd" => "0"}, cid)
      assert BudgetAlerts.evaluate_crossings(run.id) == []
    end

    test "returns 50% crossing when spend reaches half cap and no prior audit", %{
      correlation_id: cid
    } do
      run = insert_run!(%{"max_tokens_usd" => "100"}, cid)
      insert_stage_run!(run.id, "55", :succeeded)

      [crossing] = BudgetAlerts.evaluate_crossings(run.id)
      assert crossing.pct == 50
      assert crossing.threshold_name == "50% of cap"
      assert Decimal.equal?(crossing.cap_usd, Decimal.new("100"))
      assert Decimal.equal?(crossing.spent_usd, Decimal.new("55"))
    end

    test "returns both bands when spend crosses 80% and no audits exist", %{
      correlation_id: cid
    } do
      run = insert_run!(%{"max_tokens_usd" => "100"}, cid)
      insert_stage_run!(run.id, "85", :succeeded)

      crossings = BudgetAlerts.evaluate_crossings(run.id) |> Enum.sort_by(& &1.pct)
      assert Enum.map(crossings, & &1.pct) == [50, 80]
    end

    test "is idempotent when budget_threshold_crossed already recorded for a band", %{
      correlation_id: cid
    } do
      run = insert_run!(%{"max_tokens_usd" => "100"}, cid)
      insert_stage_run!(run.id, "90", :succeeded)

      assert {:ok, _} =
               Audit.append(%{
                 event_kind: :budget_threshold_crossed,
                 run_id: run.id,
                 stage_id: nil,
                 correlation_id: cid,
                 payload: %{
                   "pct" => "50",
                   "cap_usd" => "100",
                   "spent_usd" => "90",
                   "threshold_name" => "50% of cap",
                   "band" => "50"
                 }
               })

      crossings = BudgetAlerts.evaluate_crossings(run.id)
      assert Enum.map(crossings, & &1.pct) == [80]
    end

    test "matches BudgetGuard sum_completed_stage_spend/1", %{correlation_id: cid} do
      run = insert_run!(%{"max_tokens_usd" => "200"}, cid)
      insert_stage_run!(run.id, "10", :succeeded)
      insert_stage_run!(run.id, "20", :failed)
      insert_stage_run!(run.id, "5", :running)

      spent = BudgetGuard.sum_completed_stage_spend(run.id)
      assert Decimal.equal?(spent, Decimal.new("30"))

      insert_stage_run!(run.id, "80", :succeeded)

      spent2 = BudgetGuard.sum_completed_stage_spend(run.id)
      assert Decimal.equal?(spent2, Decimal.new("110"))

      assert [_ | _] = BudgetAlerts.evaluate_crossings(run.id)
    end
  end

  defp insert_run!(caps_snapshot, correlation_id) do
    %Run{}
    |> Run.changeset(%{
      workflow_id: "wf-budget-alerts-test",
      workflow_version: 1,
      workflow_checksum: String.duplicate("a", 64),
      correlation_id: to_string(correlation_id),
      state: :coding,
      caps_snapshot: caps_snapshot
    })
    |> Repo.insert!()
  end

  defp insert_stage_run!(run_id, cost_usd, state) do
    suffix = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)

    %StageRun{}
    |> StageRun.changeset(%{
      run_id: run_id,
      workflow_stage_id: "st_" <> suffix,
      kind: :coding,
      agent_role: :coder,
      attempt: 1,
      state: state,
      timeout_seconds: 300,
      sandbox: :none,
      cost_usd: cost_usd
    })
    |> Repo.insert!()
  end
end
