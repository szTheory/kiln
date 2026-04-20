defmodule Kiln.Audit.EventKindP3Test do
  @moduledoc """
  Migration round-trip + `Kiln.Audit.append/1` acceptance for the 8 Phase 3
  D-145 event kinds plus the `:model_routing_fallback` D-106 schema rewrite.

  `use Kiln.AuditLedgerCase, async: false` gives us a per-test sandbox
  connection; the sandbox wraps every test in a transaction so the 9
  inserts are rolled back cleanly at test end.
  """

  use Kiln.AuditLedgerCase, async: false

  require Logger

  alias Kiln.Audit
  alias Kiln.Audit.EventKind

  # Plan 03-03 Task 2 test target — all 9 kinds the plan enumerates.
  # `:model_routing_fallback` was already declared in Phase 1 (position 10
  # in the @kinds list); only its payload schema was rewritten in P3 to
  # match D-106. The other 8 are the D-145 new atoms.
  @new_kinds [
    :orphan_container_swept,
    :dtu_contract_drift_detected,
    :dtu_health_degraded,
    :factory_circuit_opened,
    :factory_circuit_closed,
    :model_deprecated_resolved,
    :model_routing_fallback,
    :notification_fired,
    :notification_suppressed
  ]

  describe "EventKind.values/0" do
    test "includes all Phase 3 kinds exercised by this plan" do
      for k <- @new_kinds do
        assert k in EventKind.values(), "missing P3 kind: #{inspect(k)}"
      end
    end
  end

  describe "Audit.append/1 for P3 kinds" do
    test "accepts each kind with a minimal valid payload" do
      payloads = %{
        orphan_container_swept: %{
          "container_id" => "sandbox-abc1234",
          "boot_epoch_found" => 1_700_000_000,
          "age_seconds" => 60
        },
        dtu_contract_drift_detected: %{
          "endpoint" => "/repos/octocat/hello-world/pulls",
          "method" => "GET",
          "drift_kind" => "new_required_field"
        },
        dtu_health_degraded: %{"consecutive_misses" => 3},
        factory_circuit_opened: %{"reason" => "scaffolded", "scaffolded" => true},
        factory_circuit_closed: %{"reason" => "scaffolded", "scaffolded" => true},
        model_deprecated_resolved: %{
          "model_id" => "claude-opus-4-5",
          "deprecated_on" => "2026-12-01",
          "preset" => "elixir_lib",
          "role" => "planner"
        },
        model_routing_fallback: %{
          "requested_model" => "claude-opus-4-5",
          "actual_model_used" => "claude-sonnet-4-5",
          "fallback_reason" => "http_429",
          "tier_crossed" => false,
          "attempt_number" => 2,
          "wall_clock_ms" => 350
        },
        notification_fired: %{"reason" => "missing_api_key", "platform" => "macos"},
        notification_suppressed: %{
          "reason" => "missing_api_key",
          "dedup_key" => "run:abc:missing_api_key"
        }
      }

      for k <- @new_kinds do
        cid = Ecto.UUID.generate()
        Logger.metadata(correlation_id: cid)

        assert {:ok, event} =
                 Audit.append(%{
                   event_kind: k,
                   run_id: nil,
                   stage_id: nil,
                   correlation_id: cid,
                   payload: Map.fetch!(payloads, k)
                 }),
               "Audit.append/1 failed for P3 kind #{inspect(k)}"

        assert event.event_kind == k
        assert event.correlation_id == cid
      end
    end

    test "model_routing_fallback requires all D-106 fields" do
      cid = Ecto.UUID.generate()

      # Missing `actual_model_used` should fail schema validation at the
      # boundary — this is the T-silent-model-fallback threat mitigation.
      assert {:error, {:audit_payload_invalid, _}} =
               Audit.append(%{
                 event_kind: :model_routing_fallback,
                 correlation_id: cid,
                 payload: %{
                   "requested_model" => "claude-opus-4-5",
                   "fallback_reason" => "http_429",
                   "tier_crossed" => false,
                   "attempt_number" => 1,
                   "wall_clock_ms" => 100
                 }
               })
    end
  end
end
