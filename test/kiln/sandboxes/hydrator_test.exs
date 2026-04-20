defmodule Kiln.Sandboxes.HydratorTest do
  use Kiln.DataCase, async: false

  require Logger

  alias Kiln.{Artifacts, Sandboxes.Hydrator}
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory

  setup do
    Logger.metadata(correlation_id: Ecto.UUID.generate())

    run = RunFactory.insert(:run)
    stage_run = StageRunFactory.insert(:stage_run, run_id: run.id)

    workspace_dir =
      Path.join(System.tmp_dir!(), "kiln-hydrator-#{System.unique_integer([:positive])}")

    on_exit(fn ->
      File.rm_rf!(workspace_dir)
      Logger.metadata(correlation_id: nil)
    end)

    {:ok, run: run, stage_run: stage_run, workspace_dir: workspace_dir}
  end

  test "hydrates artifact refs into the workspace", %{
    run: run,
    stage_run: stage_run,
    workspace_dir: workspace_dir
  } do
    {:ok, artifact} =
      Artifacts.put(stage_run.id, "greeting.txt", ["hello kiln"],
        run_id: run.id,
        content_type: :"text/markdown"
      )

    refs = [%{name: "greeting.txt", sha256: artifact.sha256, size_bytes: artifact.size_bytes}]

    assert {:ok, [path]} = Hydrator.hydrate(refs, workspace_dir)
    assert path == Path.join(workspace_dir, "greeting.txt")
    assert File.read!(path) == "hello kiln"
  end

  test "returns missing_artifact when the CAS blob cannot be resolved", %{
    workspace_dir: workspace_dir
  } do
    refs = [%{name: "missing.txt", sha256: String.duplicate("0", 64), size_bytes: 0}]

    assert {:error, {:missing_artifact, sha}} = Hydrator.hydrate(refs, workspace_dir)
    assert sha == String.duplicate("0", 64)
  end

  test "returns ok with an empty path list for empty refs", %{workspace_dir: workspace_dir} do
    assert {:ok, []} = Hydrator.hydrate([], workspace_dir)
  end
end
