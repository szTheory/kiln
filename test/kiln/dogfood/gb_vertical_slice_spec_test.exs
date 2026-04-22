defmodule Kiln.Dogfood.GbVerticalSliceSpecTest do
  use ExUnit.Case, async: true

  alias Kiln.Specs.ScenarioParser

  @spec_path Application.app_dir(:kiln, "priv/dogfood/gb_vertical_slice_spec.md")

  test "gb_vertical_slice_spec.md parses to three scenarios" do
    md = File.read!(@spec_path)
    assert {:ok, %{"scenarios" => scenarios}} = ScenarioParser.parse_document(md)
    assert length(scenarios) == 3

    ids = scenarios |> Enum.map(& &1["id"]) |> Enum.sort()
    assert ids == ["compile_gate", "mix_oracle_smoke", "scenario_runner_gate"]

    for s <- scenarios do
      steps = s["steps"]
      assert Enum.any?(steps, &(&1["kind"] == "shell"))
    end
  end
end
