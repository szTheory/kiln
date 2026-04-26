defmodule Kiln.Integration.AttachedRepoIntakeTest do
  @moduledoc false

  use Kiln.ObanCase, async: false

  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.Intake
  alias Kiln.OperatorReadiness
  alias Kiln.Runs
  alias Kiln.Runs.Run
  alias Kiln.Secrets
  alias Kiln.Specs

  @moduletag :integration

  setup do
    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, true)
    :ok = Secrets.put(:anthropic_api_key, "test-key")

    on_exit(fn ->
      :ok = Secrets.put(:anthropic_api_key, nil)
    end)

    :ok
  end

  test "Attach.Intake -> promote_draft -> start_for_attached_request creates one durable attached run" do
    attached_repo = attached_repo_fixture()

    assert {:ok, draft} =
             Intake.create_draft(attached_repo.id, %{
               "request_kind" => "feature",
               "title" => "Start one attached-repo run",
               "change_summary" => "Promote the bounded request and launch through Kiln.Runs.",
               "acceptance_criteria" => ["one durable attached run"]
             })

    assert {:ok, promoted_request} = Specs.promote_draft(draft.id)

    assert {:ok, run} =
             Runs.start_for_attached_request(promoted_request, attached_repo.id,
               return_to: "/attach"
             )

    stored = Repo.get!(Run, run.id)

    assert run.state in [:queued, :planning]
    assert stored.state in [:queued, :planning]
    assert stored.attached_repo_id == attached_repo.id
    assert stored.spec_id == promoted_request.spec.id
    assert stored.spec_revision_id == promoted_request.revision.id
  end

  test "repeated start_for_attached_request/3 calls never create an unlinked run shape" do
    attached_repo = attached_repo_fixture()
    promoted_request = promoted_attached_request_fixture(attached_repo.id)

    assert {:ok, first_run} =
             Runs.start_for_attached_request(promoted_request, attached_repo.id,
               return_to: "/attach"
             )

    assert {:ok, second_run} =
             Runs.start_for_attached_request(promoted_request, attached_repo.id,
               return_to: "/attach"
             )

    linked_runs =
      from(r in Run,
        where:
          r.id in ^[first_run.id, second_run.id] and
            r.attached_repo_id == ^attached_repo.id and
            r.spec_id == ^promoted_request.spec.id and
            r.spec_revision_id == ^promoted_request.revision.id
      )
      |> Repo.all()

    unlinked_runs =
      from(r in Run,
        where: r.id in ^[first_run.id, second_run.id],
        where: is_nil(r.attached_repo_id) or is_nil(r.spec_id) or is_nil(r.spec_revision_id)
      )
      |> Repo.all()

    assert Enum.sort(Enum.map(linked_runs, & &1.id)) == Enum.sort([first_run.id, second_run.id])
    assert unlinked_runs == []
  end

  defp promoted_attached_request_fixture(attached_repo_id) do
    assert {:ok, draft} =
             Intake.create_draft(attached_repo_id, %{
               "request_kind" => "bugfix",
               "title" => "Keep attach linkage on repeat starts",
               "change_summary" =>
                 "Repeated launches must stay linked to the same promoted request.",
               "acceptance_criteria" => ["run linkage stays explicit"]
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
        "local_path:/tmp/kiln-integration-#{System.unique_integer([:positive])}",
      workspace_key: "workspace-integration-#{System.unique_integer([:positive])}",
      workspace_path: "/tmp/kiln-workspace",
      base_branch: "main"
    }

    %AttachedRepo{}
    |> AttachedRepo.changeset(Map.merge(base_attrs, attrs))
    |> Repo.insert!()
  end
end
