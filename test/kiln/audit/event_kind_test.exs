defmodule Kiln.Audit.EventKindTest do
  use ExUnit.Case, async: true

  alias Kiln.Audit.EventKind

  describe "values/0" do
    test "contains exactly 22 kinds (D-08 taxonomy lock at P1)" do
      assert length(EventKind.values()) == 22
    end

    test "every element is an atom" do
      assert Enum.all?(EventKind.values(), &is_atom/1)
    end
  end

  describe "values_as_strings/0" do
    test "matches values/0 1-to-1 in order" do
      assert length(EventKind.values_as_strings()) == length(EventKind.values())

      Enum.zip(EventKind.values(), EventKind.values_as_strings())
      |> Enum.each(fn {atom, str} ->
        assert Atom.to_string(atom) == str
      end)
    end
  end

  describe "valid?/1" do
    test "accepts atoms inside the taxonomy" do
      assert EventKind.valid?(:stage_started)
      assert EventKind.valid?(:escalation_triggered)
    end

    test "accepts string forms inside the taxonomy" do
      assert EventKind.valid?("stage_started")
      assert EventKind.valid?("escalation_triggered")
    end

    test "rejects unknown atoms" do
      refute EventKind.valid?(:not_a_kind)
    end

    test "rejects unknown strings" do
      refute EventKind.valid?("not_a_kind")
    end
  end
end
