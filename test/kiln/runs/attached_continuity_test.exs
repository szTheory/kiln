defmodule Kiln.Runs.AttachedContinuityTest do
  use Kiln.DataCase, async: true

  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.Intake
  alias Kiln.Runs
  alias Kiln.Specs

  test "get_for_attached_repo/2 only returns runs linked to the same attached repo and preloads continuity data" do
    attached_repo =
      attached_repo_fixture(%{
        source_fingerprint: "local_path:/tmp/kiln-runs-continuity-a",
        workspace_key: "workspace-runs-continuity-a"
      })

    other_repo =
      attached_repo_fixture(%{
        source_fingerprint: "local_path:/tmp/kiln-runs-continuity-b",
        workspace_key: "workspace-runs-continuity-b",
        repo_slug: "jon/other"
      })

    promoted_request = promoted_attached_request_fixture(attached_repo.id, "Fetch one linked run")
    other_request = promoted_attached_request_fixture(other_repo.id, "Ignore other repo runs")

    assert {:ok, run} = Runs.create_for_attached_request(promoted_request, attached_repo.id)
    assert {:ok, other_run} = Runs.create_for_attached_request(other_request, other_repo.id)

    stored = Runs.get_for_attached_repo(attached_repo.id, run.id)

    assert stored.id == run.id
    assert stored.spec.id == promoted_request.spec.id
    assert stored.spec_revision.id == promoted_request.revision.id
    assert Runs.get_for_attached_repo(attached_repo.id, other_run.id) == nil
  end

  test "list_recent_for_attached_repo/2 returns newest-first runs with spec continuity preloads" do
    attached_repo = attached_repo_fixture()

    older_request = promoted_attached_request_fixture(attached_repo.id, "Older continuity run")
    newer_request = promoted_attached_request_fixture(attached_repo.id, "Newer continuity run")

    assert {:ok, older_run} = Runs.create_for_attached_request(older_request, attached_repo.id)
    assert {:ok, newer_run} = Runs.create_for_attached_request(newer_request, attached_repo.id)

    recent = Runs.list_recent_for_attached_repo(attached_repo.id, limit: 2)

    assert Enum.map(recent, & &1.id) == [newer_run.id, older_run.id]
    assert hd(recent).spec.id == newer_request.spec.id
    assert hd(recent).spec_revision.id == newer_request.revision.id
    assert List.last(recent).spec.id == older_request.spec.id
  end

  defp promoted_attached_request_fixture(attached_repo_id, title) do
    assert {:ok, draft} =
             Intake.create_draft(attached_repo_id, %{
               "request_kind" => "feature",
               "title" => title,
               "change_summary" => "Support repeat-run continuity reads.",
               "acceptance_criteria" => ["continuity can recover prior request context"]
             })

    assert {:ok, promoted_request} = Specs.promote_draft(draft.id)
    promoted_request
  end

  defp attached_repo_fixture(attrs \\ %{}) do
    base_attrs = %{
      source_kind: :local_path,
      repo_provider: :local,
      repo_name: "kiln",
      repo_slug: "jon/kiln",
      canonical_input: "/tmp/kiln",
      canonical_repo_root: "/tmp/kiln",
      source_fingerprint:
        "local_path:/tmp/kiln-runs-continuity-#{System.unique_integer([:positive])}",
      workspace_key: "workspace-runs-continuity-#{System.unique_integer([:positive])}",
      workspace_path: "/tmp/kiln-workspace",
      base_branch: "main"
    }

    %AttachedRepo{}
    |> AttachedRepo.changeset(Map.merge(base_attrs, attrs))
    |> Repo.insert!()
  end
end
