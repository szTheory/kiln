defmodule Kiln.ModelRegistryTest do
  @moduledoc """
  Tests for `Kiln.ModelRegistry.resolve/2`, `next/3`, and `adapter_for/1`
  — the preset → role → model resolution surface (D-105..D-108 / OPS-03).
  """

  use ExUnit.Case, async: true

  alias Kiln.ModelRegistry

  @d57_roles [:planner, :coder, :tester, :reviewer, :ui_ux, :qa_verifier, :mayor]
  @d57_presets [
    :elixir_lib,
    :phoenix_saas_feature,
    :typescript_web_feature,
    :python_cli,
    :bugfix_critical,
    :docs_update
  ]

  describe "all_presets/0" do
    test "returns exactly the 6 D-57 presets" do
      assert Enum.sort(ModelRegistry.all_presets()) == Enum.sort(@d57_presets)
    end
  end

  describe "resolve/2" do
    test "all 6 presets resolve to a role-map" do
      for preset <- ModelRegistry.all_presets() do
        mapping = ModelRegistry.resolve(preset)
        assert is_map(mapping)
        assert map_size(mapping) > 0
      end
    end

    test "every preset carries all 7 D-57 roles" do
      for preset <- ModelRegistry.all_presets() do
        mapping = ModelRegistry.resolve(preset)

        for role <- @d57_roles do
          assert Map.has_key?(mapping, role),
                 "preset #{preset} missing role #{role}"
        end
      end
    end

    test "every role spec has :model, :fallback, :fallback_policy keys" do
      for preset <- ModelRegistry.all_presets() do
        mapping = ModelRegistry.resolve(preset)

        for {role, spec} <- mapping do
          assert is_binary(spec.model), "preset #{preset} role #{role} :model is not a string"
          assert is_list(spec.fallback), "preset #{preset} role #{role} :fallback is not a list"

          assert spec.fallback_policy in [:same_provider, :cross_provider],
                 "preset #{preset} role #{role} :fallback_policy invalid"
        end
      end
    end

    test "every role's fallback_policy is :same_provider in P3 (D-107)" do
      for preset <- ModelRegistry.all_presets() do
        for {role, spec} <- ModelRegistry.resolve(preset) do
          assert spec.fallback_policy == :same_provider,
                 "preset #{preset} role #{role} expected :same_provider, got #{spec.fallback_policy}"
        end
      end
    end

    test "stage_overrides replace preset entries for a given role" do
      override = %{
        coder: %{
          model: "claude-haiku-4-5-20250929",
          fallback: [],
          fallback_policy: :same_provider
        }
      }

      base = ModelRegistry.resolve(:elixir_lib)
      overridden = ModelRegistry.resolve(:elixir_lib, override)

      assert overridden.coder.model == "claude-haiku-4-5-20250929"
      assert overridden.coder.fallback == []
      # Non-overridden roles unchanged
      assert overridden.planner.model == base.planner.model
      assert overridden.mayor.model == base.mayor.model
    end

    test "bugfix_critical upgrades coder to Opus" do
      mapping = ModelRegistry.resolve(:bugfix_critical)
      assert mapping.coder.model == "claude-opus-4-5-20250929"
    end

    test "docs_update downgrades every role to Haiku" do
      mapping = ModelRegistry.resolve(:docs_update)

      for {_role, spec} <- mapping do
        assert spec.model == "claude-haiku-4-5-20250929"
      end
    end
  end

  describe "next/3" do
    test "returns the next model in the fallback chain" do
      # elixir_lib's planner chain is
      # ["claude-opus-4-5-20250929", "claude-sonnet-4-5-20250929", ...]
      assert {:ok, "claude-sonnet-4-5-20250929"} =
               ModelRegistry.next("claude-opus-4-5-20250929", :http_429, :elixir_lib)
    end

    test "returns {:exhausted, current} when chain is exhausted" do
      # docs_update has only Haiku and no fallback — Haiku is the
      # tail of the chain, so any call to next/3 with it exhausts.
      assert {:exhausted, "claude-haiku-4-5-20250929"} =
               ModelRegistry.next("claude-haiku-4-5-20250929", :http_429, :docs_update)
    end

    test "returns {:exhausted, current} when current is not in chain" do
      assert {:exhausted, "unknown-model"} =
               ModelRegistry.next("unknown-model", :http_429, :elixir_lib)
    end
  end

  describe "adapter_for/1" do
    test "routes claude-* to Anthropic" do
      assert ModelRegistry.adapter_for("claude-opus-4-5-20250929") ==
               Kiln.Agents.Adapter.Anthropic
    end

    test "routes gpt-* to OpenAI" do
      assert ModelRegistry.adapter_for("gpt-4o-mini") == Kiln.Agents.Adapter.OpenAI
    end

    test "routes gemini-* to Google" do
      assert ModelRegistry.adapter_for("gemini-2.5-flash") == Kiln.Agents.Adapter.Google
    end

    test "routes anything else to Ollama" do
      assert ModelRegistry.adapter_for("llama3.3:70b") == Kiln.Agents.Adapter.Ollama
      assert ModelRegistry.adapter_for("qwen2.5-coder:32b") == Kiln.Agents.Adapter.Ollama
    end
  end
end
