defmodule Kiln.Specs.SpecRevisionTest do
  use Kiln.DataCase, async: true

  alias Kiln.Specs
  alias Kiln.Specs.SpecRevision

  test "create_spec + create_revision persists body and optional manifest" do
    assert {:ok, spec} = Specs.create_spec(%{title: "Auth API"})
    assert {:ok, rev} = Specs.create_revision(spec, %{body: "# Spec\n"})

    loaded = Specs.get_revision!(rev.id)
    assert loaded.body == "# Spec\n"
    assert loaded.scenario_manifest_sha256 == nil
  end

  test "manifest hash must be valid sha256 hex when present" do
    {:ok, spec} = Specs.create_spec(%{title: "T"})

    bad =
      %SpecRevision{}
      |> SpecRevision.changeset(%{
        spec_id: spec.id,
        body: "x",
        scenario_manifest_sha256: "not-hex"
      })

    assert %{scenario_manifest_sha256: [_]} = errors_on(bad)

    hex = String.duplicate("a", 64)

    assert {:ok, _} =
             %SpecRevision{}
             |> SpecRevision.changeset(%{
               spec_id: spec.id,
               body: "x",
               scenario_manifest_sha256: hex
             })
             |> Kiln.Repo.insert()
  end
end
