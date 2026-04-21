defmodule Kiln.RunsTest do
  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs

  describe "list_for_board/0" do
    test "returns all runs grouped by canonical state order then updated_at desc" do
      r_queued =
        RunFactory.insert(:run,
          state: :queued,
          workflow_id: "wf-board-a"
        )

      r_coding =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: "wf-board-b"
        )

      out = Runs.list_for_board()
      assert length(out) == 2

      assert Enum.any?(out, &(&1.id == r_queued.id))
      assert Enum.any?(out, &(&1.id == r_coding.id))

      # Queued column precedes coding per Run.states/0
      assert Enum.find_index(out, &(&1.id == r_queued.id)) <
               Enum.find_index(out, &(&1.id == r_coding.id))
    end

    test "within the same state, newer updated_at appears first" do
      older =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: "wf-old",
          updated_at: ~U[2026-01-01 00:00:00.000000Z]
        )

      newer =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: "wf-new",
          updated_at: ~U[2026-01-02 00:00:00.000000Z]
        )

      out = Runs.list_for_board() |> Enum.filter(&(&1.state == :coding))
      assert Enum.map(out, & &1.id) == [newer.id, older.id]
    end
  end
end
