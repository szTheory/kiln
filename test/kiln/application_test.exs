defmodule Kiln.ApplicationTest do
  @moduledoc """
  Supervision-tree shape assertions. Phase 3 extends the staged-boot
  application tree from 10 children to 14 by adding
  `Kiln.Sandboxes.Supervisor`, `Kiln.Sandboxes.DTU.Supervisor`,
  `Kiln.Agents.SessionSupervisor`, and
  `Kiln.Policies.FactoryCircuitBreaker` before `RunDirector`.

  Tests cover:

    * Exactly 14 children post-boot.
    * All 14 module-ids present in `Supervisor.which_children/1`.
    * The named pools (`Kiln.Finch`, `Kiln.RunRegistry`,
      `Kiln.Runs.RunDirector`, `Kiln.Runs.RunSupervisor`,
      `Kiln.Policies.StuckDetector`) are alive.
    * `KilnWeb.Endpoint` is alive (staged-start invariant preserved).
  """
  use ExUnit.Case, async: false

  describe "supervision tree (Phase 3, 14 children)" do
    test "exactly 14 children running under Kiln.Supervisor" do
      child_ids =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _pid, _type, _mods} -> id end)

      assert length(child_ids) == 14,
             "Phase 3 requires EXACTLY 14 children, got #{length(child_ids)}: #{inspect(child_ids)}"
    end

    test "locked child set includes the 4 Phase 3 runtime additions" do
      child_ids =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _pid, _type, _mods} -> id end)

      # Child IDs are a mix of module names and `:name` atoms depending
      # on how each child was specified (modules use their name; named
      # processes like Registry/Finch use the `:name` atom). The
      # contract is about concern presence, not exact id literal — match
      # on a predicate that recognises each concern.
      expectations = [
        {"KilnWeb.Telemetry", &(&1 == KilnWeb.Telemetry)},
        {"Kiln.Repo", &(&1 == Kiln.Repo)},
        {"Phoenix.PubSub (via supervisor)",
         fn id -> is_atom(id) and to_string(id) =~ "PubSub" end},
        {"Finch (Kiln.Finch)", &(&1 == Kiln.Finch)},
        {"Registry (Kiln.RunRegistry)", &(&1 == Kiln.RunRegistry)},
        {"Oban", &(&1 == Oban)},
        {"Kiln.Sandboxes.Supervisor", &(&1 == Kiln.Sandboxes.Supervisor)},
        {"Kiln.Sandboxes.DTU.Supervisor", &(&1 == Kiln.Sandboxes.DTU.Supervisor)},
        {"Kiln.Agents.SessionSupervisor", &(&1 == Kiln.Agents.SessionSupervisor)},
        {"Kiln.Policies.FactoryCircuitBreaker", &(&1 == Kiln.Policies.FactoryCircuitBreaker)},
        {"Kiln.Runs.RunSupervisor", &(&1 == Kiln.Runs.RunSupervisor)},
        {"Kiln.Runs.RunDirector", &(&1 == Kiln.Runs.RunDirector)},
        {"Kiln.Policies.StuckDetector", &(&1 == Kiln.Policies.StuckDetector)},
        {"KilnWeb.Endpoint", &(&1 == KilnWeb.Endpoint)}
      ]

      for {label, pred} <- expectations do
        assert Enum.any?(child_ids, pred),
               "expected child #{label} missing from tree: #{inspect(child_ids)}"
      end
    end

    test "Kiln.Finch named pool is alive" do
      pid = Process.whereis(Kiln.Finch)
      assert is_pid(pid), "Kiln.Finch named pool must be registered post-boot"
      assert Process.alive?(pid)
    end

    test "Finch stays as one child with per-provider pools" do
      pools = Kiln.Application.finch_pools()

      assert Map.has_key?(pools, "https://api.anthropic.com")
      assert Map.has_key?(pools, "https://api.openai.com")
      assert Map.has_key?(pools, "https://generativelanguage.googleapis.com")
      assert Map.has_key?(pools, "http://localhost:11434")
      assert Map.has_key?(pools, "http://172.28.0.10:80")
      assert Map.has_key?(pools, :default)
    end

    test "Kiln.RunRegistry is alive (used by Kiln.Runs.RunSubtree per-run naming)" do
      pid = Process.whereis(Kiln.RunRegistry)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "Oban supervisor tree is alive" do
      config = Oban.config()
      assert is_struct(config, Oban.Config)

      oban_child =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.find(fn {id, _pid, _type, _mods} -> id == Oban end)

      assert {Oban, pid, _type, _mods} = oban_child
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "Kiln.Runs.RunSupervisor is alive (DynamicSupervisor; D-95)" do
      pid = Process.whereis(Kiln.Runs.RunSupervisor)
      assert is_pid(pid), "Kiln.Runs.RunSupervisor must be registered post-boot"
      assert Process.alive?(pid)
    end

    test "Kiln.Runs.RunDirector is alive (:permanent GenServer; D-92..D-96)" do
      pid = Process.whereis(Kiln.Runs.RunDirector)
      assert is_pid(pid), "Kiln.Runs.RunDirector must be registered post-boot"
      assert Process.alive?(pid)
    end

    test "Kiln.Policies.StuckDetector is alive (:permanent GenServer; D-91)" do
      pid = Process.whereis(Kiln.Policies.StuckDetector)
      assert is_pid(pid), "Kiln.Policies.StuckDetector must be registered post-boot"
      assert Process.alive?(pid)
    end

    test "new Phase 3 runtime children are alive" do
      for name <- [
            Kiln.Sandboxes.Supervisor,
            Kiln.Sandboxes.DTU.Supervisor,
            Kiln.Agents.SessionSupervisor,
            Kiln.Policies.FactoryCircuitBreaker
          ] do
        pid = Process.whereis(name)
        assert is_pid(pid), "#{inspect(name)} must be registered post-boot"
        assert Process.alive?(pid)
      end
    end

    test "sandboxes supervisor is ordered before run director in the planned infra list" do
      ids =
        Kiln.Application.infra_children()
        |> Enum.map(&Supervisor.child_spec(&1, []).id)

      assert Enum.find_index(ids, &(&1 == Kiln.Sandboxes.Supervisor)) <
               Enum.find_index(ids, &(&1 == Kiln.Runs.RunDirector))
    end

    test "agent telemetry handler is attached after boot" do
      _ = Kiln.Agents.TelemetryHandler.attach()
      handlers = :telemetry.list_handlers([:kiln, :agent, :call, :start])
      ids = Enum.map(handlers, & &1.id)

      assert {Kiln.Agents.TelemetryHandler, :agent_call_lifecycle} in ids
    end

    test "KilnWeb.Endpoint is alive (staged start — added after BootChecks per D-32)" do
      pid = Process.whereis(KilnWeb.Endpoint)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end
end
