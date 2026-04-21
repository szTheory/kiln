defmodule Kiln.Runs.Phase5RunFieldsTest do
  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Repo
  alias Kiln.Runs.Run

  test "run row has governed_attempt_count and stuck_signal_window defaults" do
    run = RunFactory.insert(:run)
    loaded = Repo.get!(Run, run.id)

    assert loaded.governed_attempt_count == 0
    assert loaded.stuck_signal_window == []
  end

  test "transition_changeset can update phase 5 counters" do
    run = RunFactory.insert(:run)

    assert {:ok, updated} =
             run
             |> Run.transition_changeset(%{
               state: :planning,
               governed_attempt_count: 2,
               stuck_signal_window: [%{"stage_id" => "s1", "failure_class" => "verify"}]
             })
             |> Repo.update()

    assert updated.governed_attempt_count == 2
    assert hd(updated.stuck_signal_window)["failure_class"] == "verify"
  end
end
