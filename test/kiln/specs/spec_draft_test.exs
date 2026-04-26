defmodule Kiln.Specs.SpecDraftTest do
  use Kiln.DataCase, async: true

  import Ecto.Query

  alias Kiln.Audit.Event
  alias Kiln.Specs

  describe "create_draft/1 and list_open_drafts/0" do
    test "creates an open draft and lists it" do
      assert {:ok, d} =
               Specs.create_draft(%{
                 title: "T",
                 body: "B",
                 source: :freeform
               })

      assert d.inbox_state == :open
      open_drafts = Enum.filter(Specs.list_open_drafts(), &(&1.id == d.id))
      assert [listed] = open_drafts
      assert listed.id == d.id
    end
  end

  describe "archive_draft/1" do
    test "archives an open draft" do
      {:ok, d} =
        Specs.create_draft(%{title: "T", body: "B", source: :freeform})

      assert {:ok, archived} = Specs.archive_draft(d.id)
      assert archived.inbox_state == :archived
      assert archived.archived_at
      refute Enum.any?(Specs.list_open_drafts(), &(&1.id == d.id))
    end

    test "returns error for non-open draft" do
      {:ok, d} =
        Specs.create_draft(%{title: "T", body: "B", source: :freeform})

      assert {:ok, _} = Specs.archive_draft(d.id)
      assert {:error, :invalid_state} = Specs.archive_draft(d.id)
    end
  end

  describe "promote_draft/1" do
    test "promotes open draft, creates spec + revision + audit" do
      {:ok, d} =
        Specs.create_draft(%{title: "My title", body: "## Spec\n", source: :freeform})

      assert {:ok, %{draft: promoted, spec: spec, revision: rev}} =
               Specs.promote_draft(d.id)

      assert promoted.inbox_state == :promoted
      assert promoted.promoted_spec_id == spec.id
      assert rev.spec_id == spec.id
      assert rev.body == d.body
      assert spec.title == d.title

      assert {:error, :invalid_state} = Specs.promote_draft(d.id)

      assert [%Event{event_kind: :spec_draft_promoted}] =
               from(e in Event, where: e.event_kind == :spec_draft_promoted, select: e)
               |> Repo.all()
    end

    test "cannot promote archived draft" do
      {:ok, d} =
        Specs.create_draft(%{title: "T", body: "B", source: :freeform})

      assert {:ok, _} = Specs.archive_draft(d.id)
      assert {:error, :invalid_state} = Specs.promote_draft(d.id)
    end
  end
end
