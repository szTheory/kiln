defmodule Kiln.ModelRegistry.PresetsTest do
  @moduledoc """
  Cross-validation between the 6 D-57 presets and the 4-provider
  pricing tables: every model referenced by any preset (primary or
  fallback) MUST have a corresponding `Kiln.Pricing.estimate_usd/3`
  entry, otherwise `BudgetGuard` silently returns $0 on that model
  and the cost-runaway guardrail fails.

  Also asserts preset-shape invariants that would silently mask the
  tier-crossing telemetry contract if violated.
  """

  use ExUnit.Case, async: true

  describe "preset ↔ pricing cross-validation" do
    test "every preset model has a matching Kiln.Pricing entry" do
      for preset <- Kiln.ModelRegistry.all_presets() do
        mapping = Kiln.ModelRegistry.resolve(preset)

        for {role, spec} <- mapping do
          models = [spec.model | spec.fallback]

          for model <- models do
            assert Kiln.Pricing.known_model?(model),
                   "preset #{preset} role #{role} references unknown pricing for model #{model}"
          end
        end
      end
    end
  end

  describe "preset shape invariants" do
    test "every preset file loads cleanly via Code.eval_file/1" do
      presets_dir = Path.expand("../../../priv/model_registry", __DIR__)

      for preset <- Kiln.ModelRegistry.all_presets() do
        path = Path.join(presets_dir, "#{preset}.exs")
        assert File.exists?(path), "missing preset file #{path}"

        # eval returns {value, bindings} — we only need the first.
        {roles, _} = Code.eval_file(path)
        assert is_map(roles), "preset #{preset} file does not eval to a map"
        assert map_size(roles) == 7, "preset #{preset} does not declare all 7 D-57 roles"
      end
    end

    test "every preset declares :same_provider (D-107 P3 invariant)" do
      for preset <- Kiln.ModelRegistry.all_presets() do
        for {_role, spec} <- Kiln.ModelRegistry.resolve(preset) do
          assert spec.fallback_policy == :same_provider
        end
      end
    end
  end
end
