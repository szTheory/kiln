defmodule Kiln.Attach.ContinuityTest do
  use Kiln.DataCase, async: true

  alias Kiln.Attach
  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.Intake
  alias Kiln.Runs
  alias Kiln.Specs

  test "explicit draft wins over newer same-repo draft, promoted request, and linked run" do
    attached_repo = attached_repo_fixture()

    assert {:ok, explicit_draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "feature",
               "title" => "Explicit carry-forward",
               "change_summary" => "Prefer the explicit same-repo draft.",
               "acceptance_criteria" => ["explicit draft wins"]
             })

    assert {:ok, _newer_draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "bugfix",
               "title" => "Newer draft",
               "change_summary" => "Would win without an explicit draft id.",
               "acceptance_criteria" => ["newest open draft otherwise wins"]
             })

    assert {:ok, promoted_draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "feature",
               "title" => "Promoted request",
               "change_summary" => "Provides a promoted continuity target.",
               "acceptance_criteria" => ["promotion works"]
             })

    assert {:ok, promoted_request} = Specs.promote_draft(promoted_draft.id)
    assert {:ok, _run} = Runs.create_for_attached_request(promoted_request, attached_repo.id)

    assert {:ok, continuity} =
             Attach.get_repo_continuity(attached_repo.id, draft_id: explicit_draft.id)

    assert continuity.selected_target.kind == :draft
    assert continuity.selected_target.source_id == explicit_draft.id
    assert continuity.carry_forward.source == :draft
    assert continuity.carry_forward.title == "Explicit carry-forward"
  end

  test "latest open draft wins over promoted request and cross-repo data is ignored" do
    attached_repo =
      attached_repo_fixture(%{
        source_fingerprint: "local_path:/tmp/kiln-continuity-a",
        workspace_key: "workspace-continuity-a"
      })

    other_repo =
      attached_repo_fixture(%{
        source_fingerprint: "local_path:/tmp/kiln-continuity-b",
        workspace_key: "workspace-continuity-b",
        repo_slug: "jon/other"
      })

    assert {:ok, promoted_draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "bugfix",
               "title" => "Older promoted request",
               "change_summary" => "Becomes the fallback if no open draft remains.",
               "acceptance_criteria" => ["promoted request available"]
             })

    assert {:ok, _promoted_request} = Specs.promote_draft(promoted_draft.id)

    assert {:ok, open_draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "feature",
               "title" => "Latest same-repo draft",
               "change_summary" => "Should win for this repo.",
               "acceptance_criteria" => ["latest open draft wins"]
             })

    assert {:ok, _other_draft} =
             Intake.create_draft(other_repo.id, %{
               "request_kind" => "feature",
               "title" => "Other repo draft",
               "change_summary" => "Must never leak across repos.",
               "acceptance_criteria" => ["other repo ignored"]
             })

    assert {:ok, continuity} = Attach.get_repo_continuity(attached_repo.id)

    assert continuity.selected_target.kind == :draft
    assert continuity.selected_target.source_id == open_draft.id
    assert continuity.carry_forward.change_summary == "Should win for this repo."
    assert continuity.last_request.source_id == open_draft.id
  end

  test "explicit continuity metadata controls recent attached repo ordering" do
    older_repo =
      attached_repo_fixture(%{
        source_fingerprint: "local_path:/tmp/kiln-continuity-c",
        workspace_key: "workspace-continuity-c"
      })

    newer_repo =
      attached_repo_fixture(%{
        source_fingerprint: "local_path:/tmp/kiln-continuity-d",
        workspace_key: "workspace-continuity-d"
      })

    baseline = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert {:ok, _} =
             Attach.mark_repo_selected(older_repo.id, at: DateTime.add(baseline, 120, :second))

    assert {:ok, _} =
             Attach.mark_run_started(newer_repo.id, at: DateTime.add(baseline, 60, :second))

    recent = Attach.list_recent_attached_repos(limit: 2)

    assert Enum.map(recent, & &1.id) == [older_repo.id, newer_repo.id]
    assert hd(recent).last_selected_at == DateTime.add(baseline, 120, :second)
    assert List.last(recent).last_run_started_at == DateTime.add(baseline, 60, :second)
  end

  test "explicit run selection returns same-repo run context and carry-forward facts" do
    attached_repo =
      attached_repo_fixture(%{
        source_fingerprint: "local_path:/tmp/kiln-continuity-e",
        workspace_key: "workspace-continuity-e"
      })

    assert {:ok, draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "feature",
               "title" => "Run-backed request",
               "change_summary" => "Carry forward from a linked run.",
               "acceptance_criteria" => ["linked run survives"]
             })

    assert {:ok, promoted_request} = Specs.promote_draft(draft.id)
    assert {:ok, run} = Runs.create_for_attached_request(promoted_request, attached_repo.id)

    assert {:ok, continuity} =
             Attach.get_repo_continuity(attached_repo.id, run_id: run.id)

    assert continuity.selected_target.kind == :run
    assert continuity.selected_target.run_id == run.id
    assert continuity.last_run.id == run.id
    assert continuity.carry_forward.source == :run
    assert continuity.carry_forward.change_summary == "Carry forward from a linked run."
  end

  defp attached_repo_fixture(attrs \\ %{}) do
    base_attrs = %{
      source_kind: :local_path,
      repo_provider: :local,
      repo_name: "kiln",
      repo_slug: "jon/kiln",
      canonical_input: "/tmp/kiln",
      canonical_repo_root: "/tmp/kiln",
      source_fingerprint: "local_path:/tmp/kiln-continuity-#{System.unique_integer([:positive])}",
      workspace_key: "workspace-continuity-#{System.unique_integer([:positive])}",
      workspace_path: "/tmp/kiln-workspace",
      base_branch: "main"
    }

    %AttachedRepo{}
    |> AttachedRepo.changeset(Map.merge(base_attrs, attrs))
    |> Repo.insert!()
  end
end
