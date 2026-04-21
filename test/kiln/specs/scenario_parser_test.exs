defmodule Kiln.Specs.ScenarioParserTest do
  use ExUnit.Case, async: true

  alias Kiln.Specs.ScenarioParser

  test "parse_document/1 reads fixture with merged kiln-scenario blocks" do
    path = Path.expand("../../fixtures/specs/minimal_spec.md", __DIR__)
    md = File.read!(path)
    assert md =~ "kiln-scenario"

    assert {:ok, %{"scenarios" => scenarios}} = ScenarioParser.parse_document(md)
    assert length(scenarios) == 2
    ids = Enum.map(scenarios, & &1["id"]) |> Enum.sort()
    assert ids == ["smoke", "smoke-two"]
  end

  test "invalid YAML surfaces {:error, {:yaml_invalid, _}} with line hint" do
    bad = """
    ```kiln-scenario
    scenarios:
      - id: bad
        description: x
        steps:
          - kind: assert
            expect: [unclosed
    ```
    """

    assert {:error, {:yaml_invalid, info}} = ScenarioParser.parse_document(bad)
    assert is_map(info)
    assert Map.has_key?(info, :message)
    assert Map.has_key?(info, :line)
  end

  test "schema invalid after YAML merge" do
    bad = """
    ```kiln-scenario
    scenarios:
      - id: BAD_UPPER
        description: x
        steps:
          - kind: assert
            expect: "true"
    ```
    """

    assert {:error, {:schema_invalid, _}} = ScenarioParser.parse_document(bad)
  end
end
