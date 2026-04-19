defmodule Kiln.ExternalOperationsTest do
  @moduledoc """
  Mechanical proof of behaviors 10-13 from 01-VALIDATION.md:

    * Behavior 10 — `fetch_or_record_intent/2` with a new key inserts a
      row in `:intent_recorded` AND appends an
      `external_op_intent_recorded` audit event in the same transaction
      (D-18).
    * Behavior 11 — racing two calls with the same idempotency_key
      produces exactly ONE row (UNIQUE INDEX wins); the second call
      returns `{:found_existing, op}` and emits no audit event.
    * Behavior 12 — `complete_op/2` transitions state to `:completed`
      AND appends an `external_op_completed` audit event in the same
      transaction (D-18 invariant for the completion edge).
    * Behavior 13 — after intent insert with no action, a re-call of
      `fetch_or_record_intent/2` returns `{:found_existing}` with state
      still `:intent_recorded` — the invariant that lets P3's executor
      skip re-doing an already-completed action is testable here.

  Also covers the `fail_op/2` failure edge (symmetric to `complete_op`).
  """

  use Kiln.DataCase, async: true

  alias Kiln.Audit
  alias Kiln.ExternalOperations
  alias Kiln.ExternalOperations.Operation

  require Logger

  setup do
    # Every test operates inside a Logger.metadata scope so
    # `Kiln.Audit.append/1` (which reads Logger.metadata[:correlation_id]
    # as a fallback) can correlate the intent audit event with the row.
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)
    {:ok, correlation_id: cid}
  end

  describe "fetch_or_record_intent/2 (behaviors 10, 11, 13)" do
    test "new key → {:inserted_new, %Operation{state: :intent_recorded}} + paired audit event (behavior 10)",
         %{correlation_id: cid} do
      key = "run_a:stage_x:llm_complete"

      assert {:inserted_new, %Operation{} = op} =
               ExternalOperations.fetch_or_record_intent(key, %{
                 op_kind: "llm_complete",
                 intent_payload: %{"model" => "sonnet-4"}
               })

      assert op.idempotency_key == key
      assert op.state == :intent_recorded
      assert op.intent_recorded_at != nil
      assert op.intent_payload == %{"model" => "sonnet-4"}

      # D-18: companion audit event persisted in the same tx.
      assert [event] = Audit.replay(correlation_id: cid)
      assert event.event_kind == :external_op_intent_recorded
      assert event.payload["op_kind"] == "llm_complete"
      assert event.payload["idempotency_key"] == key
    end

    test "same key twice → {:found_existing, op} on second call, no duplicate audit event (behavior 11)",
         %{correlation_id: cid} do
      key = "run_b:stage_y:docker_run"
      attrs = %{op_kind: "docker_run", intent_payload: %{"image" => "alpine:3.20"}}

      assert {:inserted_new, op1} = ExternalOperations.fetch_or_record_intent(key, attrs)
      assert {:found_existing, op2} = ExternalOperations.fetch_or_record_intent(key, attrs)

      assert op1.id == op2.id
      assert Repo.aggregate(Operation, :count) == 1

      # Exactly one intent_recorded event (the second call must NOT
      # re-append an audit event).
      events = Audit.replay(correlation_id: cid)
      assert length(events) == 1
      assert hd(events).event_kind == :external_op_intent_recorded
    end

    test "found_existing retains :intent_recorded state when action never started (behavior 13)" do
      key = "run_c:stage_z:git_push"
      attrs = %{op_kind: "git_push", intent_payload: %{"ref" => "refs/heads/main"}}

      {:inserted_new, _} = ExternalOperations.fetch_or_record_intent(key, attrs)

      # Simulate a worker crash between intent and action: the retrying
      # worker calls fetch_or_record_intent again with the same key.
      {:found_existing, op} = ExternalOperations.fetch_or_record_intent(key, attrs)

      assert op.state == :intent_recorded
      # The invariant: since state != :completed, the executor must
      # re-run the action (or move to :action_in_flight first). P3's
      # worker will check `state` before deciding whether to skip.
    end

    test "validation failure → {:error, changeset}" do
      assert {:error, %Ecto.Changeset{valid?: false} = cs} =
               ExternalOperations.fetch_or_record_intent("k", %{})

      assert "can't be blank" in errors_on(cs).op_kind
    end
  end

  describe "complete_op/2 (behavior 12)" do
    test "transitions to :completed + writes external_op_completed audit event in same tx",
         %{correlation_id: cid} do
      {:inserted_new, op} =
        ExternalOperations.fetch_or_record_intent("run_d:stage_1:llm_complete", %{
          op_kind: "llm_complete",
          intent_payload: %{}
        })

      assert {:ok, completed} = ExternalOperations.complete_op(op, %{"tokens" => 42})

      assert completed.state == :completed
      assert completed.result_payload == %{"tokens" => 42}
      assert completed.completed_at != nil

      kinds =
        cid
        |> then(&Audit.replay(correlation_id: &1))
        |> Enum.map(& &1.event_kind)

      assert :external_op_intent_recorded in kinds
      assert :external_op_completed in kinds
    end
  end

  describe "fail_op/2" do
    test "transitions to :failed + writes external_op_failed audit event; increments attempts",
         %{correlation_id: cid} do
      {:inserted_new, op} =
        ExternalOperations.fetch_or_record_intent("run_e:stage_1:llm_complete", %{
          op_kind: "llm_complete",
          intent_payload: %{}
        })

      assert op.attempts == 0

      assert {:ok, failed} =
               ExternalOperations.fail_op(op, %{"type" => "rate_limit", "retry_after_ms" => 5000})

      assert failed.state == :failed
      assert failed.attempts == 1
      assert failed.last_error == %{"type" => "rate_limit", "retry_after_ms" => 5000}

      kinds =
        cid
        |> then(&Audit.replay(correlation_id: &1))
        |> Enum.map(& &1.event_kind)

      assert :external_op_failed in kinds
    end
  end

  describe "abandon_op/2" do
    test "transitions to :abandoned + writes external_op_failed audit event with 'abandoned:' prefix",
         %{correlation_id: cid} do
      {:inserted_new, op} =
        ExternalOperations.fetch_or_record_intent("run_f:stage_1:docker_run", %{
          op_kind: "docker_run",
          intent_payload: %{}
        })

      assert {:ok, abandoned} =
               ExternalOperations.abandon_op(op, "stuck_detector: no action after 30m")

      assert abandoned.state == :abandoned
      assert abandoned.last_error == %{"reason" => "stuck_detector: no action after 30m"}

      events = Audit.replay(correlation_id: cid)
      abandon_event = Enum.find(events, &(&1.event_kind == :external_op_failed))
      assert abandon_event != nil
      assert String.starts_with?(abandon_event.payload["error"], "abandoned:")
    end
  end
end
