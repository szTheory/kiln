defmodule Kiln.ArtifactsTest do
  @moduledoc """
  Integration tests for `Kiln.Artifacts` (Plan 02-03 Task 2). Exercises
  the full put → insert → audit-append pairing, read!/1 integrity
  guarantee, ref_for/1 shape, and by_sha/1 dedup visibility.

  Runs `async: false` because CAS writes touch a shared filesystem
  directory (even with per-test correlation_ids, two tests writing
  identical bytes race on the same <sha> path). Content-addressed
  dedup makes this safe in principle, but the filesystem-level
  rename(2) atomicity is what we're testing here — the less we
  concurrency-stress during the plan-level unit tests, the cleaner
  the signal.
  """
  use Kiln.DataCase, async: false
  require Logger

  alias Kiln.{Artifacts, Audit}
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)

    run = RunFactory.insert(:run)
    stage_run = StageRunFactory.insert(:stage_run, run_id: run.id)
    {:ok, run: run, stage_run: stage_run, correlation_id: cid}
  end

  describe "put/4 — happy path (D-80)" do
    test "inserts Artifact row + appends :artifact_written audit event in same tx", %{
      run: run,
      stage_run: sr,
      correlation_id: cid
    } do
      body = ["# Plan\n", "Write the code.\n"]
      expected_size = body |> Enum.map(&IO.iodata_length/1) |> Enum.sum()

      assert {:ok, artifact} =
               Artifacts.put(sr.id, "plan.md", body,
                 run_id: run.id,
                 content_type: "text/markdown",
                 producer_kind: "planning"
               )

      # Artifact row
      assert artifact.stage_run_id == sr.id
      assert artifact.run_id == run.id
      assert artifact.name == "plan.md"
      assert Regex.match?(~r/^[0-9a-f]{64}$/, artifact.sha256)
      assert artifact.size_bytes == expected_size
      assert artifact.content_type == :"text/markdown"
      assert artifact.producer_kind == "planning"
      assert artifact.schema_version == 1
      assert artifact.inserted_at != nil

      # D-80: companion :artifact_written audit event persisted in the
      # same tx with matching correlation_id.
      assert [event] = Audit.replay(correlation_id: cid)
      assert event.event_kind == :artifact_written
      assert event.run_id == run.id
      assert event.stage_id == sr.id
      assert event.payload["name"] == "plan.md"
      assert event.payload["sha256"] == artifact.sha256
      assert event.payload["size_bytes"] == expected_size
      assert event.payload["content_type"] == "text/markdown"
    end

    test "accepts content_type as atom (already normalized)", %{
      run: run,
      stage_run: sr
    } do
      assert {:ok, artifact} =
               Artifacts.put(sr.id, "atom.md", ["body"],
                 run_id: run.id,
                 content_type: :"text/markdown"
               )

      assert artifact.content_type == :"text/markdown"
    end

    test "unique (stage_run_id, name) — second put with same name is rejected", %{
      run: run,
      stage_run: sr
    } do
      body1 = ["first"]
      body2 = ["second"]

      assert {:ok, _} =
               Artifacts.put(sr.id, "plan.md", body1,
                 run_id: run.id,
                 content_type: "text/markdown"
               )

      assert {:error, %Ecto.Changeset{} = cs} =
               Artifacts.put(sr.id, "plan.md", body2,
                 run_id: run.id,
                 content_type: "text/markdown"
               )

      refute cs.valid?
      # The unique_constraint rewrites the DB error into a field error
      # on :stage_run_id (or :name, depending on Ecto version) — either
      # indicates the (stage_run_id, name) collision.
      errors = Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
      assert errors[:stage_run_id] || errors[:name]
    end
  end

  describe "read!/1 — integrity guarantee (D-84)" do
    test "returns bytes on sha match", %{run: run, stage_run: sr} do
      body = "contents here"

      {:ok, artifact} =
        Artifacts.put(sr.id, "file.md", [body],
          run_id: run.id,
          content_type: "text/markdown"
        )

      assert Artifacts.read!(artifact) == body
    end

    test "raises CorruptionError on tampered blob + appends :integrity_violation audit event",
         %{run: run, stage_run: sr, correlation_id: cid} do
      body = "original"

      {:ok, artifact} =
        Artifacts.put(sr.id, "file.md", [body],
          run_id: run.id,
          content_type: "text/markdown"
        )

      # Simulate tampering — blob was mode 0444 so we must chmod back
      # to write. The read!/1 re-hash must reject the changed content.
      path = Kiln.Artifacts.CAS.cas_path(artifact.sha256)
      File.chmod!(path, 0o644)
      File.write!(path, "tampered!")

      assert_raise Kiln.Artifacts.CorruptionError, ~r/expected=.*actual=/, fn ->
        Artifacts.read!(artifact)
      end

      # :integrity_violation audit event is appended BEFORE raising so
      # the forensic record survives the exception.
      events = Audit.replay(correlation_id: cid)

      violation =
        Enum.find(events, &(&1.event_kind == :integrity_violation))

      assert violation
      assert violation.payload["artifact_id"] == artifact.id
      assert violation.payload["expected_sha"] == artifact.sha256
      assert violation.payload["actual_sha"] != artifact.sha256

      # Restore mode for cleanup (tmpdirs will be wiped anyway but be
      # polite to any concurrent tests).
      File.chmod!(path, 0o444)
    end
  end

  describe "get/2" do
    test "returns {:ok, artifact} when (stage_run_id, name) exists", %{
      run: run,
      stage_run: sr
    } do
      {:ok, artifact} =
        Artifacts.put(sr.id, "file.md", ["body"],
          run_id: run.id,
          content_type: "text/markdown"
        )

      assert {:ok, found} = Artifacts.get(sr.id, "file.md")
      assert found.id == artifact.id
    end

    test "returns {:error, :not_found} for a missing (stage_run_id, name)", %{
      stage_run: sr
    } do
      assert {:error, :not_found} = Artifacts.get(sr.id, "nope.md")
    end
  end

  describe "ref_for/1 (D-75)" do
    test "returns the shape stage-contract artifact_ref expects", %{
      run: run,
      stage_run: sr
    } do
      {:ok, artifact} =
        Artifacts.put(sr.id, "file.md", ["bytes"],
          run_id: run.id,
          content_type: "text/markdown"
        )

      ref = Artifacts.ref_for(artifact)
      assert %{sha256: _, size_bytes: _, content_type: _} = ref
      assert Regex.match?(~r/^[0-9a-f]{64}$/, ref.sha256)
      assert ref.size_bytes == 5
      # content_type comes back as the string form (matches the
      # JSON-Schema enum).
      assert ref.content_type == "text/markdown"
    end
  end

  describe "by_sha/1 — dedup visibility (D-77)" do
    test "two artifacts with same bytes share sha and are both returned", %{
      run: run,
      stage_run: sr
    } do
      body = "same bytes"

      {:ok, a1} =
        Artifacts.put(sr.id, "a.md", [body],
          run_id: run.id,
          content_type: "text/markdown"
        )

      {:ok, a2} =
        Artifacts.put(sr.id, "b.md", [body],
          run_id: run.id,
          content_type: "text/markdown"
        )

      # Same bytes → same sha (content-addressing is free dedup)
      assert a1.sha256 == a2.sha256

      ids = Artifacts.by_sha(a1.sha256) |> Enum.map(& &1.id) |> MapSet.new()
      assert MapSet.member?(ids, a1.id)
      assert MapSet.member?(ids, a2.id)
    end
  end

  describe "stream!/1" do
    test "streams blob bytes without re-hashing", %{run: run, stage_run: sr} do
      body = "streaming body"

      {:ok, artifact} =
        Artifacts.put(sr.id, "stream.md", [body],
          run_id: run.id,
          content_type: "text/markdown"
        )

      streamed = artifact |> Artifacts.stream!() |> Enum.join("")
      assert streamed == body
    end
  end
end
