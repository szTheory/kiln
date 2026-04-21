defmodule Kiln.Runs.RunDirectorReadinessTest do
  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.OperatorReadiness
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
end
