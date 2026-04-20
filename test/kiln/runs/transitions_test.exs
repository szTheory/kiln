defmodule Kiln.Runs.TransitionsTest do
  @moduledoc """
  Command-module tests for `Kiln.Runs.Transitions` — the state-machine
  command path shipped in Plan 02-06.

  Covers:
    * every D-87 allowed edge succeeds
    * cross-cutting edges (any non-terminal → `:escalated` / `:failed`)
    * illegal transitions are rejected cleanly with no audit event
    * terminal states reject every outgoing transition
    * in-transaction audit event pairing (verified via
      `Kiln.Audit.replay/1` on the correlation_id)
    * post-commit PubSub broadcast on both `"run:<id>"` and
      `"runs:board"` topics
    * `SELECT ... FOR UPDATE` serialisation under concurrent callers

  Uses `Kiln.DataCase` for the Ecto sandbox and `Kiln.StuckDetectorCase`
  for the singleton-reuse dance (checker issue #6). `async: false` is
  non-negotiable here — PubSub broadcasts to `"runs:board"` are a
  process-global topic, and the concurrent race test allocates
  sandbox-shared connections across spawned tasks.
  """

  use Kiln.DataCase, async: false
  use Kiln.StuckDetectorCase, async: false
  require Logger

  alias Kiln.{Audit, Repo}
  alias Kiln.Runs.{Run, Transitions, IllegalTransitionError}
  alias Kiln.Factory.Run, as: RunFactory

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)
    {:ok, correlation_id: cid}
  end

  describe "matrix/0" do
    test "returns a map with 6 non-terminal keys matching Run.active_states/0" do
      m = Transitions.matrix()
      keys = MapSet.new(Map.keys(m))
      assert keys == MapSet.new(Run.active_states())
    end

    test "every value list is a subset of Run.states/0" do
      for {_from, tos} <- Transitions.matrix() do
        for to <- tos do
          assert to in Run.states(),
                 "matrix contains target #{inspect(to)} which is not in Run.states/0"
        end
      end
    end

    test "no matrix entry lists :escalated or :failed (those are cross-cutting)" do
      for {_from, tos} <- Transitions.matrix() do
        refute :escalated in tos
        refute :failed in tos
      end
    end

    test "terminal states are NOT keys in the matrix" do
      for terminal <- Run.terminal_states() do
        refute Map.has_key?(Transitions.matrix(), terminal),
               "terminal state #{inspect(terminal)} must not be a matrix key"
      end
    end
  end

  describe "transition/3 — allowed transitions" do
    test "queued -> planning succeeds with audit event pairing", %{correlation_id: cid} do
      run = RunFactory.insert(:run, state: :queued)
      assert {:ok, updated} = Transitions.transition(run.id, :planning)
      assert updated.state == :planning

      assert [event] = Audit.replay(correlation_id: cid)
      assert event.event_kind == :run_state_transitioned
      assert event.run_id == run.id
      assert event.payload["from"] == "queued"
      assert event.payload["to"] == "planning"
    end

    test "every D-87 allowed edge passes" do
      for {from, tos} <- Transitions.matrix(), to <- tos do
        run = RunFactory.insert(:run, state: from)

        assert {:ok, updated} = Transitions.transition(run.id, to),
               "expected #{from} -> #{to} to succeed"

        assert updated.state == to,
               "expected state to be #{inspect(to)} after #{from} -> #{to} transition"
      end
    end

    test "any non-terminal state can reach :escalated (cross-cutting)" do
      for from <- Run.active_states() do
        run = RunFactory.insert(:run, state: from)

        assert {:ok, updated} =
                 Transitions.transition(run.id, :escalated, %{reason: :test_escalation}),
               "expected cross-cutting #{from} -> :escalated"

        assert updated.state == :escalated
        assert updated.escalation_reason == "test_escalation"
      end
    end

    test "any non-terminal state can reach :failed (cross-cutting)" do
      for from <- Run.active_states() do
        run = RunFactory.insert(:run, state: from)

        assert {:ok, updated} =
                 Transitions.transition(run.id, :failed, %{reason: :test_failure}),
               "expected cross-cutting #{from} -> :failed"

        assert updated.state == :failed
        assert updated.escalation_reason == "test_failure"
      end
    end

    test "reason atom is recorded in the audit payload", %{correlation_id: cid} do
      run = RunFactory.insert(:run, state: :planning)
      assert {:ok, _} = Transitions.transition(run.id, :blocked, %{reason: :needs_credentials})

      assert [event] = Audit.replay(correlation_id: cid)
      assert event.payload["from"] == "planning"
      assert event.payload["to"] == "blocked"
      assert event.payload["reason"] == "needs_credentials"
    end

    test "non-atom reason is silently dropped from audit payload (T5)", %{correlation_id: cid} do
      run = RunFactory.insert(:run, state: :planning)

      assert {:ok, _} =
               Transitions.transition(run.id, :blocked, %{reason: "<script>alert(1)</script>"})

      assert [event] = Audit.replay(correlation_id: cid)
      refute Map.has_key?(event.payload, "reason")
    end
  end

  describe "transition/3 — illegal transitions" do
    test "queued -> merged rejected" do
      run = RunFactory.insert(:run, state: :queued)
      assert {:error, :illegal_transition} = Transitions.transition(run.id, :merged)
    end

    test "queued -> coding rejected (two-hop not allowed)" do
      run = RunFactory.insert(:run, state: :queued)
      assert {:error, :illegal_transition} = Transitions.transition(run.id, :coding)
    end

    test "merged (terminal) -> anything rejected" do
      run = RunFactory.insert(:run, state: :merged)

      for to <- [:planning, :coding, :queued, :escalated, :failed] do
        assert {:error, :illegal_transition} = Transitions.transition(run.id, to),
               "expected terminal :merged -> #{to} to be rejected"
      end
    end

    test "failed (terminal) -> anything rejected" do
      run = RunFactory.insert(:run, state: :failed)
      assert {:error, :illegal_transition} = Transitions.transition(run.id, :planning)
    end

    test "escalated (terminal) -> anything rejected" do
      run = RunFactory.insert(:run, state: :escalated)
      assert {:error, :illegal_transition} = Transitions.transition(run.id, :planning)
    end

    test "illegal transitions write no audit event", %{correlation_id: cid} do
      run = RunFactory.insert(:run, state: :queued)
      assert {:error, :illegal_transition} = Transitions.transition(run.id, :merged)
      assert [] == Audit.replay(correlation_id: cid)

      # Run state unchanged.
      assert %Run{state: :queued} = Repo.get!(Run, run.id)
    end

    test "not_found for unknown run_id" do
      assert {:error, :not_found} = Transitions.transition(Ecto.UUID.generate(), :planning)
    end
  end

  describe "transition!/3" do
    test "returns the Run on success" do
      run = RunFactory.insert(:run, state: :queued)
      assert %Run{state: :planning} = Transitions.transition!(run.id, :planning)
    end

    test "raises IllegalTransitionError with from/to/allowed message on illegal edge" do
      run = RunFactory.insert(:run, state: :queued)

      assert_raise IllegalTransitionError, ~r/from.*queued.*to.*merged.*allowed/, fn ->
        Transitions.transition!(run.id, :merged)
      end
    end

    test "raises IllegalTransitionError with :not_found shape for unknown run_id" do
      fake_id = Ecto.UUID.generate()

      try do
        Transitions.transition!(fake_id, :planning)
        flunk("expected IllegalTransitionError to be raised")
      rescue
        e in IllegalTransitionError ->
          assert e.from == :not_found
          assert e.to == :planning
          assert e.allowed == []
      end
    end
  end

  describe "concurrent transitions — SELECT ... FOR UPDATE" do
    test "two parallel transitions on the same run serialise; one wins, one fails" do
      run = RunFactory.insert(:run, state: :queued)

      # The test DB uses Ecto.Adapters.SQL.Sandbox — the spawned tasks
      # must be granted ownership of this test's sandboxed connection
      # BEFORE they begin, so their own Repo queries (and the
      # StuckDetector's GenServer.call inside `transition/3`) see the
      # pre-seeded run row. See Kiln.DataCase.setup_sandbox/1 — we are
      # in shared mode here (async: false).
      parent = self()

      tasks =
        for _ <- 1..2 do
          Task.async(fn ->
            Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, parent, self())
            Transitions.transition(run.id, :planning)
          end)
        end

      results = Task.await_many(tasks, 5_000)
      oks = Enum.count(results, &match?({:ok, _}, &1))
      errs = Enum.count(results, &match?({:error, :illegal_transition}, &1))

      assert oks == 1,
             "expected exactly one winner under SELECT FOR UPDATE; got results: #{inspect(results)}"

      assert errs == 1,
             "expected exactly one illegal_transition reject; got results: #{inspect(results)}"

      # Final state is :planning and exactly ONE row exists (no duplicate audit).
      assert %Run{state: :planning} = Repo.get!(Run, run.id)
    end
  end

  describe "post-commit PubSub broadcast" do
    test "subscribes to run:<id> and receives :run_state on success" do
      run = RunFactory.insert(:run, state: :queued)
      :ok = Phoenix.PubSub.subscribe(Kiln.PubSub, "run:#{run.id}")

      {:ok, _} = Transitions.transition(run.id, :planning)

      assert_receive {:run_state, %Run{state: :planning}}, 200
    end

    test "subscribes to runs:board and receives :run_state on success" do
      run = RunFactory.insert(:run, state: :queued)
      :ok = Phoenix.PubSub.subscribe(Kiln.PubSub, "runs:board")

      {:ok, _} = Transitions.transition(run.id, :planning)

      assert_receive {:run_state, %Run{state: :planning}}, 200
    end

    test "no broadcast when the transition is rejected" do
      run = RunFactory.insert(:run, state: :queued)
      :ok = Phoenix.PubSub.subscribe(Kiln.PubSub, "run:#{run.id}")

      assert {:error, :illegal_transition} = Transitions.transition(run.id, :merged)

      refute_receive {:run_state, _}, 100
    end
  end
end
