defmodule Kiln.GitHub.PromoterTest do
  use Kiln.DataCase, async: false

  import Ecto.Query

  require Logger

  alias Kiln.Repo
  alias Kiln.Audit.Event
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.GitHub.Promoter

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)
    :ok
  end

  test "apply_check_result merges when checks pass" do
    run = RunFactory.insert(:run, state: :verifying)

    assert {:ok, updated} =
             Promoter.apply_check_result(run.id, %{
               "predicate_pass" => true,
               "is_draft" => false,
               "head_sha" => String.duplicate("1", 40),
               "required_failed" => false,
               "required" => []
             })

    assert updated.state == :merged

    assert [_] =
             Repo.all(
               from(e in Event,
                 where: e.run_id == ^run.id and e.event_kind == :ci_status_observed
               )
             )
  end

  test "apply_check_result loops to planning when required checks fail" do
    run = RunFactory.insert(:run, state: :verifying)

    assert {:ok, updated} =
             Promoter.apply_check_result(run.id, %{
               "predicate_pass" => false,
               "required_failed" => true,
               "head_sha" => String.duplicate("2", 40),
               "required" => [%{"name" => "unit", "conclusion" => "failure"}]
             })

    assert updated.state == :planning
    assert is_map(updated.escalation_detail)

    assert [_] =
             Repo.all(
               from(e in Event,
                 where: e.run_id == ^run.id and e.event_kind == :ci_status_observed
               )
             )
  end

  test "apply_check_result ignores non-verifying runs" do
    run = RunFactory.insert(:run, state: :coding)

    assert {:ok, :ignored} =
             Promoter.apply_check_result(run.id, %{
               "predicate_pass" => true,
               "is_draft" => false
             })

    refute Repo.exists?(
             from(e in Event,
               where: e.run_id == ^run.id and e.event_kind == :ci_status_observed
             )
           )
  end
end
