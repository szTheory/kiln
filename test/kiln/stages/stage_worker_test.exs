defmodule Kiln.Stages.StageWorkerTest do
  @moduledoc """
  Unit tests for `Kiln.Stages.StageWorker` — the Oban worker that drives
  a stage through validate-input → dispatch (stub) → produce-artifact →
  transition-run (Plan 02-08 Task 1).

  Exercises the LOCKED D-87-compliant transition mapping:
    :planning  → :coding
    :coding    → :testing
    :testing   → :verifying
    :verifying → :merged  (terminal)
    :merge     → NO TRANSITION (Phase-3 owns merge semantics)

  Also proves the D-75 50 MB cap rejection at the stage-contract boundary
  (checker issue #2 regression guard — 52_428_801 bytes = 50 MB + 1 must
  be rejected via `{:cancel, {:stage_input_rejected, _}}` BEFORE any
  agent invocation).

  Uses `Kiln.ObanCase` + `Kiln.StuckDetectorCase` (checker issue #6
  centralised helpers — no more inline `Process.whereis(...)` dances).
  """

  use Kiln.ObanCase, async: false
  use Kiln.StuckDetectorCase, async: false

  require Logger

  alias Kiln.{Artifacts, Audit}
  alias Kiln.Runs.Run
  alias Kiln.Stages.StageWorker
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)

    run =
      RunFactory.insert(:run,
        state: :planning,
        workflow_id: "elixir_phoenix_feature",
        workflow_checksum: String.duplicate("a", 64)
      )

    stage_run =
      StageRunFactory.insert(:stage_run,
        run_id: run.id,
        kind: :planning,
        agent_role: :planner
      )

    {:ok, run: run, stage_run: stage_run, correlation_id: cid}
  end

  defp valid_planning_input(run, stage_run) do
    %{
      "run_id" => run.id,
      "stage_run_id" => stage_run.id,
      "attempt" => 1,
      "spec_ref" => %{
        "sha256" => String.duplicate("f", 64),
        "size_bytes" => 100,
        "content_type" => "text/markdown"
      },
      "budget_remaining" => %{
        "tokens_usd" => 1.0,
        "tokens" => 1000,
        "elapsed_seconds" => 300
      },
      "model_profile_snapshot" => %{
        "role" => "planner",
        "requested_model" => "sonnet-class",
        "fallback_chain" => []
      },
      "holdout_excluded" => true,
      "last_diagnostic_ref" => nil
    }
  end

  defp job_args(run, stage_run, input, kind \\ "planning") do
    %{
      "idempotency_key" => "run:#{run.id}:stage:#{stage_run.id}",
      "run_id" => run.id,
      "stage_run_id" => stage_run.id,
      "stage_kind" => kind,
      "stage_input" => input
    }
  end

  describe "happy path — valid planning stage input" do
    test "transitions run :planning → :coding; writes artifact; completes op",
         %{run: run, stage_run: sr} do
      args = job_args(run, sr, valid_planning_input(run, sr))
      assert :ok = perform_job(StageWorker, args)

      # Run moved to :coding (LOCKED mapping per Plan 02-08)
      updated = Kiln.Repo.get!(Run, run.id)
      assert updated.state == :coding

      # Artifact was written under the stub-dispatch path
      assert {:ok, _artifact} = Artifacts.get(sr.id, "planning.md")
    end

    test "second perform on same idempotency_key is a noop", %{run: run, stage_run: sr} do
      args = job_args(run, sr, valid_planning_input(run, sr))

      assert :ok = perform_job(StageWorker, args)
      assert :ok = perform_job(StageWorker, args)

      final = Kiln.Repo.get!(Run, run.id)
      assert final.state == :coding
    end
  end

  describe "invalid stage input" do
    test "missing required field triggers :stage_input_rejected + escalation",
         %{run: run, stage_run: sr, correlation_id: cid} do
      bad_input = valid_planning_input(run, sr) |> Map.delete("holdout_excluded")
      args = job_args(run, sr, bad_input)

      # JSV must reject; StageWorker must cancel + escalate
      assert {:cancel, {:stage_input_rejected, _}} = perform_job(StageWorker, args)

      # Run moved to :escalated
      updated = Kiln.Repo.get!(Run, run.id)
      assert updated.state == :escalated

      # Audit has BOTH :stage_input_rejected AND :run_state_transitioned events
      events = Audit.replay(correlation_id: cid)
      kinds = events |> Enum.map(& &1.event_kind) |> MapSet.new()
      assert MapSet.member?(kinds, :stage_input_rejected)
      assert MapSet.member?(kinds, :run_state_transitioned)
    end

    # Addresses checker issue #2: explicit 50 MB + 1 byte boundary-rejection test.
    # D-75 LOCKS the 50 MB cap; Plan 01 encoded it as "size_bytes": {"maximum": 52428800}.
    # This test proves the rejection fires at the stage-contract validation boundary,
    # NOT inside the agent.
    test "oversized spec_ref.size_bytes (50 MB + 1) rejected at contract boundary",
         %{run: run, stage_run: sr, correlation_id: cid} do
      oversized_input =
        valid_planning_input(run, sr)
        |> Map.put("spec_ref", %{
          "sha256" => String.duplicate("b", 64),
          # 50 MB + 1 — the deliberate violation
          "size_bytes" => 52_428_801,
          "content_type" => "text/markdown"
        })

      args = job_args(run, sr, oversized_input)

      assert {:cancel, {:stage_input_rejected, _err}} = perform_job(StageWorker, args),
             "StageWorker MUST reject oversized inputs at the contract boundary (D-75 50 MB cap; checker issue #2)"

      # Run moved to :escalated (invalid_stage_input reason)
      updated = Kiln.Repo.get!(Run, run.id)
      assert updated.state == :escalated

      # Audit event exists for the rejection
      events = Audit.replay(correlation_id: cid)
      kinds = events |> Enum.map(& &1.event_kind) |> MapSet.new()

      assert MapSet.member?(kinds, :stage_input_rejected),
             "Audit ledger MUST record :stage_input_rejected for boundary rejections"
    end
  end

  describe "transition mapping (LOCKED per Plan 02-08 checker #3)" do
    test ":planning → :coding" do
      run =
        RunFactory.insert(:run,
          state: :planning,
          workflow_id: "elixir_phoenix_feature",
          workflow_checksum: String.duplicate("a", 64)
        )

      sr =
        StageRunFactory.insert(:stage_run,
          run_id: run.id,
          kind: :planning,
          agent_role: :planner
        )

      args = job_args(run, sr, valid_planning_input(run, sr), "planning")
      assert :ok = perform_job(StageWorker, args)
      assert Kiln.Repo.get!(Run, run.id).state == :coding
    end

    test ":verifying → :merged (reaches terminal)" do
      run =
        RunFactory.insert(:run,
          state: :verifying,
          workflow_id: "elixir_phoenix_feature",
          workflow_checksum: String.duplicate("a", 64)
        )

      sr =
        StageRunFactory.insert(:stage_run,
          run_id: run.id,
          kind: :verifying,
          agent_role: :qa_verifier
        )

      verifying_input = %{
        "run_id" => run.id,
        "stage_run_id" => sr.id,
        "attempt" => 1,
        "spec_ref" => %{
          "sha256" => String.duplicate("f", 64),
          "size_bytes" => 100,
          "content_type" => "text/markdown"
        },
        "budget_remaining" => %{
          "tokens_usd" => 1.0,
          "tokens" => 1000,
          "elapsed_seconds" => 300
        },
        "model_profile_snapshot" => %{
          "role" => "qa_verifier",
          "requested_model" => "sonnet-class",
          "fallback_chain" => []
        },
        "holdout_excluded" => true,
        "test_output_ref" => %{
          "sha256" => String.duplicate("c", 64),
          "size_bytes" => 100,
          "content_type" => "text/markdown"
        }
      }

      args = job_args(run, sr, verifying_input, "verifying")
      assert :ok = perform_job(StageWorker, args)
      assert Kiln.Repo.get!(Run, run.id).state == :merged
    end

    test ":merge kind does NOT issue a transition (Phase 3 owns merge semantics)" do
      # Run is already in :merged (reached via verifying). If StageWorker tried
      # to transition :merged → :merged, D-87 would reject it (terminal → *).
      # The LOCKED mapping's final clause treats :merge as a no-op transition.
      run =
        RunFactory.insert(:run,
          state: :merged,
          workflow_id: "elixir_phoenix_feature",
          workflow_checksum: String.duplicate("a", 64)
        )

      sr =
        StageRunFactory.insert(:stage_run,
          run_id: run.id,
          kind: :merge,
          agent_role: :coder
        )

      merge_input = %{
        "run_id" => run.id,
        "stage_run_id" => sr.id,
        "attempt" => 1,
        "spec_ref" => %{
          "sha256" => String.duplicate("f", 64),
          "size_bytes" => 100,
          "content_type" => "text/markdown"
        },
        "budget_remaining" => %{
          "tokens_usd" => 1.0,
          "tokens" => 1000,
          "elapsed_seconds" => 300
        },
        "model_profile_snapshot" => %{
          "role" => "coder",
          "requested_model" => "sonnet-class",
          "fallback_chain" => []
        },
        "holdout_excluded" => true,
        "verifier_verdict_ref" => %{
          "sha256" => String.duplicate("d", 64),
          "size_bytes" => 100,
          "content_type" => "text/markdown"
        }
      }

      args = job_args(run, sr, merge_input, "merge")
      assert :ok = perform_job(StageWorker, args)
      # State unchanged — the :merge kind does not transition the run.
      assert Kiln.Repo.get!(Run, run.id).state == :merged
    end
  end

  describe "idempotency key shape (D-70)" do
    test "uses run:<run_id>:stage:<stage_run_id> format", %{run: run, stage_run: sr} do
      args = job_args(run, sr, valid_planning_input(run, sr))
      assert args["idempotency_key"] == "run:#{run.id}:stage:#{sr.id}"
    end
  end
end
