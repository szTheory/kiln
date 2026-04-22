defmodule Kiln.Specs.TemplateInstantiateTest do
  use Kiln.DataCase, async: true

  import Ecto.Query

  alias Kiln.Audit.Event
  alias Kiln.Runs
  alias Kiln.Specs

  test "instantiate_template_promoted/1 promotes hello-kiln and audits template_id" do
    assert {:ok, %{spec: spec, revision: rev}} =
             Specs.instantiate_template_promoted("hello-kiln")

    assert spec.title == "Hello Kiln"
    assert rev.spec_id == spec.id
    assert rev.body =~ "Hello Kiln"

    assert [audit] =
             from(e in Event,
               where: e.event_kind == :spec_draft_promoted,
               order_by: [desc: e.inserted_at],
               limit: 1,
               select: e
             )
             |> Repo.all()

    assert %{"template_id" => "hello-kiln"} = audit.payload
  end

  test "instantiate_template_promoted/1 returns unknown_template for bogus ids" do
    assert {:error, :unknown_template} =
             Specs.instantiate_template_promoted("not-a-real-template")
  end

  test "create_for_promoted_template/2 inserts a queued run with workflow checksum" do
    assert {:ok, %{spec: spec}} = Specs.instantiate_template_promoted("hello-kiln")

    assert {:ok, run} = Runs.create_for_promoted_template(spec, "hello-kiln")
    assert run.state == :queued
    assert run.workflow_id == "elixir_phoenix_feature"
    assert {:ok, _} = Runs.workflow_checksum(run.id)
    assert String.length(run.workflow_checksum) == 64
  end

  test "promote_draft/2 records template_id on audit payload" do
    {:ok, d} =
      Specs.create_draft(%{
        title: "T",
        body: "B",
        source: :freeform
      })

    assert {:ok, %{spec: spec}} = Specs.promote_draft(d.id, template_id: "markdown-spec-stub")

    assert spec.title == "T"

    assert %{"template_id" => "markdown-spec-stub"} =
             from(e in Event,
               where: e.event_kind == :spec_draft_promoted,
               order_by: [desc: e.inserted_at],
               limit: 1,
               select: e.payload
             )
             |> Repo.one()
  end
end
