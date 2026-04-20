defmodule Kiln.ApplicationTest do
  @moduledoc """
  Supervision-tree shape assertions. Phase 1 / D-42 locked the child
  count at 7; Plan 02-07 / D-92..D-96 extend it to 10 by adding
  `Kiln.Runs.RunSupervisor`, `Kiln.Runs.RunDirector`, and
  `Kiln.Policies.StuckDetector` to `infra_children` (between `Oban`
  and the BootChecks.run!/0 call). `KilnWeb.Endpoint` is still added
  dynamically AFTER BootChecks as the 10th child.

  Tests cover:

    * Exactly 10 children post-boot.
    * All 10 module-ids present in `Supervisor.which_children/1`.
    * The named pools (`Kiln.Finch`, `Kiln.RunRegistry`,
      `Kiln.Runs.RunDirector`, `Kiln.Runs.RunSupervisor`,
      `Kiln.Policies.StuckDetector`) are alive.
    * `KilnWeb.Endpoint` is alive (staged-start invariant preserved).
  """
  use ExUnit.Case, async: false

  describe "supervision tree (D-42 + D-92..D-96, 10 children)" do
    test "exactly 10 children running under Kiln.Supervisor (D-42 + D-92..D-96)" do
      child_ids =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _pid, _type, _mods} -> id end)

      assert length(child_ids) == 10,
             "Phase 2 requires EXACTLY 10 children, got #{length(child_ids)}: #{inspect(child_ids)}"
    end

    test "locked child set: P1 seven + RunSupervisor + RunDirector + StuckDetector" do
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

    test "negative: no Phase 3+ stub children in the P2 tree" do
      child_ids =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _pid, _type, _mods} -> id end)

      # These are children downstream phases will add — they MUST NOT
      # ship in P2 per D-42's spirit (no stub children without
      # behavior). Phase 2's RunSupervisor + RunDirector +
      # StuckDetector are NOT in this list because D-91..D-96 each
      # explicitly list them as the "P2 behavior to exercise" (the
      # hook path + rehydration loop + subtree host IS the behavior).
      forbidden = [
        Kiln.Sandboxes.Supervisor,
        Kiln.Agents.SessionSupervisor,
        Kiln.Sandboxes.DTU.Supervisor,
        DNSCluster
      ]

      for forbidden_child <- forbidden do
        refute Enum.any?(child_ids, fn id -> id == forbidden_child end),
               "#{inspect(forbidden_child)} MUST NOT be in the P2 supervision tree"
      end
    end

    test "Kiln.Finch named pool is alive" do
      pid = Process.whereis(Kiln.Finch)
      assert is_pid(pid), "Kiln.Finch named pool must be registered post-boot"
      assert Process.alive?(pid)
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

    test "KilnWeb.Endpoint is alive (staged start — added after BootChecks per D-32)" do
      pid = Process.whereis(KilnWeb.Endpoint)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end
end
