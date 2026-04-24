defmodule Kiln.Specs.AttachRequestDraftTest do
  use Kiln.DataCase, async: true

  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.Intake
  alias Kiln.Specs

  test "persists attached_repo_id, request_kind, change_summary, acceptance_criteria, and out_of_scope on spec_drafts" do
    attached_repo = attached_repo_fixture()

    assert {:ok, draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "feature",
               "title" => "Bound attached change",
               "change_summary" => "Persist the intake contract on the draft.",
               "acceptance_criteria" => ["Stored on spec_drafts", "Reusable on promotion"],
               "out_of_scope" => ["Repeat-run continuity"]
             })

    assert draft.source == :attached_repo_intake
    assert draft.attached_repo_id == attached_repo.id
    assert draft.request_kind == :feature
    assert draft.change_summary == "Persist the intake contract on the draft."
    assert draft.acceptance_criteria == ["Stored on spec_drafts", "Reusable on promotion"]
    assert draft.out_of_scope == ["Repeat-run continuity"]
  end

  test "copies the same bounded-request fields into spec_revisions" do
    attached_repo = attached_repo_fixture()

    assert {:ok, draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "bugfix",
               "title" => "Fix stale request launch",
               "change_summary" => "Carry the intake contract into the promoted revision.",
               "acceptance_criteria" => ["Frozen on spec_revisions"],
               "out_of_scope" => ["Draft PR messaging"]
             })

    assert {:ok, %{revision: revision}} = Specs.promote_draft(draft.id)

    assert revision.attached_repo_id == attached_repo.id
    assert revision.request_kind == :bugfix
    assert revision.change_summary == "Carry the intake contract into the promoted revision."
    assert revision.acceptance_criteria == ["Frozen on spec_revisions"]
    assert revision.out_of_scope == ["Draft PR messaging"]
  end

  test "attached-request drafts stay in the existing Specs lifecycle and do not bypass open/promoted state rules" do
    attached_repo = attached_repo_fixture()

    assert {:ok, draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "feature",
               "title" => "Respect existing lifecycle",
               "change_summary" => "Use the standard draft promotion rules.",
               "acceptance_criteria" => ["Can promote once"]
             })

    assert {:ok, %{draft: promoted}} = Specs.promote_draft(draft.id)
    assert promoted.inbox_state == :promoted
    assert {:error, :invalid_state} = Specs.promote_draft(draft.id)
  end

  defp attached_repo_fixture(attrs \\ %{}) do
    base_attrs = %{
      source_kind: :local_path,
      repo_provider: :local,
      repo_name: "kiln",
      repo_slug: "jon/kiln",
      canonical_input: "/tmp/kiln",
      canonical_repo_root: "/tmp/kiln",
      source_fingerprint: "local_path:/tmp/kiln-specs-#{System.unique_integer([:positive])}",
      workspace_key: "workspace-specs-#{System.unique_integer([:positive])}",
      workspace_path: "/tmp/kiln-workspace",
      base_branch: "main"
    }

    %AttachedRepo{}
    |> AttachedRepo.changeset(Map.merge(base_attrs, attrs))
    |> Repo.insert!()
  end
end
