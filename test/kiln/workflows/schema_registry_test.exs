defmodule Kiln.Workflows.SchemaRegistryTest do
  use ExUnit.Case, async: true

  alias Kiln.Workflows.SchemaRegistry

  describe "kinds/0" do
    test "returns exactly [:workflow]" do
      assert SchemaRegistry.kinds() == [:workflow]
    end
  end

  describe "fetch/1" do
    test "returns {:ok, %JSV.Root{}} for :workflow" do
      assert {:ok, %JSV.Root{}} = SchemaRegistry.fetch(:workflow)
    end

    test "returns {:error, :unknown_kind} for an atom not in the registry" do
      assert {:error, :unknown_kind} = SchemaRegistry.fetch(:nonsense)
    end
  end

  describe "positive validation" do
    @tag :positive
    test "the minimal_two_stage fixture validates against the compiled workflow schema" do
      {:ok, root} = SchemaRegistry.fetch(:workflow)

      {:ok, raw} =
        YamlElixir.read_from_file("test/support/fixtures/workflows/minimal_two_stage.yaml")

      assert {:ok, _casted} = JSV.validate(raw, root)
    end
  end

  describe "negative validation caveats" do
    # The D-62 validators run OUTSIDE JSV (Kiln.Workflows.load!/1 bounded
    # checks). JSON Schema alone cannot express "signature must be null
    # across a null|object union" — the union accepts both shapes. The
    # loader's D-62 validator 6 asserts signature is nil at runtime.
    # See test/kiln/workflows/loader_test.exs (Plan 02-02+) for that gate.
    test "signature_populated fixture is accepted by JSV alone (D-62 v6 is a runtime gate)" do
      {:ok, root} = SchemaRegistry.fetch(:workflow)

      {:ok, raw} =
        YamlElixir.read_from_file("test/support/fixtures/workflows/signature_populated.yaml")

      # JSV's signature schema is `{"type": ["null", "object"]}`. A populated
      # object conforms. The v1 "must be null" invariant is enforced by the
      # Elixir-side D-62 validator 6, not by JSV. This test documents the
      # boundary so a future reader does not assume JSV alone is sufficient.
      assert {:ok, _casted} = JSV.validate(raw, root)
    end
  end
end
