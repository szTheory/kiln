defmodule Kiln.Oban.PostMortemMaterializeWorkerTest do
  use Kiln.ObanCase, async: false

  require Logger

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Oban.PostMortemMaterializeWorker
  alias Kiln.Runs.PostMortems

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)
    {:ok, correlation_id: cid}
  end

  test "writes run_postmortems row on perform", %{correlation_id: _} do
    run =
      RunFactory.insert(:run,
        state: :merged,
        workflow_id: "wf_post_mortem_worker"
      )

    args = %{
      "run_id" => run.id,
      "idempotency_key" => "post_mortem_materialize:" <> run.id
    }

    assert :ok = perform_job(PostMortemMaterializeWorker, args)

    row = PostMortems.get_by_run_id(run.id)
    assert row.status == :complete
    assert is_map(row.snapshot)
    assert is_list(Map.get(row.snapshot, "stages", []))
  end
end
