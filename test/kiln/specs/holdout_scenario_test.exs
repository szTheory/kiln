defmodule Kiln.Specs.HoldoutScenarioTest do
  use Kiln.DataCase, async: true

  alias Kiln.Repo
  alias Kiln.Specs
  alias Kiln.Specs.HoldoutScenario

  test "insert holdout linked to spec" do
    {:ok, spec} = Specs.create_spec(%{title: "With holdouts"})

    assert {:ok, row} =
             %HoldoutScenario{}
             |> HoldoutScenario.changeset(%{
               spec_id: spec.id,
               label: "golden",
               body: "Given...\nWhen...\nThen...\n"
             })
             |> Repo.insert()

    assert row.label == "golden"
  end

  test "label unique per spec" do
    {:ok, spec} = Specs.create_spec(%{title: "U"})

    attrs = %{spec_id: spec.id, label: "dup", body: "a"}

    assert {:ok, _} =
             %HoldoutScenario{}
             |> HoldoutScenario.changeset(attrs)
             |> Repo.insert()

    dup =
      %HoldoutScenario{}
      |> HoldoutScenario.changeset(attrs)
      |> Repo.insert()

    assert {:error, changeset} = dup
    assert %{spec_id: ["has already been taken"]} = errors_on(changeset)
  end
end
