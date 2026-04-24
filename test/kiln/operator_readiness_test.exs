defmodule Kiln.OperatorReadinessTest do
  use Kiln.DataCase, async: false

  alias Kiln.OperatorReadiness
  alias Kiln.OperatorReadiness.ProbeRow
  alias Kiln.Repo

  setup do
    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, true)

    :ok
  end

  test "ready? reflects persisted flags" do
    assert OperatorReadiness.ready?()
    assert {:ok, _} = OperatorReadiness.mark_step(:github, false)
    refute OperatorReadiness.ready?()
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert OperatorReadiness.ready?()
  end

  test "fresh readiness state is pessimistic by default" do
    Repo.delete_all(ProbeRow)

    refute OperatorReadiness.ready?()

    assert %{
             anthropic: false,
             github: false,
             docker: false,
             verified: 0,
             total: 3
           } = OperatorReadiness.current_state()
  end

  test "mark_step upserts the singleton row when it is missing" do
    Repo.delete_all(ProbeRow)

    assert {:ok, row} = OperatorReadiness.mark_step(:docker, true)
    assert row.id == 1
    refute row.anthropic_configured
    refute row.github_cli_ok
    assert row.docker_ok
  end
end
