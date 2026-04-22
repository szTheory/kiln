defmodule Kiln.Runs.RunCompareTest do
  use Kiln.DataCase, async: true

  alias Kiln.Artifacts.Artifact
  alias Kiln.Repo
  alias Kiln.Runs.Compare
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory

  describe "Kiln.Runs.Compare" do
    test "union contains a stage only on baseline with candidate_stage nil" do
      baseline = RunFactory.insert(:run)
      candidate = RunFactory.insert(:run)

      _sb =
        StageRunFactory.insert(:stage_run,
          run_id: baseline.id,
          workflow_stage_id: "only_baseline",
          attempt: 1
        )

      _sc =
        StageRunFactory.insert(:stage_run,
          run_id: candidate.id,
          workflow_stage_id: "only_candidate",
          attempt: 1
        )

      snap = Compare.snapshot(baseline.id, candidate.id)

      assert "only_baseline" in snap.union_stage_ids
      assert "only_candidate" in snap.union_stage_ids

      row_b = Enum.find(snap.rows, &(&1.workflow_stage_id == "only_baseline"))
      assert row_b.baseline_stage
      assert row_b.candidate_stage == nil

      row_c = Enum.find(snap.rows, &(&1.workflow_stage_id == "only_candidate"))
      assert row_c.candidate_stage
      assert row_c.baseline_stage == nil
    end

    test "artifacts with matching sha256 compare as :same" do
      sha = String.duplicate("c", 64)

      baseline = RunFactory.insert(:run)
      candidate = RunFactory.insert(:run)

      sb =
        StageRunFactory.insert(:stage_run,
          run_id: baseline.id,
          workflow_stage_id: "coding",
          attempt: 1
        )

      sc =
        StageRunFactory.insert(:stage_run,
          run_id: candidate.id,
          workflow_stage_id: "coding",
          attempt: 1
        )

      for {run, sr} <- [{baseline, sb}, {candidate, sc}] do
        %Artifact{}
        |> Artifact.changeset(%{
          stage_run_id: sr.id,
          run_id: run.id,
          name: "compare.txt",
          sha256: sha,
          size_bytes: 4,
          content_type: :"text/plain"
        })
        |> Repo.insert!()
      end

      snap = Compare.snapshot(baseline.id, candidate.id)

      row = Enum.find(snap.artifact_rows, &(&1.logical_key == "coding::compare.txt"))
      assert row.equality == :same
    end

    test "artifacts with differing sha256 compare as :different" do
      sha_a = String.duplicate("c", 64)
      sha_b = String.duplicate("e", 64)

      baseline = RunFactory.insert(:run)
      candidate = RunFactory.insert(:run)

      sb =
        StageRunFactory.insert(:stage_run,
          run_id: baseline.id,
          workflow_stage_id: "coding",
          attempt: 1
        )

      sc =
        StageRunFactory.insert(:stage_run,
          run_id: candidate.id,
          workflow_stage_id: "coding",
          attempt: 1
        )

      %Artifact{}
      |> Artifact.changeset(%{
        stage_run_id: sb.id,
        run_id: baseline.id,
        name: "compare.txt",
        sha256: sha_a,
        size_bytes: 4,
        content_type: :"text/plain"
      })
      |> Repo.insert!()

      %Artifact{}
      |> Artifact.changeset(%{
        stage_run_id: sc.id,
        run_id: candidate.id,
        name: "compare.txt",
        sha256: sha_b,
        size_bytes: 4,
        content_type: :"text/plain"
      })
      |> Repo.insert!()

      snap = Compare.snapshot(baseline.id, candidate.id)

      row = Enum.find(snap.artifact_rows, &(&1.logical_key == "coding::compare.txt"))
      assert row.equality == :different
    end
  end
end
