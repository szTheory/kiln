defmodule Kiln.Runs.PostMortemsTest do
  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs.PostMortems

  test "upsert_snapshot is idempotent per run_id" do
    run = RunFactory.insert(:run)

    attrs = %{
      schema_version: "1",
      status: :pending,
      source_watermark: "2020-01-01T00:00:00Z",
      snapshot: %{"stages" => []}
    }

    assert {:ok, row1} = PostMortems.upsert_snapshot(run.id, attrs)
    assert row1.run_id == run.id
    assert row1.status == :pending

    assert {:ok, row2} =
             PostMortems.upsert_snapshot(run.id, %{
               attrs
               | status: :complete,
                 snapshot: %{"ok" => true}
             })

    assert row2.run_id == row1.run_id
    assert row2.status == :complete
    assert row2.snapshot == %{"ok" => true}

    assert PostMortems.get_by_run_id(run.id).status == :complete
  end
end
