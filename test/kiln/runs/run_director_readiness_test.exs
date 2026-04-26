defmodule Kiln.Runs.RunDirectorReadinessTest do
  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.OperatorSetup
  alias Kiln.OperatorReadiness
  alias Kiln.OperatorReadiness.ProbeRow
  alias Kiln.Repo
  alias Kiln.Runs.RunDirector

  test "start_run returns factory_not_ready when OperatorReadiness is false" do
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, false)

    run = RunFactory.insert(:run, state: :queued)

    try do
      assert {:error, :factory_not_ready} = RunDirector.start_run(run.id)
    after
      assert {:ok, _} = OperatorReadiness.mark_step(:docker, true)
    end
  end

  test "start_run returns factory_not_ready when readiness row has not been verified yet" do
    Repo.delete_all(ProbeRow)
    run = RunFactory.insert(:run, state: :queued)

    assert {:error, :factory_not_ready} = RunDirector.start_run(run.id)
  end

  test "first_blocker follows checklist order and preserves the settings anchor" do
    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, false)
    assert {:ok, _} = OperatorReadiness.mark_step(:github, false)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, false)

    assert %{id: :anthropic, href: "/settings#settings-item-anthropic"} =
             OperatorSetup.first_blocker()
  end
end
