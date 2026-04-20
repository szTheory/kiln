defmodule Kiln.Blockers.PlaybookRegistryTest do
  use ExUnit.Case, async: true
  alias Kiln.Blockers.{PlaybookRegistry, Playbook, Reason}

  describe "fetch/1" do
    test "every Reason atom resolves to a Playbook" do
      for reason <- Reason.all() do
        assert {:ok, %Playbook{reason: ^reason}} = PlaybookRegistry.fetch(reason)
      end
    end

    test "unknown reason returns :error" do
      assert {:error, :unknown_reason} = PlaybookRegistry.fetch(:nope)
    end
  end

  describe "render/2 — Mustache substitution" do
    test "substitutes {provider} and {run_id} in short_message and title" do
      {:ok, rp} =
        PlaybookRegistry.render(:missing_api_key, %{
          provider: "anthropic",
          run_id: "run-abc",
          provider_env_var: "ANTHROPIC_API_KEY"
        })

      assert rp.title =~ "anthropic"
      assert rp.short_message =~ "anthropic"
      refute rp.short_message =~ "{provider}"
    end

    test "preserves unsubstituted tokens for missing context keys" do
      {:ok, rp} = PlaybookRegistry.render(:missing_api_key, %{})
      assert rp.short_message =~ "{provider}"
    end
  end

  describe "stub playbooks" do
    for reason <- [:gh_auth_expired, :gh_permissions_insufficient, :unrecoverable_stage_failure] do
      test "#{reason} carries stub: true frontmatter" do
        {:ok, pb} = PlaybookRegistry.fetch(unquote(reason))
        assert pb.frontmatter["stub"] == true
      end
    end

    for reason <- [
          :missing_api_key,
          :invalid_api_key,
          :rate_limit_exhausted,
          :quota_exceeded,
          :budget_exceeded,
          :policy_violation
        ] do
      test "#{reason} is REAL (not stub)" do
        {:ok, pb} = PlaybookRegistry.fetch(unquote(reason))
        refute pb.frontmatter["stub"] == true
      end
    end
  end
end
