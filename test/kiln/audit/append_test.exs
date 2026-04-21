defmodule Kiln.AuditTest do
  use Kiln.DataCase, async: true

  alias Kiln.Audit
  alias Kiln.Audit.EventKind

  describe "append/1 — valid payloads" do
    test "run_state_transitioned with minimal valid payload inserts" do
      cid = Ecto.UUID.generate()

      assert {:ok, event} =
               Audit.append(%{
                 event_kind: :run_state_transitioned,
                 payload: %{"from" => "queued", "to" => "planning"},
                 correlation_id: cid
               })

      assert event.event_kind == :run_state_transitioned
      assert event.schema_version == 1
      assert event.correlation_id == cid
    end

    test "accepts string event_kind and normalizes to atom" do
      assert {:ok, event} =
               Audit.append(%{
                 event_kind: "stage_started",
                 payload: %{"stage_kind" => "coding"},
                 correlation_id: Ecto.UUID.generate()
               })

      assert event.event_kind == :stage_started
    end

    test "every one of the 33 kinds accepts its minimal payload" do
      for kind <- EventKind.values() do
        payload = minimal_payload_for(kind)
        cid = Ecto.UUID.generate()

        assert {:ok, _event} =
                 Audit.append(%{
                   event_kind: kind,
                   payload: payload,
                   correlation_id: cid
                 }),
               "append failed for kind=#{inspect(kind)} payload=#{inspect(payload)}"
      end
    end

    test "fills correlation_id from Logger.metadata when not passed" do
      cid = Ecto.UUID.generate()
      Logger.metadata(correlation_id: cid)

      try do
        assert {:ok, event} =
                 Audit.append(%{
                   event_kind: :stage_started,
                   payload: %{"stage_kind" => "coding"}
                 })

        assert event.correlation_id == cid
      after
        Logger.metadata(correlation_id: nil)
      end
    end
  end

  describe "append/1 — invalid payloads are rejected before INSERT" do
    test "run_state_transitioned with bogus 'from' enum value" do
      cid = Ecto.UUID.generate()

      assert {:error, {:audit_payload_invalid, _}} =
               Audit.append(%{
                 event_kind: :run_state_transitioned,
                 payload: %{"from" => "bogus_state", "to" => "planning"},
                 correlation_id: cid
               })

      # No row persisted.
      assert Repo.aggregate(Kiln.Audit.Event, :count) == 0
    end

    test "stage_started with unknown key (additionalProperties: false)" do
      cid = Ecto.UUID.generate()

      assert {:error, {:audit_payload_invalid, _}} =
               Audit.append(%{
                 event_kind: :stage_started,
                 payload: %{"stage_kind" => "coding", "definitely_not_a_known_key" => true},
                 correlation_id: cid
               })
    end

    test "stage_completed missing required field" do
      cid = Ecto.UUID.generate()

      assert {:error, {:audit_payload_invalid, _}} =
               Audit.append(%{
                 event_kind: :stage_completed,
                 payload: %{"stage_kind" => "coding"},
                 correlation_id: cid
               })
    end
  end

  describe "append/1 — unknown event_kind" do
    test "atom not in taxonomy returns :unknown_event_kind" do
      assert {:error, {:unknown_event_kind, :made_up_kind}} =
               Audit.append(%{
                 event_kind: :made_up_kind,
                 payload: %{},
                 correlation_id: Ecto.UUID.generate()
               })
    end

    test "string not in taxonomy returns :unknown_event_kind" do
      assert {:error, {:unknown_event_kind, "made_up_kind"}} =
               Audit.append(%{
                 event_kind: "made_up_kind",
                 payload: %{},
                 correlation_id: Ecto.UUID.generate()
               })
    end
  end

  describe "append/1 — correlation_id requirements" do
    test "raises ArgumentError when correlation_id neither passed nor in metadata" do
      Logger.metadata(correlation_id: nil)

      assert_raise ArgumentError, ~r/correlation_id/, fn ->
        Audit.append(%{
          event_kind: :stage_started,
          payload: %{"stage_kind" => "coding"}
        })
      end
    end
  end

  describe "replay/1 — filters (UI-05)" do
    alias Kiln.Factory.Run, as: RunFactory

    test "filters by stage_id + occurred bounds" do
      run = RunFactory.insert(:run)
      cid = Ecto.UUID.generate()

      t0 = ~U[2026-01-01 12:00:00.000000Z]
      t1 = ~U[2026-01-02 12:00:00.000000Z]

      stage_a = Ecto.UUID.generate()
      stage_b = Ecto.UUID.generate()

      assert {:ok, _} =
               Audit.append(%{
                 event_kind: :run_state_transitioned,
                 correlation_id: cid,
                 run_id: run.id,
                 stage_id: stage_a,
                 occurred_at: t0,
                 payload: minimal_payload_for(:run_state_transitioned)
               })

      assert {:ok, _} =
               Audit.append(%{
                 event_kind: :run_state_transitioned,
                 correlation_id: cid,
                 run_id: run.id,
                 stage_id: stage_b,
                 occurred_at: t1,
                 payload: minimal_payload_for(:run_state_transitioned)
               })

      out =
        Audit.replay(
          run_id: run.id,
          stage_id: stage_a,
          occurred_after: ~U[2026-01-01 00:00:00.000000Z],
          occurred_before: ~U[2026-01-01 23:59:59.000000Z]
        )

      assert length(out) == 1
      assert hd(out).stage_id == stage_a
    end
  end

  # One minimal-valid payload per kind; mirrors the 25 JSON schemas
  # (22 Phase 1 + 3 Phase 2 D-85 extensions).
  defp minimal_payload_for(:run_state_transitioned), do: %{"from" => "queued", "to" => "planning"}

  defp minimal_payload_for(:stage_started), do: %{"stage_kind" => "coding"}

  defp minimal_payload_for(:stage_completed),
    do: %{"stage_kind" => "coding", "duration_ms" => 42}

  defp minimal_payload_for(:stage_failed), do: %{"stage_kind" => "coding", "reason" => "x"}

  defp minimal_payload_for(:external_op_intent_recorded),
    do: %{"op_kind" => "git_push", "idempotency_key" => "r:s:x"}

  defp minimal_payload_for(:external_op_action_started),
    do: %{"op_kind" => "git_push", "idempotency_key" => "r:s:x"}

  defp minimal_payload_for(:external_op_completed),
    do: %{"op_kind" => "git_push", "idempotency_key" => "r:s:x", "result_summary" => "ok"}

  defp minimal_payload_for(:external_op_failed),
    do: %{"op_kind" => "git_push", "idempotency_key" => "r:s:x", "error" => "x"}

  defp minimal_payload_for(:secret_reference_resolved), do: %{"name" => "ANTHROPIC_API_KEY"}

  defp minimal_payload_for(:model_routing_fallback),
    do: %{
      # D-106 / Phase 3 schema rewrite — see
      # priv/audit_schemas/v1/model_routing_fallback.json (Plan 03-03).
      "requested_model" => "claude-opus-4-5",
      "actual_model_used" => "claude-sonnet-4-5",
      "fallback_reason" => "http_429",
      "tier_crossed" => false,
      "attempt_number" => 2,
      "wall_clock_ms" => 350
    }

  defp minimal_payload_for(:budget_check_passed),
    do: %{
      "estimated_usd" => "0.01",
      "remaining_usd" => "0.99",
      "model" => "claude-sonnet-4-5-20250929"
    }

  defp minimal_payload_for(:budget_check_failed),
    do: %{
      "estimated_usd" => "1.50",
      "remaining_usd" => "0.01",
      "model" => "claude-opus-4-5-20250929"
    }

  defp minimal_payload_for(:stuck_detector_alarmed),
    do: %{"failure_class" => "schema_mismatch", "count" => 3}

  defp minimal_payload_for(:scenario_runner_verdict),
    do: %{"run_id" => Ecto.UUID.generate(), "verdict" => "pass", "exit_code" => 0}

  defp minimal_payload_for(:work_unit_created),
    do: %{"work_unit_id" => Ecto.UUID.generate(), "kind" => "task"}

  defp minimal_payload_for(:work_unit_state_changed),
    do: %{"work_unit_id" => Ecto.UUID.generate(), "from" => "open", "to" => "closed"}

  defp minimal_payload_for(:git_op_completed), do: %{"op" => "push", "sha" => "abc1234"}

  defp minimal_payload_for(:pr_created),
    do: %{"number" => 1, "url" => "https://github.com/x/y/pull/1"}

  defp minimal_payload_for(:ci_status_observed), do: %{"status" => "success"}

  defp minimal_payload_for(:block_raised),
    do: %{"reason" => "missing_api_key", "details" => %{}}

  defp minimal_payload_for(:block_resolved),
    do: %{"reason" => "missing_api_key", "resolved_by" => "operator"}

  defp minimal_payload_for(:escalation_triggered), do: %{"reason" => "stuck_detector"}

  # Phase 2 D-85 extensions.
  defp minimal_payload_for(:stage_input_rejected),
    do: %{
      "stage_run_id" => Ecto.UUID.generate(),
      "stage_kind" => "coding",
      "errors" => []
    }

  defp minimal_payload_for(:artifact_written),
    do: %{
      "name" => "plan.md",
      "sha256" => String.duplicate("a", 64),
      "size_bytes" => 1024,
      "content_type" => "text/markdown"
    }

  defp minimal_payload_for(:integrity_violation),
    do: %{
      "artifact_id" => Ecto.UUID.generate(),
      "expected_sha" => String.duplicate("a", 64),
      "actual_sha" => String.duplicate("b", 64),
      "path" => "priv/artifacts/cas/aa/aa/aa..."
    }

  # Phase 3 D-145 extensions.
  defp minimal_payload_for(:orphan_container_swept),
    do: %{
      "container_id" => "sandbox-abc1234",
      "boot_epoch_found" => 1_700_000_000,
      "age_seconds" => 120
    }

  defp minimal_payload_for(:dtu_contract_drift_detected),
    do: %{
      "endpoint" => "/repos/octocat/hello-world/pulls",
      "method" => "GET",
      "drift_kind" => "new_required_field"
    }

  defp minimal_payload_for(:dtu_health_degraded),
    do: %{"consecutive_misses" => 3}

  defp minimal_payload_for(:factory_circuit_opened),
    do: %{"reason" => "scaffolded", "scaffolded" => true}

  defp minimal_payload_for(:factory_circuit_closed),
    do: %{"reason" => "scaffolded", "scaffolded" => true}

  defp minimal_payload_for(:model_deprecated_resolved),
    do: %{
      "model_id" => "claude-opus-4-5",
      "deprecated_on" => "2026-12-01",
      "preset" => "elixir_lib",
      "role" => "planner"
    }

  defp minimal_payload_for(:notification_fired),
    do: %{"reason" => "missing_api_key", "platform" => "macos"}

  defp minimal_payload_for(:notification_suppressed),
    do: %{"reason" => "missing_api_key", "dedup_key" => "run:abc:missing_api_key"}
end
