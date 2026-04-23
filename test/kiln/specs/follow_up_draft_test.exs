defmodule Kiln.Specs.FollowUpDraftTest do
  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Repo
  alias Kiln.Specs
  alias Kiln.Specs.SpecDraft

  test "file_follow_up_from_run is idempotent for the same correlation id" do
    run = RunFactory.insert(:run, state: :merged, workflow_id: "wf_follow_up")
    cid = Ecto.UUID.generate()

    assert {:ok, %SpecDraft{id: id1}} =
             Specs.file_follow_up_from_run(run, correlation_id: cid)

    assert {:ok, %SpecDraft{id: id2}} =
             Specs.file_follow_up_from_run(run, correlation_id: cid)

    assert id1 == id2
    assert Repo.aggregate(from(d in SpecDraft, where: d.source_run_id == ^run.id), :count) == 1
  end

  test "different correlation ids create distinct drafts" do
    run = RunFactory.insert(:run, state: :merged, workflow_id: "wf_follow_up_2")

    assert {:ok, d1} = Specs.file_follow_up_from_run(run, correlation_id: Ecto.UUID.generate())
    assert {:ok, d2} = Specs.file_follow_up_from_run(run, correlation_id: Ecto.UUID.generate())

    assert d1.id != d2.id
    assert Repo.aggregate(from(d in SpecDraft, where: d.source_run_id == ^run.id), :count) == 2
  end
end
