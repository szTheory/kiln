defmodule Kiln.NotificationsTest do
  # Touches Kiln.Audit.append/1 which writes to audit_events. Must
  # compose with Kiln.AuditLedgerCase so each test runs inside an Ecto
  # sandbox transaction.
  use Kiln.AuditLedgerCase, async: false

  require Logger

  alias Kiln.Audit
  alias Kiln.Notifications
  alias Kiln.Notifications.DedupCache

  setup do
    case Process.whereis(DedupCache) do
      nil -> {:ok, _} = DedupCache.start_link([])
      pid when is_pid(pid) -> DedupCache.clear()
    end

    # Allow the DedupCache's GenServer process to share the sandbox
    # connection if tests go through Audit.append — DedupCache itself
    # owns no DB, but its init-started ETS table needs to survive.
    Logger.metadata(correlation_id: Ecto.UUID.generate())

    on_exit(fn -> DedupCache.clear() end)
    :ok
  end

  describe "desktop/2 reason validation (unit — no shell-out)" do
    test "rejects unknown reason atom with {:error, :invalid_reason}" do
      assert {:error, :invalid_reason} =
               Notifications.desktop(:not_in_enum, %{run_id: "run-invalid"})
    end

    test "rejects any non-Blockers.Reason atom (T-03-04-02 mitigation)" do
      assert {:error, :invalid_reason} =
               Notifications.desktop(:"malicious.atom", %{run_id: "run-x"})

      assert {:error, :invalid_reason} =
               Notifications.desktop(:random_thing, %{run_id: "run-x"})
    end
  end

  describe "DedupCache TTL + check_and_record (unit — no shell-out)" do
    test "first check_and_record returns :fire; second returns :suppress" do
      key = {"run-dedup-unit-1", :missing_api_key}
      assert :fire == DedupCache.check_and_record(key)
      assert :suppress == DedupCache.check_and_record(key)
    end

    test "different reason for same run_id is a separate dedup entry" do
      assert :fire == DedupCache.check_and_record({"run-dedup-unit-2", :missing_api_key})
      assert :fire == DedupCache.check_and_record({"run-dedup-unit-2", :budget_exceeded})
    end

    test "different run_id for same reason is a separate dedup entry" do
      assert :fire == DedupCache.check_and_record({"run-a", :missing_api_key})
      assert :fire == DedupCache.check_and_record({"run-b", :missing_api_key})
    end

    test "clear/0 wipes the table and a previously-suppressed key fires again" do
      key = {"run-dedup-unit-4", :missing_api_key}
      assert :fire == DedupCache.check_and_record(key)
      assert :suppress == DedupCache.check_and_record(key)

      :ok = DedupCache.clear()

      assert :fire == DedupCache.check_and_record(key)
    end

    test "expired entry (TTL exceeded) fires again" do
      key = {"run-dedup-unit-5", :missing_api_key}

      # Hand-insert a record with a timestamp older than the 5-min TTL.
      stale_ts = System.monotonic_time(:millisecond) - 6 * 60 * 1000
      :ets.insert(DedupCache, {key, stale_ts})

      assert :fire == DedupCache.check_and_record(key)
    end
  end

  describe "desktop/2 suppression path emits audit event without shelling out" do
    # The :suppress path emits `notification_suppressed` without calling
    # System.cmd, so this is safe to run in unit mode on any platform.
    # `run_id` is :binary_id on Kiln.Audit.Event, so use a real UUID.
    test "second identical (run_id, reason) within TTL emits :notification_suppressed" do
      run_id = Ecto.UUID.generate()
      reason = :missing_api_key

      # Pre-seed dedup entry so the FIRST call through `desktop/2` takes
      # the :suppress branch — skipping the shell-out entirely.
      :ets.insert(DedupCache, {{run_id, reason}, System.monotonic_time(:millisecond)})

      assert :ok = Notifications.desktop(reason, %{run_id: run_id, provider: "anthropic"})

      # Exactly one audit event of kind :notification_suppressed for this
      # correlation was written.
      events = Audit.replay(event_kind: :notification_suppressed)
      assert Enum.any?(events, fn ev -> ev.payload["run_id"] == run_id end)
    end

    test "nil run_id in context is accepted (suppress branch)" do
      reason = :budget_exceeded
      :ets.insert(DedupCache, {{nil, reason}, System.monotonic_time(:millisecond)})

      assert :ok = Notifications.desktop(reason, %{})
    end
  end

  describe "desktop/2 platform routing (integration — shells out)" do
    @describetag :integration

    test "returns :ok on macOS/Linux or {:error, _} on other platforms" do
      # Integration tests use real UUID run_ids since ExternalOperations.run_id is :binary_id.
      run_id = Ecto.UUID.generate()
      result = Notifications.desktop(:missing_api_key, %{run_id: run_id, provider: "anthropic"})
      assert result == :ok or match?({:error, _}, result)
    end

    test "first call within TTL fires + writes :notification_fired audit event" do
      run_id = Ecto.UUID.generate()

      assert :ok =
               Notifications.desktop(:missing_api_key, %{run_id: run_id, provider: "anthropic"})

      events = Audit.replay(event_kind: :notification_fired)
      assert Enum.any?(events, fn ev -> ev.payload["run_id"] == run_id end)
    end

    test "second call for same (run_id, reason) within TTL is dedup-suppressed" do
      run_id = Ecto.UUID.generate()

      assert :ok = Notifications.desktop(:missing_api_key, %{run_id: run_id})
      assert :ok = Notifications.desktop(:missing_api_key, %{run_id: run_id})

      events = Audit.replay(event_kind: :notification_suppressed)
      assert Enum.any?(events, fn ev -> ev.payload["run_id"] == run_id end)
    end
  end
end
