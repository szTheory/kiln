defmodule Kiln.Stages.ContractRegistryTest do
  use ExUnit.Case, async: true

  alias Kiln.Stages.ContractRegistry

  @all_kinds [:planning, :coding, :testing, :verifying, :merge]

  describe "kinds/0" do
    test "returns the canonical 5 stage kinds in order" do
      assert ContractRegistry.kinds() == @all_kinds
    end
  end

  describe "fetch/1" do
    for kind <- @all_kinds do
      test "returns {:ok, %JSV.Root{}} for #{inspect(kind)}" do
        assert {:ok, %JSV.Root{}} = ContractRegistry.fetch(unquote(kind))
      end
    end

    test "returns {:error, :unknown_kind} for an atom not in the registry" do
      assert {:error, :unknown_kind} = ContractRegistry.fetch(:bogus)
    end
  end

  describe "smoke validation against a hand-crafted envelope" do
    test "a well-formed planning envelope validates against the planning contract" do
      {:ok, root} = ContractRegistry.fetch(:planning)

      envelope = %{
        "run_id" => "00000000-0000-0000-0000-000000000001",
        "stage_run_id" => "00000000-0000-0000-0000-000000000002",
        "attempt" => 1,
        "spec_ref" => %{
          "sha256" => String.duplicate("a", 64),
          "size_bytes" => 1024,
          "content_type" => "text/markdown"
        },
        "budget_remaining" => %{
          "tokens_usd" => 0.5,
          "tokens" => 10_000,
          "elapsed_seconds" => 30
        },
        "model_profile_snapshot" => %{
          "role" => "planner",
          "requested_model" => "sonnet-class",
          "fallback_chain" => ["haiku-class", "opus-class"]
        },
        "holdout_excluded" => true,
        "last_diagnostic_ref" => nil
      }

      assert {:ok, _casted} = JSV.validate(envelope, root)
    end

    test "missing required fields fail validation at the boundary" do
      {:ok, root} = ContractRegistry.fetch(:coding)
      bad = %{"run_id" => "00000000-0000-0000-0000-000000000001"}

      assert {:error, %JSV.ValidationError{}} = JSV.validate(bad, root)
    end

    test "verifying accepts holdout_excluded: false (the one kind that may opt in)" do
      {:ok, root} = ContractRegistry.fetch(:verifying)

      envelope = %{
        "run_id" => "00000000-0000-0000-0000-000000000001",
        "stage_run_id" => "00000000-0000-0000-0000-000000000002",
        "attempt" => 1,
        "spec_ref" => %{
          "sha256" => String.duplicate("a", 64),
          "size_bytes" => 1024,
          "content_type" => "text/markdown"
        },
        "budget_remaining" => %{
          "tokens_usd" => 0.5,
          "tokens" => 10_000,
          "elapsed_seconds" => 30
        },
        "model_profile_snapshot" => %{
          "role" => "qa_verifier",
          "requested_model" => "sonnet-class",
          "fallback_chain" => []
        },
        "holdout_excluded" => false,
        "test_output_ref" => %{
          "sha256" => String.duplicate("b", 64),
          "size_bytes" => 2048,
          "content_type" => "text/plain"
        }
      }

      assert {:ok, _casted} = JSV.validate(envelope, root)
    end

    test "planning rejects holdout_excluded: false (must be const true)" do
      {:ok, root} = ContractRegistry.fetch(:planning)

      envelope = %{
        "run_id" => "00000000-0000-0000-0000-000000000001",
        "stage_run_id" => "00000000-0000-0000-0000-000000000002",
        "attempt" => 1,
        "spec_ref" => %{
          "sha256" => String.duplicate("a", 64),
          "size_bytes" => 1024,
          "content_type" => "text/markdown"
        },
        "budget_remaining" => %{
          "tokens_usd" => 0.5,
          "tokens" => 10_000,
          "elapsed_seconds" => 30
        },
        "model_profile_snapshot" => %{
          "role" => "planner",
          "requested_model" => "sonnet-class",
          "fallback_chain" => []
        },
        "holdout_excluded" => false,
        "last_diagnostic_ref" => nil
      }

      assert {:error, %JSV.ValidationError{}} = JSV.validate(envelope, root)
    end
  end
end
