defmodule Kiln.Blockers.ReasonTest do
  use ExUnit.Case, async: true
  alias Kiln.Blockers.Reason
  require Kiln.Blockers.Reason

  @blocking_expected [
    :missing_api_key,
    :invalid_api_key,
    :rate_limit_exhausted,
    :quota_exceeded,
    :budget_exceeded,
    :policy_violation,
    :gh_auth_expired,
    :gh_permissions_insufficient,
    :unrecoverable_stage_failure
  ]

  @all_expected @blocking_expected ++ [:budget_threshold_50, :budget_threshold_80]

  test "all/0 returns exactly 11 atoms (9 blocking + 2 advisory)" do
    assert Enum.sort(Reason.all()) == Enum.sort(@all_expected)
    assert length(Reason.all()) == 11
  end

  test "blocking?/1 is true for halt reasons and false for advisory atoms" do
    for r <- @blocking_expected do
      assert Reason.blocking?(r), "expected blocking #{inspect(r)}"
    end

    refute Reason.blocking?(:budget_threshold_50)
    refute Reason.blocking?(:budget_threshold_80)
  end

  test "valid?/1 accepts every enum member" do
    for r <- @all_expected, do: assert(Reason.valid?(r))
  end

  test "valid?/1 rejects arbitrary atoms + non-atoms" do
    refute Reason.valid?(:totally_random)
    refute Reason.valid?("missing_api_key")
    refute Reason.valid?(42)
    refute Reason.valid?(nil)
  end

  test "is_reason/1 guard matches every enum member" do
    for r <- @all_expected do
      assert guarded(r) == :ok, "guard rejected #{inspect(r)}"
    end
  end

  test "is_reason/1 guard rejects non-members" do
    assert guarded(:not_a_reason) == :no
  end

  defp guarded(r) when Kiln.Blockers.Reason.is_reason(r), do: :ok
  defp guarded(_), do: :no

  test "BlockedError exception renders reason + run_id + context" do
    err =
      Kiln.Blockers.BlockedError.exception(
        reason: :missing_api_key,
        run_id: "run-abc",
        context: %{provider: :anthropic}
      )

    assert %Kiln.Blockers.BlockedError{reason: :missing_api_key, run_id: "run-abc"} = err
    assert err.message =~ "missing_api_key"
    assert err.message =~ "run-abc"
  end

  test "playbook.json schema loads and validates a minimal entry" do
    schema_path = "priv/playbook_schemas/v1/playbook.json"
    assert File.exists?(schema_path)
    raw = Jason.decode!(File.read!(schema_path))
    root = JSV.build!(raw, default_meta: "https://json-schema.org/draft/2020-12/schema")

    valid = %{
      "reason" => "missing_api_key",
      "severity" => "halt",
      "short_message" => "Provider API key is missing.",
      "title" => "Missing API key",
      "remediation_commands" => [
        %{"label" => "Set the key", "command" => "export ANTHROPIC_API_KEY=..."}
      ],
      "next_action_on_resolve" => "resume_run",
      "owning_phase" => 3
    }

    assert {:ok, _} = JSV.validate(valid, root)
  end

  test "playbook.json accepts advisory budget_threshold_50 entry" do
    schema_path = "priv/playbook_schemas/v1/playbook.json"
    raw = Jason.decode!(File.read!(schema_path))
    root = JSV.build!(raw, default_meta: "https://json-schema.org/draft/2020-12/schema")

    valid = %{
      "reason" => "budget_threshold_50",
      "severity" => "warn",
      "short_message" => "Spend is about {pct}% of the frozen cap. The run continues.",
      "title" => "Budget notice: half of run cap reached ({run_id})",
      "remediation_commands" => [
        %{
          "label" => "Review run detail",
          "command" => "open http://localhost:4000/ops/runs/{run_id}"
        }
      ],
      "next_action_on_resolve" => "resume_run",
      "owning_phase" => 18
    }

    assert {:ok, _} = JSV.validate(valid, root)
  end
end
