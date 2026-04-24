defmodule Kiln.Attach.IntakeTest do
  use Kiln.DataCase, async: true

  alias Kiln.Attach
  alias Kiln.Attach.AttachedRepo
  alias Kiln.Attach.Intake
  alias Kiln.Attach.IntakeRequest

  describe "IntakeRequest.changeset/2" do
    test "rejects missing request_kind, blank title, blank change_summary, and empty acceptance_criteria" do
      changeset =
        IntakeRequest.changeset(%IntakeRequest{}, %{
          "title" => "   ",
          "change_summary" => "\n",
          "acceptance_criteria" => ["", "  "],
          "out_of_scope" => [""]
        })

      assert %{
               request_kind: ["can't be blank"],
               title: ["can't be blank"],
               change_summary: ["can't be blank"],
               acceptance_criteria: ["must include at least one item"]
             } = errors_on(changeset)
    end
  end

  describe "create_draft/2" do
    test "attached_repo_id does not resolve through Kiln.Attach.get_attached_repo/1" do
      assert {:error, :not_found} =
               Intake.create_draft(Ecto.UUID.generate(), valid_request_attrs())
    end

    test "trims empty list entries from acceptance_criteria and out_of_scope before persistence" do
      attached_repo = attached_repo_fixture()

      assert {:ok, draft} =
               Intake.create_draft(attached_repo.id, %{
                 "request_kind" => "feature",
                 "title" => "Add repo intake",
                 "change_summary" => "Capture a bounded request before launch.",
                 "acceptance_criteria" => [
                   "Shows required fields",
                   "",
                   "  ",
                   "Persists the request"
                 ],
                 "out_of_scope" => ["", "  ", "Repeat-run continuity"]
               })

      assert draft.title == "Add repo intake"
      assert draft.body =~ "- Shows required fields"
      assert draft.body =~ "- Persists the request"
      assert draft.body =~ "- Repeat-run continuity"
      refute draft.body =~ "\n- \n"
      assert {:ok, ^attached_repo} = Attach.get_attached_repo(attached_repo.id)
    end
  end

  defp attached_repo_fixture(attrs \\ %{}) do
    base_attrs = %{
      source_kind: :local_path,
      repo_provider: :local,
      repo_name: "kiln",
      repo_slug: "jon/kiln",
      canonical_input: "/tmp/kiln",
      canonical_repo_root: "/tmp/kiln",
      source_fingerprint: "local_path:/tmp/kiln-#{System.unique_integer([:positive])}",
      workspace_key: "workspace-#{System.unique_integer([:positive])}",
      workspace_path: "/tmp/kiln-workspace",
      base_branch: "main"
    }

    %AttachedRepo{}
    |> AttachedRepo.changeset(Map.merge(base_attrs, attrs))
    |> Repo.insert!()
  end

  defp valid_request_attrs do
    %{
      "request_kind" => "feature",
      "title" => "Bounded request",
      "change_summary" => "Implement one PR-sized change.",
      "acceptance_criteria" => ["One acceptance criterion"]
    }
  end
end
