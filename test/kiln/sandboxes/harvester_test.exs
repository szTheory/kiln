defmodule Kiln.Sandboxes.HarvesterTest do
  use Kiln.DataCase, async: false

  require Logger

  alias Kiln.Audit
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.Sandboxes.{Harvester, Hydrator}

  setup do
    correlation_id = Ecto.UUID.generate()
    Logger.metadata(correlation_id: correlation_id)

    run = RunFactory.insert(:run)
    stage_run = StageRunFactory.insert(:stage_run, run_id: run.id)
    workspace_dir = Path.join(System.tmp_dir!(), "kiln-harvester-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(workspace_dir, "out"))

    on_exit(fn ->
      File.rm_rf!(workspace_dir)
      Logger.metadata(correlation_id: nil)
    end)

    {:ok, run: run, stage_run: stage_run, workspace_dir: workspace_dir, correlation_id: correlation_id}
  end

  test "harvests regular out files in sorted order and emits artifact_written events", %{
    run: run,
    stage_run: stage_run,
    workspace_dir: workspace_dir,
    correlation_id: correlation_id
  } do
    File.write!(Path.join(workspace_dir, "out/b.txt"), "second")
    File.write!(Path.join(workspace_dir, "out/a.txt"), "first")

    assert {:ok, records} = Harvester.harvest(workspace_dir, run.id, stage_run.id)
    assert Enum.map(records, & &1.name) == ["a.txt", "b.txt"]

    events =
      Audit.replay(correlation_id: correlation_id)
      |> Enum.filter(&(&1.event_kind == :artifact_written and &1.run_id == run.id))

    assert length(events) == 2
  end

  test "returns ok with an empty list when out is empty", %{run: run, stage_run: stage_run, workspace_dir: workspace_dir} do
    assert {:ok, []} = Harvester.harvest(workspace_dir, run.id, stage_run.id)
  end

  test "skips nested directories under out", %{run: run, stage_run: stage_run, workspace_dir: workspace_dir} do
    File.mkdir_p!(Path.join(workspace_dir, "out/nested"))
    File.write!(Path.join(workspace_dir, "out/nested/ignored.txt"), "ignored")
    File.write!(Path.join(workspace_dir, "out/top.txt"), "kept")

    assert {:ok, [%{name: "top.txt"}]} = Harvester.harvest(workspace_dir, run.id, stage_run.id)
  end

  test "round-trips harvested bytes back through hydration", %{
    run: run,
    stage_run: stage_run,
    workspace_dir: workspace_dir
  } do
    File.write!(Path.join(workspace_dir, "out/result.txt"), "phase 3 ships")

    assert {:ok, [%{name: "result.txt", sha256: sha, size_bytes: size}]} =
             Harvester.harvest(workspace_dir, run.id, stage_run.id)

    restored_workspace =
      Path.join(System.tmp_dir!(), "kiln-harvester-restore-#{System.unique_integer([:positive])}")

    on_exit(fn ->
      File.rm_rf!(restored_workspace)
    end)

    assert {:ok, [_]} =
             Hydrator.hydrate(
               [%{name: "result.txt", sha256: sha, size_bytes: size}],
               restored_workspace
             )

    assert File.read!(Path.join(restored_workspace, "result.txt")) == "phase 3 ships"
  end
end
