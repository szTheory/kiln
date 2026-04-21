defmodule Kiln.Agents.AdapterContractTest do
  @moduledoc """
  Behaviour-contract tests for `Kiln.Agents.Adapter` (D-101 / D-102).

  Asserts the 4 callbacks locked in D-102 are declared REQUIRED (no
  `@optional_callbacks`) and that the Wave 0 `Kiln.Agents.AdapterMock`
  resolves against the behaviour once this plan lands.
  """

  use ExUnit.Case, async: true

  test "behaviour exposes 4 required callbacks" do
    callbacks = Kiln.Agents.Adapter.behaviour_info(:callbacks)
    assert {:complete, 2} in callbacks
    assert {:stream, 2} in callbacks
    assert {:count_tokens, 1} in callbacks
    assert {:capabilities, 0} in callbacks
    assert length(callbacks) == 4
  end

  test "no optional callbacks (D-102)" do
    optional = Kiln.Agents.Adapter.behaviour_info(:optional_callbacks)
    assert optional == []
  end

  test "Kiln.Agents.AdapterMock resolves (Mox defmock registered in Wave 0)" do
    assert Code.ensure_loaded?(Kiln.Agents.AdapterMock)
  end

  test "Kiln.Agents.SessionSupervisor legacy scaffold boots as empty Supervisor" do
    {pid, started_here?} =
      case Kiln.Agents.SessionSupervisor.start_link([]) do
        {:ok, pid} -> {pid, true}
        {:error, {:already_started, pid}} -> {pid, false}
      end

    assert Process.alive?(pid)

    assert Supervisor.count_children(pid) == %{
             active: 0,
             specs: 0,
             supervisors: 0,
             workers: 0
           }

    if started_here? do
      :ok = Supervisor.stop(pid)
    end
  end
end
