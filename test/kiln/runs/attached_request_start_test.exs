defmodule Kiln.Runs.AttachedRequestStartTest do
  use Kiln.DataCase, async: true

  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.Intake
  alias Kiln.OperatorReadiness
  alias Kiln.Runs
  alias Kiln.Runs.Run
  alias Kiln.Secrets
  alias Kiln.Specs

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

  test "create_for_attached_request/2 persists attached_repo_id, spec_id, and spec_revision_id" do
    attached_repo = attached_repo_fixture()
    promoted_request = promoted_attached_request_fixture(attached_repo.id)

    assert {:ok, run} = Runs.create_for_attached_request(promoted_request, attached_repo.id)

    assert run.state == :queued
    assert run.attached_repo_id == attached_repo.id
    assert run.spec_id == promoted_request.spec.id
    assert run.spec_revision_id == promoted_request.revision.id
  end

  test "start_for_attached_request/3 returns the same typed blocked return when setup is missing" do
    attached_repo = attached_repo_fixture()
    promoted_request = promoted_attached_request_fixture(attached_repo.id)

    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, false)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, false)

    assert {:blocked,
            %{
              reason: :factory_not_ready,
              blocker: %{id: :anthropic, href: "/settings#settings-item-anthropic"},
              settings_target: "/settings?return_to=%2Fattach#settings-item-anthropic"
            }} =
             Runs.start_for_attached_request(promoted_request, attached_repo.id,
               return_to: "/attach"
             )
  end

  test "create_for_attached_request/2 loads the shipped workflow and records its checksum" do
    attached_repo = attached_repo_fixture()
    promoted_request = promoted_attached_request_fixture(attached_repo.id)

    assert {:ok, run} = Runs.create_for_attached_request(promoted_request, attached_repo.id)

    assert run.workflow_id == "elixir_phoenix_feature"
    assert String.length(run.workflow_checksum) == 64
    assert {:ok, checksum} = Runs.workflow_checksum(run.id)
    assert checksum == run.workflow_checksum
  end

  test "start_for_attached_request/3 deletes the queued run when provider credentials are missing" do
    attached_repo = attached_repo_fixture()
    promoted_request = promoted_attached_request_fixture(attached_repo.id)
    count_before = Repo.aggregate(Run, :count)

    :ok = Secrets.put(:anthropic_api_key, nil)

    assert {:error, :missing_api_key} =
             Runs.start_for_attached_request(promoted_request, attached_repo.id)

    assert Repo.aggregate(Run, :count) == count_before
  end

  defp promoted_attached_request_fixture(attached_repo_id) do
    assert {:ok, draft} =
             Intake.create_draft(attached_repo_id, %{
               "request_kind" => "feature",
               "title" => "Persist attach-aware launches",
               "change_summary" => "Start bounded attached work through the Runs context.",
               "acceptance_criteria" => ["persists attached_repo_id", "workflow checksum matches"]
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
      source_fingerprint: "local_path:/tmp/kiln-runs-#{System.unique_integer([:positive])}",
      workspace_key: "workspace-runs-#{System.unique_integer([:positive])}",
      workspace_path: "/tmp/kiln-workspace",
      base_branch: "main"
    }

    %AttachedRepo{}
    |> AttachedRepo.changeset(Map.merge(base_attrs, attrs))
    |> Repo.insert!()
  end
end
