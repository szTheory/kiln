defmodule Kiln.ApplicationTest do
  @moduledoc """
  Behaviors 39, 40, 41 from 01-VALIDATION.md — the D-42 supervision-tree
  shape contract.

  39 — Exactly 7 children under `Kiln.Supervisor` after Application.start/2
       completes (infra stage + BootChecks + Endpoint added dynamically).
  40 — No Phase 2+ stub children (RunDirector, RunSupervisor,
       Sandboxes.Supervisor, etc.) appear — they land in their own phases.
  41 — `Kiln.Finch` named pool is alive (Req uses it via
       `req: [finch: Kiln.Finch]` in Phase 3+).
  """
  use ExUnit.Case, async: false

  describe "supervision tree (D-42, behaviors 39-41)" do
    test "exactly 7 P1 children running under Kiln.Supervisor (D-42)" do
      child_ids =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _pid, _type, _mods} -> id end)

      assert length(child_ids) == 7,
             "D-42 requires EXACTLY 7 children, got #{length(child_ids)}: #{inspect(child_ids)}"
    end

    test "D-42 locked child set: Telemetry, Repo, PubSub, Finch, RunRegistry, Oban, Endpoint (behavior 39)" do
      child_ids =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _pid, _type, _mods} -> id end)

      # Child IDs are a mix of module names and `:name` atoms depending
      # on how each child was specified. The D-42 contract is about the
      # seven P1 concerns, not the exact id literal — match on a
      # predicate that recognises each concern.
      #
      #   KilnWeb.Telemetry       — module-name id
      #   Kiln.Repo               — module-name id
      #   Phoenix.PubSub          — "Phoenix.PubSub.Supervisor" id (since
      #                              Phoenix.PubSub.child_spec returns a
      #                              supervisor under the hood)
      #   Finch                   — `Kiln.Finch` name id
      #   Registry                — `Kiln.RunRegistry` name id
      #   Oban                    — module-name id
      #   KilnWeb.Endpoint        — module-name id
      expectations = [
        {"KilnWeb.Telemetry", &(&1 == KilnWeb.Telemetry)},
        {"Kiln.Repo", &(&1 == Kiln.Repo)},
        {"Phoenix.PubSub (via supervisor)",
         fn id -> is_atom(id) and to_string(id) =~ "PubSub" end},
        {"Finch (Kiln.Finch)", &(&1 == Kiln.Finch)},
        {"Registry (Kiln.RunRegistry)", &(&1 == Kiln.RunRegistry)},
        {"Oban", &(&1 == Oban)},
        {"KilnWeb.Endpoint", &(&1 == KilnWeb.Endpoint)}
      ]

      for {label, pred} <- expectations do
        assert Enum.any?(child_ids, pred),
               "expected D-42 child #{label} missing from tree: #{inspect(child_ids)}"
      end
    end

    test "negative: no Phase 2+ stub children in the P1 tree (behavior 40)" do
      child_ids =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _pid, _type, _mods} -> id end)

      # These are all children that downstream phases will add — they
      # MUST NOT ship in P1 per CONTEXT.md D-42 ("shipping them as
      # no-op :permanent children with TODOs creates dead code that
      # must be restructured at P2/3/4/5").
      forbidden = [
        Kiln.Runs.RunDirector,
        Kiln.Runs.RunSupervisor,
        Kiln.Sandboxes.Supervisor,
        Kiln.Policies.StuckDetector,
        Kiln.Agents.SessionSupervisor,
        Kiln.Sandboxes.DTU.Supervisor,
        DNSCluster
      ]

      for forbidden_child <- forbidden do
        refute Enum.any?(child_ids, fn id -> id == forbidden_child end),
               "#{inspect(forbidden_child)} MUST NOT be in the P1 D-42 supervision tree"
      end
    end

    test "Kiln.Finch named pool is alive (behavior 41)" do
      pid = Process.whereis(Kiln.Finch)
      assert is_pid(pid), "Kiln.Finch named pool must be registered post-boot"
      assert Process.alive?(pid)
    end

    test "Kiln.RunRegistry is alive (D-42 P1 child — Phase 2 will use it for RunServer lookup)" do
      pid = Process.whereis(Kiln.RunRegistry)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "Oban supervisor tree is alive" do
      # Oban registers its root supervisor under a namespaced name in
      # Oban 2.21+ (`Oban.Registry` keyed on the instance name). The
      # most portable assertion is that `Oban.config/1` returns without
      # raising — it looks up the instance via `Oban.Registry`.
      config = Oban.config()
      assert is_struct(config, Oban.Config)

      # Find the Oban child via `which_children` and assert it's alive.
      oban_child =
        Kiln.Supervisor
        |> Supervisor.which_children()
        |> Enum.find(fn {id, _pid, _type, _mods} -> id == Oban end)

      assert {Oban, pid, _type, _mods} = oban_child
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "KilnWeb.Endpoint is alive (staged start — added after BootChecks per D-32)" do
      pid = Process.whereis(KilnWeb.Endpoint)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end
end
