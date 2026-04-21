defmodule Kiln.Audit.EventKindTest do
  use ExUnit.Case, async: true

  alias Kiln.Audit.EventKind

  # Phase 3 D-145 extension atoms — appended to the @kinds list after
  # the 3 Phase 2 D-85 atoms. `:model_routing_fallback` is NOT in this
  # list because it was already declared in Phase 1's 22-kind block.
  @p3_new_kinds [
    :orphan_container_swept,
    :dtu_contract_drift_detected,
    :dtu_health_degraded,
    :factory_circuit_opened,
    :factory_circuit_closed,
    :model_deprecated_resolved,
    :notification_fired,
    :notification_suppressed
  ]

  describe "values/0" do
    test "contains exactly 35 kinds (22 P1 + 3 P2 D-85 + 8 P3 D-145 + 2 P8)" do
      assert length(EventKind.values()) == 35
    end

    test "every element is an atom" do
      assert Enum.all?(EventKind.values(), &is_atom/1)
    end

    test "includes the 3 D-85 Phase 2 extensions" do
      assert :stage_input_rejected in EventKind.values()
      assert :artifact_written in EventKind.values()
      assert :integrity_violation in EventKind.values()
    end

    test "includes all 8 D-145 Phase 3 extensions" do
      for kind <- @p3_new_kinds do
        assert kind in EventKind.values(), "missing P3 kind: #{inspect(kind)}"
      end
    end

    test "preserves append-only ordering: P2 D-85 atoms precede P3 D-145 atoms; P8 appends last" do
      # After Phase 3: the last 8 kinds before any Phase-8 tail MUST be the D-145
      # additions. Phase 8 appends `:spec_draft_promoted` then `:follow_up_drafted`.
      values = EventKind.values()
      assert List.last(values) == :follow_up_drafted

      last_p3_block = values |> Enum.drop(-2) |> Enum.take(-8)
      assert last_p3_block == @p3_new_kinds

      three_before_p3_block = values |> Enum.take(-13) |> Enum.take(3)

      assert three_before_p3_block == [
               :stage_input_rejected,
               :artifact_written,
               :integrity_violation
             ]
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

    test "includes the 8 Phase 3 D-145 string forms" do
      strs = EventKind.values_as_strings()

      for kind <- @p3_new_kinds do
        assert Atom.to_string(kind) in strs,
               "missing P3 string: #{Atom.to_string(kind)}"
      end
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

    test "accepts the 8 Phase 3 D-145 atoms and their string forms" do
      for kind <- @p3_new_kinds do
        assert EventKind.valid?(kind), "rejected P3 atom: #{inspect(kind)}"

        assert EventKind.valid?(Atom.to_string(kind)),
               "rejected P3 string: #{Atom.to_string(kind)}"
      end
    end

    test "rejects unknown atoms" do
      refute EventKind.valid?(:not_a_kind)
    end

    test "rejects unknown strings" do
      refute EventKind.valid?("not_a_kind")
    end
  end
end
