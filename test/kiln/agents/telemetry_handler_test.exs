defmodule Kiln.Agents.TelemetryHandlerTest do
  @moduledoc """
  Tests for `Kiln.Agents.TelemetryHandler` - the boot-time attacher
  that turns adapter-stop telemetry into `model_routing_fallback`
  audit events (OPS-02 / D-106).

  The silent-fallback-impossible guardrail requires that EVERY stop
  event where `actual_model_used != requested_model` writes exactly
  one audit row; the matching case writes zero.
  """

  use Kiln.DataCase, async: false

  alias Kiln.Agents.TelemetryHandler

  setup do
    _ = TelemetryHandler.attach()
    on_exit(fn -> TelemetryHandler.detach() end)

    Logger.metadata(correlation_id: Ecto.UUID.generate())
    :ok
  end

  describe "attach/0 and detach/0" do
    test "detach is idempotent" do
      TelemetryHandler.detach()
      assert match?(_, TelemetryHandler.detach())
      _ = TelemetryHandler.attach()
    end
  end

  describe "handle_event on :stop with fallback" do
    test "writes exactly one model_routing_fallback audit row on mismatch" do
      run_id = Ecto.UUID.generate()

      :telemetry.execute(
        [:kiln, :agent, :call, :stop],
        %{duration: 1_000_000_000, tokens_in: 100, tokens_out: 50},
        %{
          requested_model: "claude-opus-4-5-20250929",
          actual_model_used: "claude-sonnet-4-5-20250929",
          provider: :anthropic,
          role: :coder,
          fallback_reason: :http_429,
          run_id: run_id,
          stage_id: nil,
          attempt_number: 2,
          provider_http_status: 429
        }
      )

      import Ecto.Query

      rows =
        Kiln.Repo.all(
          from(e in Kiln.Audit.Event,
            where: e.event_kind == ^:model_routing_fallback and e.run_id == ^run_id
          )
        )

      assert length(rows) == 1
      [row] = rows
      assert row.payload["requested_model"] == "claude-opus-4-5-20250929"
      assert row.payload["actual_model_used"] == "claude-sonnet-4-5-20250929"
      assert row.payload["tier_crossed"] == true
      assert row.payload["fallback_reason"] == "http_429"
      assert row.payload["attempt_number"] == 2
      assert row.payload["provider"] == "anthropic"
      assert row.payload["role"] == "coder"
      assert row.payload["provider_http_status"] == 429
      assert is_integer(row.payload["wall_clock_ms"])
    end

    test "does NOT write an audit row when requested == actual" do
      run_id = Ecto.UUID.generate()

      :telemetry.execute(
        [:kiln, :agent, :call, :stop],
        %{duration: 1_000_000, tokens_in: 100, tokens_out: 50},
        %{
          requested_model: "claude-sonnet-4-5-20250929",
          actual_model_used: "claude-sonnet-4-5-20250929",
          provider: :anthropic,
          role: :coder,
          run_id: run_id,
          stage_id: nil
        }
      )

      import Ecto.Query

      rows =
        Kiln.Repo.all(
          from(e in Kiln.Audit.Event,
            where: e.event_kind == ^:model_routing_fallback and e.run_id == ^run_id
          )
        )

      assert rows == []
    end

    test "does NOT write when metadata lacks requested/actual fields" do
      run_id = Ecto.UUID.generate()

      :telemetry.execute(
        [:kiln, :agent, :call, :stop],
        %{duration: 1_000_000},
        %{run_id: run_id, stage_id: nil}
      )

      import Ecto.Query

      rows =
        Kiln.Repo.all(
          from(e in Kiln.Audit.Event,
            where: e.event_kind == ^:model_routing_fallback and e.run_id == ^run_id
          )
        )

      assert rows == []
    end

    test "same-tier fallback records tier_crossed: false" do
      run_id = Ecto.UUID.generate()

      :telemetry.execute(
        [:kiln, :agent, :call, :stop],
        %{duration: 1_000_000, tokens_in: 10, tokens_out: 5},
        %{
          requested_model: "claude-sonnet-4-5-20250929",
          actual_model_used: "claude-sonnet-4-5-older",
          provider: :anthropic,
          role: :coder,
          fallback_reason: :http_5xx,
          run_id: run_id,
          stage_id: nil
        }
      )

      import Ecto.Query

      rows =
        Kiln.Repo.all(
          from(e in Kiln.Audit.Event,
            where: e.event_kind == ^:model_routing_fallback and e.run_id == ^run_id
          )
        )

      assert length(rows) == 1
      [row] = rows
      assert row.payload["tier_crossed"] == false
    end
  end

  describe "handle_event on :start and :exception" do
    test "accepts :start events without emitting audit" do
      run_id = Ecto.UUID.generate()

      :telemetry.execute(
        [:kiln, :agent, :call, :start],
        %{},
        %{
          requested_model: "claude-sonnet-4-5-20250929",
          run_id: run_id,
          stage_id: nil
        }
      )

      import Ecto.Query

      rows =
        Kiln.Repo.all(
          from(e in Kiln.Audit.Event,
            where: e.event_kind == ^:model_routing_fallback and e.run_id == ^run_id
          )
        )

      assert rows == []
    end

    test "accepts :exception events without emitting audit" do
      run_id = Ecto.UUID.generate()

      :telemetry.execute(
        [:kiln, :agent, :call, :exception],
        %{duration: 1_000_000},
        %{
          requested_model: "claude-sonnet-4-5-20250929",
          actual_model_used: "claude-haiku-4-5-20250929",
          run_id: run_id,
          stage_id: nil
        }
      )

      import Ecto.Query

      rows =
        Kiln.Repo.all(
          from(e in Kiln.Audit.Event,
            where: e.event_kind == ^:model_routing_fallback and e.run_id == ^run_id
          )
        )

      assert rows == []
    end
  end
end
