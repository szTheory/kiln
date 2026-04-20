defmodule Kiln.Audit.EventKindTest do
  use ExUnit.Case, async: true

  alias Kiln.Audit.EventKind

  describe "values/0" do
    test "contains exactly 25 kinds (D-08 Phase 1 taxonomy + D-85 Phase 2 extension)" do
      assert length(EventKind.values()) == 25
    end

    test "every element is an atom" do
      assert Enum.all?(EventKind.values(), &is_atom/1)
    end

    test "includes the 3 D-85 Phase 2 extensions" do
      assert :stage_input_rejected in EventKind.values()
      assert :artifact_written in EventKind.values()
      assert :integrity_violation in EventKind.values()
    end

    test "preserves the Phase 1 append-only ordering (new kinds at the end)" do
      # The last 3 kinds in the list MUST be the Phase 2 D-85 additions,
      # in declaration order. Reordering breaks the CHECK-constraint
      # migration contract (the Phase 1 `down/0` hard-codes the original 22).
      last_three = EventKind.values() |> Enum.take(-3)
      assert last_three == [:stage_input_rejected, :artifact_written, :integrity_violation]
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

    test "includes the 3 Phase 2 D-85 string forms" do
      strs = EventKind.values_as_strings()
      assert "stage_input_rejected" in strs
      assert "artifact_written" in strs
      assert "integrity_violation" in strs
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

    test "accepts the 3 Phase 2 D-85 atoms" do
      assert EventKind.valid?(:stage_input_rejected)
      assert EventKind.valid?(:artifact_written)
      assert EventKind.valid?(:integrity_violation)
    end

    test "accepts the 3 Phase 2 D-85 strings" do
      assert EventKind.valid?("stage_input_rejected")
      assert EventKind.valid?("artifact_written")
      assert EventKind.valid?("integrity_violation")
    end

    test "rejects unknown atoms" do
      refute EventKind.valid?(:not_a_kind)
    end

    test "rejects unknown strings" do
      refute EventKind.valid?("not_a_kind")
    end
  end
end
