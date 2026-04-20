defmodule Kiln.Policies.FactoryCircuitBreakerTest do
  # Uses Kiln.FactoryCircuitBreakerCase (Plan 03-00) to centralise the
  # singleton-reuse dance (mirrors StuckDetectorCase; deferred-activation
  # pattern — case now activates once Plan 03-04 ships the GenServer).
  use Kiln.FactoryCircuitBreakerCase, async: false

  alias Kiln.Policies.FactoryCircuitBreaker

  test "check/1 returns :ok for any map (no-op body P3)" do
    assert :ok ==
             FactoryCircuitBreaker.check(%{
               run_id: "r1",
               spend_last_60min_usd: Decimal.new("0")
             })
  end

  test "check/1 returns :ok even with adversarial spend (P3 body is no-op)" do
    assert :ok ==
             FactoryCircuitBreaker.check(%{
               run_id: "r1",
               spend_last_60min_usd: Decimal.new("1000000000")
             })
  end

  test "check/1 accepts arbitrary context shapes without raising (signature locked through Phase 5)" do
    assert :ok == FactoryCircuitBreaker.check(%{})

    assert :ok ==
             FactoryCircuitBreaker.check(%{
               run_id: Ecto.UUID.generate(),
               stage_id: Ecto.UUID.generate(),
               spend_last_60min_usd: Decimal.new("42.00"),
               provider: "anthropic"
             })
  end

  test "GenServer is registered under module name" do
    pid = Process.whereis(FactoryCircuitBreaker)
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  test "handle_info/2 catch-all does not crash on stray messages" do
    pid = Process.whereis(FactoryCircuitBreaker)
    send(pid, :unexpected_message)
    send(pid, {:random_tuple, :payload})
    Process.sleep(20)
    assert Process.alive?(pid)
  end
end
